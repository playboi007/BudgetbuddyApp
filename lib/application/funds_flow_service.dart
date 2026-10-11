import 'dart:convert';

import '../budgetbuddy_models.dart';
import 'contracts.dart';
import 'funds_repository.dart';

final class FundsFlowService implements FundsApplication {
  FundsFlowService({
    required this.actor,
    required this.repository,
    required this.gateway,
    required this.clock,
  });

  final ActorContext actor;
  final FundsRepository repository;
  final PaymentGateway gateway;
  final FundsClock clock;

  @override
  Future<FundsData> load() => repository.load(actor);

  @override
  Stream<FundsData> watch() => repository.watch(actor);

  @override
  Future<CommandResult> execute(FundsCommand command) async {
    final commandId = command.commandId.trim();
    if (commandId.isEmpty) {
      return _result(
        const FundsCommandMemo(
          disposition: CommandDisposition.rejected,
          failure: FundsFailure(
            FundsFailureCode.invalidCommand,
            'A command ID is required.',
          ),
        ),
        await load(),
      );
    }

    late final String fingerprint;
    try {
      fingerprint = _commandFingerprint(command);
    } on Object {
      return _result(
        const FundsCommandMemo(
          disposition: CommandDisposition.rejected,
          failure: FundsFailure(
            FundsFailureCode.invalidCommand,
            'The command contains invalid data.',
          ),
        ),
        await load(),
      );
    }

    final plan = await repository.transact<_RunPlan>(actor, (transaction) {
      final boundFingerprint = transaction.commandFingerprint(commandId);
      if (boundFingerprint != null && boundFingerprint != fingerprint) {
        return const _RunPlan.conflict();
      }

      final memo = transaction.commandMemo(commandId);
      if (memo != null) return _RunPlan.cached(memo);

      // Recover keys from existing requests when command memos are absent.
      final existingRequest = transaction.data.requests
          .where((request) => request.idempotencyKey == commandId)
          .firstWhereOrNull;
      if (existingRequest != null) {
        final recoveredFingerprint = _fingerprintForRequest(existingRequest);
        if (recoveredFingerprint != fingerprint) {
          return const _RunPlan.conflict();
        }
        if (boundFingerprint == null) {
          transaction.bindCommand(commandId, recoveredFingerprint);
        }
        final recovered = FundsCommandMemo(
          disposition: CommandDisposition.submitted,
          requestId: existingRequest.id,
        );
        transaction.completeCommand(commandId, recovered);
        return _RunPlan.cached(recovered);
      }

      if (boundFingerprint == null) {
        transaction.bindCommand(commandId, fingerprint);
      }

      try {
        return _runCommand(transaction, commandId, command);
      } catch (error) {
        if (error is! ArgumentError && error is! RangeError) rethrow;
        return _complete(
          transaction,
          commandId,
          const FundsCommandMemo(
            disposition: CommandDisposition.rejected,
            failure: FundsFailure(
              FundsFailureCode.invalidCommand,
              'The command contains invalid data.',
            ),
          ),
        );
      }
    });

    if (plan.conflict) {
      return _result(
        const FundsCommandMemo(
          disposition: CommandDisposition.rejected,
          failure: FundsFailure(
            FundsFailureCode.idempotencyConflict,
            'This command ID is already bound to a different payload.',
          ),
        ),
        await load(),
      );
    }

    var finalMemo = plan.memo!;
    if (plan.dispatchRequest != null) {
      finalMemo = await _dispatch(plan.dispatchRequest!);
    }
    return _result(finalMemo, await load());
  }

  Future<CommandResult> recordProviderResult(
    ProviderResolution resolution,
  ) async {
    final eventId = resolution.eventId.trim();
    if (eventId.isEmpty) {
      return _result(
        const FundsCommandMemo(
          disposition: CommandDisposition.rejected,
          failure: FundsFailure(
            FundsFailureCode.invalidCommand,
            'A provider event ID is required.',
          ),
        ),
        await load(),
      );
    }

    final fingerprint = _providerFingerprint(resolution);
    final resolutionPlan = await repository.transact<_ResolutionPlan>(
      actor,
      (transaction) =>
          _applyProviderResolution(transaction, resolution, fingerprint),
    );
    return _result(resolutionPlan.memo, await load());
  }

  _RunPlan _runCommand(
    FundsRepositoryTransaction transaction,
    String commandId,
    FundsCommand command,
  ) {
    return switch (command) {
      CreateCategoryCommand() => _createCategory(
        transaction,
        commandId,
        command,
      ),
      EditCategoryCommand() => _editCategory(transaction, commandId, command),
      ArchiveCategoryCommand() => _archiveCategory(
        transaction,
        commandId,
        command,
      ),
      AllocateCommand() => _moveFunds(
        transaction,
        commandId,
        command.categoryId,
        command.amount,
        allocate: true,
      ),
      ReleaseCommand() => _moveFunds(
        transaction,
        commandId,
        command.categoryId,
        command.amount,
        allocate: false,
      ),
      DepositCommand() => _startDeposit(transaction, commandId, command),
      SpendCommand() => _startSpend(transaction, commandId, command),
    };
  }

  _RunPlan _createCategory(
    FundsRepositoryTransaction transaction,
    String commandId,
    CreateCategoryCommand command,
  ) {
    final category = command.category;
    if (category.walletId != actor.walletId) {
      return _complete(
        transaction,
        commandId,
        _rejected(
          FundsFailureCode.unauthorized,
          'Category belongs to another wallet.',
        ),
      );
    }
    if (category.isArchived) {
      return _complete(
        transaction,
        commandId,
        _rejected(
          FundsFailureCode.invalidCommand,
          'A category must be active when created.',
        ),
      );
    }
    if (_categoryBalance(transaction.data, category.id) != null) {
      return _complete(
        transaction,
        commandId,
        _rejected(
          FundsFailureCode.invalidCommand,
          'A category with this ID already exists.',
        ),
      );
    }
    final categories = [
      ...transaction.data.wallet.categories,
      CategoryBalance(
        category: category,
        balance: Money.zero,
        reserved: Money.zero,
      ),
    ];
    transaction.replaceData(
      _copyData(transaction.data, categories: categories),
    );
    return _complete(transaction, commandId, _applied());
  }

  _RunPlan _editCategory(
    FundsRepositoryTransaction transaction,
    String commandId,
    EditCategoryCommand command,
  ) {
    final current = _categoryBalance(transaction.data, command.categoryId);
    if (current == null) {
      return _complete(
        transaction,
        commandId,
        _rejected(FundsFailureCode.notFound, 'Category was not found.'),
      );
    }
    if (current.category.isArchived) {
      return _complete(
        transaction,
        commandId,
        _rejected(
          FundsFailureCode.archivedCategory,
          'Archived categories cannot be edited.',
        ),
      );
    }
    final updatedCategory = FundCategory(
      id: current.category.id,
      walletId: current.category.walletId,
      name: command.name,
      kind: current.category.kind,
      target: command.target,
      createdAt: current.category.createdAt,
    );
    final categories = transaction.data.wallet.categories
        .map(
          (item) => item.category.id == updatedCategory.id
              ? CategoryBalance(
                  category: updatedCategory,
                  balance: item.balance,
                  reserved: item.reserved,
                )
              : item,
        )
        .toList(growable: false);
    transaction.replaceData(
      _copyData(transaction.data, categories: categories),
    );
    return _complete(transaction, commandId, _applied());
  }

  _RunPlan _archiveCategory(
    FundsRepositoryTransaction transaction,
    String commandId,
    ArchiveCategoryCommand command,
  ) {
    final categoryId = command.categoryId.trim();
    final current = _categoryBalance(transaction.data, categoryId);
    if (current == null) {
      return _complete(
        transaction,
        commandId,
        _rejected(FundsFailureCode.notFound, 'Category was not found.'),
      );
    }
    if (current.category.isArchived) {
      return _complete(transaction, commandId, _applied());
    }
    final hasActivePayment = transaction.data.reservations.any(
      (reservation) =>
          reservation.status == ReservationStatus.active &&
          reservation.categoryId == categoryId,
    );
    if (!current.canArchive || hasActivePayment) {
      return _complete(
        transaction,
        commandId,
        _rejected(
          FundsFailureCode.insufficientFunds,
          'A category can be archived only after its balance and holds reach zero.',
        ),
      );
    }
    final now = clock().toUtc();
    final archivedCategory = FundCategory(
      id: current.category.id,
      walletId: current.category.walletId,
      name: current.category.name,
      kind: current.category.kind,
      target: current.category.target,
      createdAt: current.category.createdAt,
      archivedAt: now,
    );
    final categories = transaction.data.wallet.categories
        .map(
          (item) => item.category.id == archivedCategory.id
              ? CategoryBalance(
                  category: archivedCategory,
                  balance: item.balance,
                  reserved: item.reserved,
                )
              : item,
        )
        .toList(growable: false);
    transaction.replaceData(
      _copyData(transaction.data, categories: categories, asOf: now),
    );
    return _complete(transaction, commandId, _applied());
  }

  _RunPlan _moveFunds(
    FundsRepositoryTransaction transaction,
    String commandId,
    String categoryId,
    Money amount, {
    required bool allocate,
  }) {
    if (amount == Money.zero) {
      return _complete(
        transaction,
        commandId,
        _rejected(FundsFailureCode.invalidCommand, 'Amount must be positive.'),
      );
    }
    categoryId = categoryId.trim();
    final current = _categoryBalance(transaction.data, categoryId);
    if (current == null) {
      return _complete(
        transaction,
        commandId,
        _rejected(FundsFailureCode.notFound, 'Category was not found.'),
      );
    }
    if (current.category.isArchived) {
      return _complete(
        transaction,
        commandId,
        _rejected(
          FundsFailureCode.archivedCategory,
          'Archived categories cannot be funded.',
        ),
      );
    }
    final available = allocate
        ? transaction.data.wallet.availableGlobal
        : current.available;
    if (available < amount) {
      return _complete(
        transaction,
        commandId,
        _rejected(
          FundsFailureCode.insufficientFunds,
          allocate
              ? 'Available global funds do not cover this allocation.'
              : 'Available category funds do not cover this release.',
        ),
      );
    }
    final now = clock().toUtc();
    final transfer = LedgerTransfer(
      source: allocate
          ? const LedgerBucket.global()
          : LedgerBucket.category(categoryId),
      destination: allocate
          ? LedgerBucket.category(categoryId)
          : const LedgerBucket.global(),
      amount: amount,
    );
    final operation = LedgerOperation(
      id: 'ledger:command:$commandId',
      walletId: actor.walletId,
      kind: allocate
          ? LedgerOperationKind.allocation
          : LedgerOperationKind.release,
      transfers: [transfer],
      postedAt: now,
      requestId: null,
      description: allocate
          ? 'Allocated to category'
          : 'Released to global funds',
    );
    final updatedBalance = allocate
        ? current.balance + amount
        : current.balance - amount;
    final categories = transaction.data.wallet.categories
        .map(
          (item) => item.category.id == categoryId
              ? CategoryBalance(
                  category: item.category,
                  balance: updatedBalance,
                  reserved: item.reserved,
                )
              : item,
        )
        .toList(growable: false);
    final unallocated = allocate
        ? transaction.data.wallet.unallocated - amount
        : transaction.data.wallet.unallocated + amount;
    transaction.replaceData(
      _copyData(
        transaction.data,
        unallocated: unallocated,
        categories: categories,
        ledger: [...transaction.data.ledger, operation],
        asOf: now,
      ),
    );
    return _complete(transaction, commandId, _applied());
  }

  _RunPlan _startDeposit(
    FundsRepositoryTransaction transaction,
    String commandId,
    DepositCommand command,
  ) {
    final quote = command.quote;
    final now = clock().toUtc();
    if (quote.walletId != actor.walletId) {
      return _complete(
        transaction,
        commandId,
        _rejected(
          FundsFailureCode.unauthorized,
          'Deposit quote belongs to another wallet.',
        ),
      );
    }
    if (!quote.isValidAt(now)) {
      return _complete(
        transaction,
        commandId,
        _rejected(FundsFailureCode.expiredQuote, 'Deposit quote has expired.'),
      );
    }
    try {
      transaction.data.wallet.total + quote.amount;
    } on RangeError {
      return _complete(
        transaction,
        commandId,
        _rejected(
          FundsFailureCode.invalidCommand,
          'Deposit would exceed the wallet balance limit.',
        ),
      );
    }
    final request = DepositRequest(
      id: _requestId(commandId),
      idempotencyKey: commandId,
      quote: quote,
      status: TransactionStatus.submitting,
      providerIdentifiers: const ProviderIdentifiers(),
      createdAt: now,
      resultDescription: 'Submitting deposit request',
      ledgerOperationId: null,
    );
    transaction.replaceData(
      _copyData(
        transaction.data,
        requests: [...transaction.data.requests, request],
        asOf: now,
      ),
    );
    final memo = FundsCommandMemo(
      disposition: CommandDisposition.submitted,
      requestId: request.id,
    );
    transaction.completeCommand(commandId, memo);
    return _RunPlan.dispatch(memo, request);
  }

  _RunPlan _startSpend(
    FundsRepositoryTransaction transaction,
    String commandId,
    SpendCommand command,
  ) {
    final quote = command.quote;
    final now = clock().toUtc();
    if (quote.walletId != actor.walletId) {
      return _complete(
        transaction,
        commandId,
        _rejected(
          FundsFailureCode.unauthorized,
          'Payment quote belongs to another wallet.',
        ),
      );
    }
    if (!quote.isValidAt(now)) {
      return _complete(
        transaction,
        commandId,
        _rejected(FundsFailureCode.expiredQuote, 'Payment quote has expired.'),
      );
    }
    final category = _categoryBalance(transaction.data, quote.categoryId);
    if (category == null) {
      return _complete(
        transaction,
        commandId,
        _rejected(FundsFailureCode.notFound, 'Payment category was not found.'),
      );
    }
    if (category.category.isArchived) {
      return _complete(
        transaction,
        commandId,
        _rejected(
          FundsFailureCode.archivedCategory,
          'Payments cannot use an archived category.',
        ),
      );
    }

    final requirement = FundingRequirement(
      quote: quote,
      categoryAvailable: category.available,
      globalAvailable: transaction.data.wallet.availableGlobal,
    );
    if (!requirement.isFullyFundable) {
      return _complete(
        transaction,
        commandId,
        _rejected(
          FundsFailureCode.insufficientFunds,
          'Category and available global funds do not cover the complete spend.',
          fundingRequirement: requirement,
        ),
      );
    }

    final approval = command.approval;
    if (requirement.needsGlobalApproval) {
      if (approval == null) {
        // Keep quote binding without a terminal memo so approval can reuse the key.
        return _RunPlan.immediate(
          FundsCommandMemo(
            disposition: CommandDisposition.requiresGlobalApproval,
            fundingRequirement: requirement,
          ),
        );
      }
      if (approval.ownerId != actor.ownerId ||
          approval.quoteId != quote.id ||
          approval.amount != requirement.globalShortfall ||
          !quote.isValidAt(approval.approvedAt) ||
          approval.approvedAt.isAfter(now)) {
        return _RunPlan.immediate(
          _rejected(
            FundsFailureCode.invalidApproval,
            'Approval must match this owner, quote, exact shortfall, and quote window.',
            fundingRequirement: requirement,
          ),
        );
      }
    } else if (approval != null) {
      return _RunPlan.immediate(
        _rejected(
          FundsFailureCode.invalidApproval,
          'This payment does not need global funding approval.',
          fundingRequirement: requirement,
        ),
      );
    }

    final funding = PaymentFundingPlan(
      quote: quote,
      categoryContribution: requirement.categoryContribution,
      globalContribution: requirement.globalShortfall,
      approval: approval,
    );
    final requestId = _requestId(commandId);
    final reservationId = _reservationId(requestId);
    final request = OutgoingPaymentRequest(
      id: requestId,
      idempotencyKey: commandId,
      funding: funding,
      reservationId: reservationId,
      status: TransactionStatus.submitting,
      providerIdentifiers: const ProviderIdentifiers(),
      createdAt: now,
      resultDescription: 'Reserving funds and submitting payment',
      ledgerOperationId: null,
    );
    final reservation = PaymentReservation(
      id: reservationId,
      requestId: requestId,
      funding: funding,
      status: ReservationStatus.active,
      createdAt: now,
    );
    final categories = transaction.data.wallet.categories
        .map(
          (item) => item.category.id == quote.categoryId
              ? CategoryBalance(
                  category: item.category,
                  balance: item.balance,
                  reserved: item.reserved + funding.categoryContribution,
                )
              : item,
        )
        .toList(growable: false);
    transaction.replaceData(
      _copyData(
        transaction.data,
        categories: categories,
        globalReserved:
            transaction.data.wallet.globalReserved + funding.globalContribution,
        requests: [...transaction.data.requests, request],
        reservations: [...transaction.data.reservations, reservation],
        asOf: now,
      ),
    );
    final memo = FundsCommandMemo(
      disposition: CommandDisposition.submitted,
      requestId: requestId,
      fundingRequirement: requirement,
    );
    transaction.completeCommand(commandId, memo);
    return _RunPlan.dispatch(memo, request);
  }

  Future<FundsCommandMemo> _dispatch(TransactionRequest request) async {
    try {
      final acknowledgment = await gateway.submit(request);
      return await _recordAcknowledgment(request.id, acknowledgment);
    } on Object {
      return _recordDispatchUnknown(request.id);
    }
  }

  Future<FundsCommandMemo> _recordDispatchUnknown(String requestId) async =>
      repository.transact(actor, (transaction) {
        final request = _requestById(transaction.data, requestId);
        if (request == null) return _submittedMemo(requestId);
        if (request.status != TransactionStatus.submitting) {
          return _memoForRequest(transaction, request);
        }
        final updated = _copyRequest(
          request,
          status: TransactionStatus.awaitingVerification,
          resultDescription:
              'Provider dispatch outcome is unknown; verification is pending.',
        );
        transaction.replaceData(
          _copyData(
            transaction.data,
            requests: _replaceRequest(transaction.data.requests, updated),
            asOf: _safeNowFor(request),
          ),
        );
        return _memoForRequest(transaction, updated);
      });

  Future<FundsCommandMemo> _recordAcknowledgment(
    String requestId,
    GatewayAcknowledgment acknowledgment,
  ) async => repository.transact(actor, (transaction) {
    final request = _requestById(transaction.data, requestId);
    if (request == null) return _submittedMemo(requestId);

    final crossRequestConflict = _identifierCollision(
      transaction.data,
      acknowledgment.identifiers,
      request.id,
    );
    if (crossRequestConflict != null) {
      final updated = _toReconciliation(request, crossRequestConflict);
      transaction.replaceData(
        _copyData(
          transaction.data,
          requests: _replaceRequest(transaction.data.requests, updated),
          asOf: _safeNowFor(request),
        ),
      );
      return _memoForRequest(transaction, updated);
    }

    ProviderIdentifiers merged;
    try {
      merged = _mergeIdentifiers(
        request.providerIdentifiers,
        acknowledgment.identifiers,
      );
    } on _IdentifierConflict catch (conflict) {
      final updated = _toReconciliation(request, conflict.message);
      transaction.replaceData(
        _copyData(
          transaction.data,
          requests: _replaceRequest(transaction.data.requests, updated),
          asOf: _safeNowFor(request),
        ),
      );
      return _memoForRequest(transaction, updated);
    }

    // A callback may settle first; a late acknowledgment must not rewind it.
    if (request.status != TransactionStatus.submitting) {
      if (!_sameIdentifiers(request.providerIdentifiers, merged)) {
        final enriched = _copyRequest(request, identifiers: merged);
        transaction.replaceData(
          _copyData(
            transaction.data,
            requests: _replaceRequest(transaction.data.requests, enriched),
            asOf: _safeNowFor(request),
          ),
        );
        return _memoForRequest(transaction, enriched);
      }
      return _memoForRequest(transaction, request);
    }

    final now = _safeNowFor(request);
    switch (acknowledgment.status) {
      case GatewayAcknowledgmentStatus.accepted:
        final updated = _copyRequest(
          request,
          status: TransactionStatus.pending,
          identifiers: merged,
          resultDescription: acknowledgment.description,
        );
        transaction.replaceData(
          _copyData(
            transaction.data,
            requests: _replaceRequest(transaction.data.requests, updated),
            asOf: now,
          ),
        );
        return _memoForRequest(transaction, updated);
      case GatewayAcknowledgmentStatus.unknown:
        final updated = _copyRequest(
          request,
          status: TransactionStatus.awaitingVerification,
          identifiers: merged,
          resultDescription: acknowledgment.description,
        );
        transaction.replaceData(
          _copyData(
            transaction.data,
            requests: _replaceRequest(transaction.data.requests, updated),
            asOf: now,
          ),
        );
        return _memoForRequest(transaction, updated);
      case GatewayAcknowledgmentStatus.rejected:
        final release = _releaseReservation(transaction.data, request, now);
        if (request is OutgoingPaymentRequest && release == null) {
          final updated = _toReconciliation(
            request,
            'Provider rejected the request, but its active reservation is missing.',
          );
          transaction.replaceData(
            _copyData(
              transaction.data,
              requests: _replaceRequest(transaction.data.requests, updated),
              asOf: now,
            ),
          );
          return _memoForRequest(transaction, updated);
        }
        final updated = _copyRequest(
          request,
          status: TransactionStatus.failed,
          identifiers: merged,
          resultDescription: acknowledgment.description,
          settledAt: now,
        );
        transaction.replaceData(
          _copyData(
            transaction.data,
            requests: _replaceRequest(transaction.data.requests, updated),
            reservations: release?.reservations,
            globalReserved: release?.globalReserved,
            categories: release?.categories,
            asOf: now,
          ),
        );
        return _memoForRequest(transaction, updated);
    }
  });

  _ResolutionPlan _applyProviderResolution(
    FundsRepositoryTransaction transaction,
    ProviderResolution resolution,
    String fingerprint,
  ) {
    final eventId = resolution.eventId.trim();
    final requestId = resolution.requestId.trim();
    final oldFingerprint = transaction.providerEventFingerprint(eventId);
    final request = requestId.isEmpty
        ? null
        : _requestById(transaction.data, requestId);
    if (oldFingerprint != null && oldFingerprint == fingerprint) {
      return _ResolutionPlan(_submittedMemo(request?.id));
    }

    final now = clock().toUtc();
    if (oldFingerprint != null) {
      final reason = 'Provider event ID was reused with different result data.';
      var data = transaction.data;
      if (request != null) {
        data = _copyData(
          data,
          requests: _replaceRequest(
            data.requests,
            _toReconciliation(request, reason),
          ),
          asOf: now,
        );
      }
      data = _appendProviderEvent(
        data,
        _providerEvent(
          resolution,
          eventId: eventId,
          requestId: request?.id ?? (requestId.isEmpty ? null : requestId),
          receivedAt: now,
          disposition: ProviderEventDisposition.quarantined,
          quarantineReason: reason,
        ),
      );
      transaction.replaceData(data);
      return _ResolutionPlan(_submittedMemo(request?.id));
    }

    transaction.bindProviderEvent(eventId, fingerprint);
    if (request == null) {
      final reason = requestId.isEmpty
          ? 'Provider result has no correlated request ID.'
          : 'Provider result references an unknown request.';
      transaction.replaceData(
        _appendProviderEvent(
          transaction.data,
          _providerEvent(
            resolution,
            eventId: eventId,
            requestId: requestId.isEmpty ? null : requestId,
            receivedAt: now,
            disposition: ProviderEventDisposition.quarantined,
            quarantineReason: reason,
          ),
        ),
      );
      return const _ResolutionPlan(
        FundsCommandMemo(disposition: CommandDisposition.applied),
      );
    }

    final incomingIdentifiers = _normalizeIdentifiers(resolution.identifiers);
    String? mismatch;
    try {
      _mergeIdentifiers(request.providerIdentifiers, incomingIdentifiers);
    } on _IdentifierConflict catch (conflict) {
      mismatch = conflict.message;
    }
    mismatch ??= _identifierCollision(
      transaction.data,
      incomingIdentifiers,
      request.id,
    );
    if (resolution.reportedAmount != null &&
        resolution.reportedAmount != request.quote.amount) {
      mismatch ??=
          'Provider reported an amount different from the accepted quote.';
    }
    final receipt = incomingIdentifiers.transactionReceipt;
    if (resolution.outcome == ProviderResolutionOutcome.succeeded &&
        (receipt == null || receipt.trim().isEmpty)) {
      mismatch ??= 'Successful provider result has no transaction receipt.';
    }
    if (receipt != null &&
        _receiptUsedByAnotherRequest(transaction.data, receipt, request.id)) {
      mismatch ??=
          'Provider receipt is already associated with another request.';
    }
    if (mismatch != null) {
      final updated = _toReconciliation(request, mismatch);
      var data = _copyData(
        transaction.data,
        requests: _replaceRequest(transaction.data.requests, updated),
        asOf: now,
      );
      final otherRequestId = receipt == null
          ? null
          : _requestWithReceipt(
              transaction.data,
              receipt,
              exceptId: request.id,
            )?.id;
      if (otherRequestId != null) {
        final other = _requestById(data, otherRequestId);
        if (other != null) {
          data = _copyData(
            data,
            requests: _replaceRequest(
              data.requests,
              _toReconciliation(other, mismatch),
            ),
          );
        }
      }
      data = _appendProviderEvent(
        data,
        _providerEvent(
          resolution,
          eventId: eventId,
          requestId: request.id,
          identifiers: incomingIdentifiers,
          receivedAt: now,
          disposition: ProviderEventDisposition.quarantined,
          quarantineReason: mismatch,
        ),
      );
      transaction.replaceData(data);
      return _ResolutionPlan(_memoForRequest(transaction, updated));
    }

    if (request.status == TransactionStatus.reconciliationRequired &&
        request.settledAt == null) {
      final reason =
          request.resultDescription ??
          'Request requires reconciliation before it can be settled.';
      transaction.replaceData(
        _appendProviderEvent(
          transaction.data,
          _providerEvent(
            resolution,
            eventId: eventId,
            requestId: request.id,
            identifiers: incomingIdentifiers,
            receivedAt: now,
            disposition: ProviderEventDisposition.quarantined,
            quarantineReason: reason,
          ),
        ),
      );
      return _ResolutionPlan(_memoForRequest(transaction, request));
    }

    final previousOutcome = _settledOutcome(request);
    if (previousOutcome != null) {
      if (resolution.outcome == ProviderResolutionOutcome.unknown) {
        final event = _providerEvent(
          resolution,
          eventId: eventId,
          requestId: request.id,
          identifiers: incomingIdentifiers,
          receivedAt: now,
          disposition: ProviderEventDisposition.duplicate,
        );
        transaction.replaceData(_appendProviderEvent(transaction.data, event));
        return _ResolutionPlan(_memoForRequest(transaction, request));
      }
      if (resolution.outcome == previousOutcome &&
          (resolution.outcome != ProviderResolutionOutcome.succeeded ||
              receipt == request.providerIdentifiers.transactionReceipt)) {
        final enriched = _copyRequest(
          request,
          identifiers: _mergeIdentifiers(
            request.providerIdentifiers,
            incomingIdentifiers,
          ),
        );
        var data = _copyData(
          transaction.data,
          requests: _replaceRequest(transaction.data.requests, enriched),
          asOf: now,
        );
        data = _appendProviderEvent(
          data,
          _providerEvent(
            resolution,
            eventId: eventId,
            requestId: request.id,
            identifiers: incomingIdentifiers,
            receivedAt: now,
            disposition: ProviderEventDisposition.duplicate,
          ),
        );
        transaction.replaceData(data);
        return _ResolutionPlan(_memoForRequest(transaction, enriched));
      }

      const reason =
          'Late provider result conflicts with an already settled request.';
      final reconciled = _toReconciliation(request, reason);
      var data = _copyData(
        transaction.data,
        requests: _replaceRequest(transaction.data.requests, reconciled),
        asOf: now,
      );
      data = _appendProviderEvent(
        data,
        _providerEvent(
          resolution,
          eventId: eventId,
          requestId: request.id,
          identifiers: incomingIdentifiers,
          receivedAt: now,
          disposition: ProviderEventDisposition.quarantined,
          quarantineReason: reason,
        ),
      );
      transaction.replaceData(data);
      return _ResolutionPlan(_memoForRequest(transaction, reconciled));
    }

    final mergedIdentifiers = _mergeIdentifiers(
      request.providerIdentifiers,
      incomingIdentifiers,
    );
    if (resolution.outcome == ProviderResolutionOutcome.unknown) {
      final updated = request.status == TransactionStatus.reconciliationRequired
          ? _copyRequest(
              request,
              identifiers: mergedIdentifiers,
              resultDescription: resolution.description,
            )
          : _copyRequest(
              request,
              status: TransactionStatus.awaitingVerification,
              identifiers: mergedIdentifiers,
              resultDescription: resolution.description,
            );
      var data = _copyData(
        transaction.data,
        requests: _replaceRequest(transaction.data.requests, updated),
        asOf: now,
      );
      data = _appendProviderEvent(
        data,
        _providerEvent(
          resolution,
          eventId: eventId,
          requestId: request.id,
          identifiers: incomingIdentifiers,
          receivedAt: now,
          disposition: ProviderEventDisposition.applied,
        ),
      );
      transaction.replaceData(data);
      return _ResolutionPlan(_memoForRequest(transaction, updated));
    }

    if (resolution.outcome == ProviderResolutionOutcome.succeeded) {
      final settled = _settleSuccess(
        transaction.data,
        request,
        mergedIdentifiers,
        resolution.description,
        now,
      );
      if (settled == null) {
        const reason =
            'Funds required for settlement are not held by this request.';
        final reconciled = _toReconciliation(request, reason);
        var data = _copyData(
          transaction.data,
          requests: _replaceRequest(transaction.data.requests, reconciled),
          asOf: now,
        );
        data = _appendProviderEvent(
          data,
          _providerEvent(
            resolution,
            eventId: eventId,
            requestId: request.id,
            identifiers: incomingIdentifiers,
            receivedAt: now,
            disposition: ProviderEventDisposition.quarantined,
            quarantineReason: reason,
          ),
        );
        transaction.replaceData(data);
        return _ResolutionPlan(_memoForRequest(transaction, reconciled));
      }
      final updated = settled.requests.firstWhere(
        (item) => item.id == request.id,
      );
      final data = _appendProviderEvent(
        settled,
        _providerEvent(
          resolution,
          eventId: eventId,
          requestId: request.id,
          identifiers: incomingIdentifiers,
          receivedAt: now,
          disposition: ProviderEventDisposition.applied,
        ),
      );
      transaction.replaceData(data);
      return _ResolutionPlan(_memoForRequest(transaction, updated));
    }

    final released = _releaseReservation(transaction.data, request, now);
    if (request is OutgoingPaymentRequest && released == null) {
      const reason = 'Confirmed failure has no active reservation to release.';
      final reconciled = _toReconciliation(request, reason);
      var data = _copyData(
        transaction.data,
        requests: _replaceRequest(transaction.data.requests, reconciled),
        asOf: now,
      );
      data = _appendProviderEvent(
        data,
        _providerEvent(
          resolution,
          eventId: eventId,
          requestId: request.id,
          identifiers: incomingIdentifiers,
          receivedAt: now,
          disposition: ProviderEventDisposition.quarantined,
          quarantineReason: reason,
        ),
      );
      transaction.replaceData(data);
      return _ResolutionPlan(_memoForRequest(transaction, reconciled));
    }
    final updated = _copyRequest(
      request,
      status: TransactionStatus.failed,
      identifiers: mergedIdentifiers,
      resultDescription: resolution.description,
      settledAt: _settlementTime(request, now),
    );
    var data = _copyData(
      transaction.data,
      requests: _replaceRequest(transaction.data.requests, updated),
      reservations: released?.reservations,
      globalReserved: released?.globalReserved,
      categories: released?.categories,
      asOf: now,
    );
    data = _appendProviderEvent(
      data,
      _providerEvent(
        resolution,
        eventId: eventId,
        requestId: request.id,
        identifiers: incomingIdentifiers,
        receivedAt: now,
        disposition: ProviderEventDisposition.applied,
      ),
    );
    transaction.replaceData(data);
    return _ResolutionPlan(_memoForRequest(transaction, updated));
  }

  FundsData? _settleSuccess(
    FundsData data,
    TransactionRequest request,
    ProviderIdentifiers identifiers,
    String description,
    DateTime now,
  ) {
    final settledAt = _settlementTime(request, now);
    final operationId = 'ledger:request:${request.id}';
    if (request is DepositRequest) {
      final operation = LedgerOperation(
        id: operationId,
        walletId: actor.walletId,
        kind: LedgerOperationKind.deposit,
        transfers: [
          LedgerTransfer(
            source: LedgerBucket.external(
              'M-Pesa ${request.quote.payer.value}',
            ),
            destination: const LedgerBucket.global(),
            amount: request.quote.amount,
          ),
        ],
        postedAt: settledAt,
        requestId: request.id,
        description: description,
      );
      final updated = _copyRequest(
        request,
        status: TransactionStatus.succeeded,
        identifiers: identifiers,
        resultDescription: description,
        ledgerOperationId: operationId,
        settledAt: settledAt,
      );
      return _copyData(
        data,
        unallocated: data.wallet.unallocated + request.quote.amount,
        requests: _replaceRequest(data.requests, updated),
        ledger: [...data.ledger, operation],
        asOf: now,
      );
    }

    if (request is! OutgoingPaymentRequest) return null;
    final reservationIndex = data.reservations.indexWhere(
      (item) =>
          item.id == request.reservationId &&
          item.requestId == request.id &&
          item.status == ReservationStatus.active,
    );
    if (reservationIndex < 0) return null;
    final reservation = data.reservations[reservationIndex];
    if (reservation.funding.totalReserved != request.funding.totalReserved ||
        reservation.funding.quote.amount != request.quote.amount ||
        reservation.funding.quote.id != request.quote.id) {
      return null;
    }
    final category = _categoryBalance(data, request.quote.categoryId);
    if (category == null ||
        category.balance < request.funding.categoryContribution ||
        category.reserved < request.funding.categoryContribution ||
        data.wallet.unallocated < request.funding.globalContribution ||
        data.wallet.globalReserved < request.funding.globalContribution) {
      return null;
    }

    final transfers = <LedgerTransfer>[];
    if (request.funding.globalContribution != Money.zero) {
      transfers.add(
        LedgerTransfer(
          source: const LedgerBucket.global(),
          destination: LedgerBucket.category(request.quote.categoryId),
          amount: request.funding.globalContribution,
        ),
      );
    }
    transfers.add(
      LedgerTransfer(
        source: LedgerBucket.category(request.quote.categoryId),
        destination: LedgerBucket.external(_recipientReference(request.quote)),
        amount: request.quote.amount,
      ),
    );
    final operation = LedgerOperation(
      id: operationId,
      walletId: actor.walletId,
      kind: LedgerOperationKind.payment,
      transfers: transfers,
      postedAt: settledAt,
      requestId: request.id,
      description: description,
    );
    final updatedCategory = CategoryBalance(
      category: category.category,
      balance: category.balance - request.funding.categoryContribution,
      reserved: category.reserved - request.funding.categoryContribution,
    );
    final categories = data.wallet.categories
        .map(
          (item) => item.category.id == request.quote.categoryId
              ? updatedCategory
              : item,
        )
        .toList(growable: false);
    final updatedReservation = PaymentReservation(
      id: reservation.id,
      requestId: reservation.requestId,
      funding: reservation.funding,
      status: ReservationStatus.consumed,
      createdAt: reservation.createdAt,
      resolvedAt: settledAt,
    );
    final reservations = [...data.reservations];
    reservations[reservationIndex] = updatedReservation;
    final updatedRequest = _copyRequest(
      request,
      status: TransactionStatus.succeeded,
      identifiers: identifiers,
      resultDescription: description,
      ledgerOperationId: operationId,
      settledAt: settledAt,
    );
    return _copyData(
      data,
      unallocated: data.wallet.unallocated - request.funding.globalContribution,
      globalReserved:
          data.wallet.globalReserved - request.funding.globalContribution,
      categories: categories,
      requests: _replaceRequest(data.requests, updatedRequest),
      reservations: reservations,
      ledger: [...data.ledger, operation],
      asOf: now,
    );
  }

  _ReservationUpdate? _releaseReservation(
    FundsData data,
    TransactionRequest request,
    DateTime now,
  ) {
    if (request is! OutgoingPaymentRequest) return null;
    final index = data.reservations.indexWhere(
      (item) =>
          item.id == request.reservationId &&
          item.requestId == request.id &&
          item.status == ReservationStatus.active,
    );
    if (index < 0) return null;
    final reservation = data.reservations[index];
    final category = _categoryBalance(data, reservation.categoryId);
    if (category == null ||
        category.reserved < reservation.funding.categoryContribution ||
        data.wallet.globalReserved < reservation.funding.globalContribution) {
      return null;
    }
    final updatedReservation = PaymentReservation(
      id: reservation.id,
      requestId: reservation.requestId,
      funding: reservation.funding,
      status: ReservationStatus.released,
      createdAt: reservation.createdAt,
      resolvedAt: _settlementTime(request, now),
    );
    final reservations = [...data.reservations];
    reservations[index] = updatedReservation;
    final categories = data.wallet.categories
        .map(
          (item) => item.category.id == reservation.categoryId
              ? CategoryBalance(
                  category: item.category,
                  balance: item.balance,
                  reserved:
                      item.reserved - reservation.funding.categoryContribution,
                )
              : item,
        )
        .toList(growable: false);
    return _ReservationUpdate(
      reservations: reservations,
      globalReserved:
          data.wallet.globalReserved - reservation.funding.globalContribution,
      categories: categories,
    );
  }

  FundsData _copyData(
    FundsData data, {
    Money? unallocated,
    Money? globalReserved,
    List<CategoryBalance>? categories,
    List<TransactionRequest>? requests,
    List<PaymentReservation>? reservations,
    List<LedgerOperation>? ledger,
    List<ProviderEvent>? providerEvents,
    DateTime? asOf,
  }) => FundsData(
    wallet: WalletSnapshot(
      wallet: data.wallet.wallet,
      revision: data.wallet.revision,
      unallocated: unallocated ?? data.wallet.unallocated,
      globalReserved: globalReserved ?? data.wallet.globalReserved,
      categories: categories ?? data.wallet.categories,
      asOf: (asOf ?? clock()).toUtc(),
    ),
    requests: requests ?? data.requests,
    reservations: reservations ?? data.reservations,
    ledger: ledger ?? data.ledger,
    providerEvents: providerEvents ?? data.providerEvents,
  );

  FundsData _appendProviderEvent(FundsData data, ProviderEvent event) =>
      _copyData(data, providerEvents: [...data.providerEvents, event]);

  ProviderEvent _providerEvent(
    ProviderResolution resolution, {
    required String eventId,
    required String? requestId,
    ProviderIdentifiers? identifiers,
    required DateTime receivedAt,
    required ProviderEventDisposition disposition,
    String? quarantineReason,
  }) => ProviderEvent(
    id: eventId,
    requestId: requestId,
    identifiers: identifiers ?? _normalizeIdentifiers(resolution.identifiers),
    resultCode: resolution.outcome.name,
    resultDescription: resolution.description,
    reportedAmount: resolution.reportedAmount,
    receivedAt: receivedAt,
    payloadReference: 'provider-event:$eventId',
    disposition: disposition,
    quarantineReason: quarantineReason,
  );

  _RunPlan _complete(
    FundsRepositoryTransaction transaction,
    String commandId,
    FundsCommandMemo memo,
  ) {
    transaction.completeCommand(commandId, memo);
    return _RunPlan.cached(memo);
  }

  FundsCommandMemo _memoForRequest(
    FundsRepositoryTransaction transaction,
    TransactionRequest request,
  ) =>
      transaction.commandMemo(request.idempotencyKey) ??
      _submittedMemo(request.id);

  static FundsCommandMemo _submittedMemo(String? requestId) => FundsCommandMemo(
    disposition: CommandDisposition.submitted,
    requestId: requestId,
  );

  static FundsCommandMemo _applied() =>
      const FundsCommandMemo(disposition: CommandDisposition.applied);

  static FundsCommandMemo _rejected(
    FundsFailureCode code,
    String message, {
    FundingRequirement? fundingRequirement,
  }) => FundsCommandMemo(
    disposition: CommandDisposition.rejected,
    fundingRequirement: fundingRequirement,
    failure: FundsFailure(code, message),
  );

  static CommandResult _result(FundsCommandMemo memo, FundsData data) =>
      CommandResult(
        disposition: memo.disposition,
        data: data,
        requestId: memo.requestId,
        fundingRequirement: memo.fundingRequirement,
        failure: memo.failure,
      );

  static CategoryBalance? _categoryBalance(FundsData data, String id) => data
      .wallet
      .categories
      .where((item) => item.category.id == id.trim())
      .firstWhereOrNull;

  static TransactionRequest? _requestById(FundsData data, String id) =>
      data.requests.where((request) => request.id == id).firstWhereOrNull;

  static List<TransactionRequest> _replaceRequest(
    List<TransactionRequest> requests,
    TransactionRequest updated,
  ) => requests
      .map((item) => item.id == updated.id ? updated : item)
      .toList(growable: false);

  static TransactionRequest _copyRequest(
    TransactionRequest request, {
    TransactionStatus? status,
    ProviderIdentifiers? identifiers,
    String? resultDescription,
    String? ledgerOperationId,
    DateTime? settledAt,
  }) {
    final nextStatus = status ?? request.status;
    final nextIdentifiers = identifiers ?? request.providerIdentifiers;
    final nextDescription = resultDescription ?? request.resultDescription;
    final nextLedgerOperationId =
        ledgerOperationId ?? request.ledgerOperationId;
    final nextSettledAt = settledAt ?? request.settledAt;
    if (request is DepositRequest) {
      return DepositRequest(
        id: request.id,
        idempotencyKey: request.idempotencyKey,
        quote: request.quote,
        status: nextStatus,
        providerIdentifiers: nextIdentifiers,
        createdAt: request.createdAt,
        resultDescription: nextDescription,
        ledgerOperationId: nextLedgerOperationId,
        settledAt: nextSettledAt,
      );
    }
    final outgoing = request as OutgoingPaymentRequest;
    return OutgoingPaymentRequest(
      id: outgoing.id,
      idempotencyKey: outgoing.idempotencyKey,
      funding: outgoing.funding,
      reservationId: outgoing.reservationId,
      status: nextStatus,
      providerIdentifiers: nextIdentifiers,
      createdAt: outgoing.createdAt,
      resultDescription: nextDescription,
      ledgerOperationId: nextLedgerOperationId,
      settledAt: nextSettledAt,
    );
  }

  static TransactionRequest _toReconciliation(
    TransactionRequest request,
    String reason,
  ) {
    if (request.status == TransactionStatus.reconciliationRequired &&
        request.resultDescription == reason) {
      return request;
    }
    return _copyRequest(
      request,
      status: TransactionStatus.reconciliationRequired,
      resultDescription: reason,
    );
  }

  static ProviderResolutionOutcome? _settledOutcome(
    TransactionRequest request,
  ) {
    if (request.status == TransactionStatus.succeeded) {
      return ProviderResolutionOutcome.succeeded;
    }
    if (request.status == TransactionStatus.failed) {
      return ProviderResolutionOutcome.failed;
    }
    if (request.status == TransactionStatus.reconciliationRequired &&
        request.settledAt != null) {
      return request.ledgerOperationId == null
          ? ProviderResolutionOutcome.failed
          : ProviderResolutionOutcome.succeeded;
    }
    return null;
  }

  static String _recipientReference(PaymentQuote quote) =>
      switch (quote.recipient) {
        PhoneRecipient(:final phoneNumber) => phoneNumber.value,
        TillRecipient(:final tillNumber) => 'Till $tillNumber',
        PaybillRecipient(:final paybillNumber, :final accountReference) =>
          'Paybill $paybillNumber / $accountReference',
      };

  static String _requestId(String commandId) => 'request:$commandId';

  static String _reservationId(String requestId) => 'reservation:$requestId';

  DateTime _safeNowFor(TransactionRequest request) {
    final now = clock().toUtc();
    return now.isBefore(request.createdAt) ? request.createdAt : now;
  }

  static DateTime _settlementTime(TransactionRequest request, DateTime now) =>
      now.isBefore(request.createdAt) ? request.createdAt : now;

  bool _receiptUsedByAnotherRequest(
    FundsData data,
    String receipt,
    String id,
  ) =>
      _requestWithReceipt(data, receipt, exceptId: id) != null ||
      data.providerEvents.any(
        (event) =>
            event.identifiers.transactionReceipt == receipt &&
            event.requestId != id,
      );

  static String? _identifierCollision(
    FundsData data,
    ProviderIdentifiers incoming,
    String requestId,
  ) {
    final normalized = _normalizeIdentifiers(incoming);
    final requestCollision = data.requests.where((request) {
      return request.id != requestId &&
          _identifiersOverlap(request.providerIdentifiers, normalized);
    }).firstWhereOrNull;
    if (requestCollision != null) {
      return 'Provider identifiers are already associated with another request.';
    }
    final eventCollision = data.providerEvents.where((event) {
      return event.requestId != requestId &&
          _identifiersOverlap(event.identifiers, normalized);
    }).firstWhereOrNull;
    if (eventCollision != null) {
      return 'Provider identifiers already appear on another provider event.';
    }
    return null;
  }

  static bool _identifiersOverlap(
    ProviderIdentifiers left,
    ProviderIdentifiers right,
  ) {
    final a = _normalizeIdentifiers(left);
    final b = _normalizeIdentifiers(right);
    bool overlaps(String? x, String? y) => x != null && x == y;
    return overlaps(a.merchantRequestId, b.merchantRequestId) ||
        overlaps(a.checkoutRequestId, b.checkoutRequestId) ||
        overlaps(a.originatorConversationId, b.originatorConversationId) ||
        overlaps(a.conversationId, b.conversationId) ||
        overlaps(a.transactionReceipt, b.transactionReceipt);
  }

  static TransactionRequest? _requestWithReceipt(
    FundsData data,
    String receipt, {
    required String exceptId,
  }) => data.requests
      .where(
        (request) =>
            request.id != exceptId &&
            request.providerIdentifiers.transactionReceipt == receipt,
      )
      .firstWhereOrNull;

  static ProviderIdentifiers _normalizeIdentifiers(ProviderIdentifiers ids) =>
      ProviderIdentifiers(
        merchantRequestId: _normalizedIdentifier(ids.merchantRequestId),
        checkoutRequestId: _normalizedIdentifier(ids.checkoutRequestId),
        originatorConversationId: _normalizedIdentifier(
          ids.originatorConversationId,
        ),
        conversationId: _normalizedIdentifier(ids.conversationId),
        transactionReceipt: _normalizedIdentifier(ids.transactionReceipt),
      );

  static String? _normalizedIdentifier(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static ProviderIdentifiers _mergeIdentifiers(
    ProviderIdentifiers existing,
    ProviderIdentifiers incoming,
  ) {
    final old = _normalizeIdentifiers(existing);
    final next = _normalizeIdentifiers(incoming);
    String? merge(String? field, String? newValue, String name) {
      if (field != null && newValue != null && field != newValue) {
        throw _IdentifierConflict(
          'Provider $name does not match this request.',
        );
      }
      return field ?? newValue;
    }

    return ProviderIdentifiers(
      merchantRequestId: merge(
        old.merchantRequestId,
        next.merchantRequestId,
        'merchant request ID',
      ),
      checkoutRequestId: merge(
        old.checkoutRequestId,
        next.checkoutRequestId,
        'checkout request ID',
      ),
      originatorConversationId: merge(
        old.originatorConversationId,
        next.originatorConversationId,
        'originator conversation ID',
      ),
      conversationId: merge(
        old.conversationId,
        next.conversationId,
        'conversation ID',
      ),
      transactionReceipt: merge(
        old.transactionReceipt,
        next.transactionReceipt,
        'transaction receipt',
      ),
    );
  }

  static bool _sameIdentifiers(ProviderIdentifiers a, ProviderIdentifiers b) =>
      a.merchantRequestId == b.merchantRequestId &&
      a.checkoutRequestId == b.checkoutRequestId &&
      a.originatorConversationId == b.originatorConversationId &&
      a.conversationId == b.conversationId &&
      a.transactionReceipt == b.transactionReceipt;

  static String _commandFingerprint(FundsCommand command) =>
      jsonEncode(switch (command) {
        CreateCategoryCommand(:final category) => [
          'createCategory',
          category.id,
          category.walletId,
          category.name,
          category.kind.name,
          category.target.minorUnits,
          category.createdAt.microsecondsSinceEpoch,
          category.archivedAt?.microsecondsSinceEpoch,
        ],
        EditCategoryCommand(:final categoryId, :final name, :final target) => [
          'editCategory',
          categoryId.trim(),
          name.trim(),
          target.minorUnits,
        ],
        ArchiveCategoryCommand(:final categoryId) => [
          'archiveCategory',
          categoryId.trim(),
        ],
        AllocateCommand(:final categoryId, :final amount) => [
          'allocate',
          categoryId.trim(),
          amount.minorUnits,
        ],
        ReleaseCommand(:final categoryId, :final amount) => [
          'release',
          categoryId.trim(),
          amount.minorUnits,
        ],
        DepositCommand(:final quote) => [
          'deposit',
          quote.id,
          quote.walletId,
          quote.payer.value,
          quote.amount.minorUnits,
          quote.createdAt.microsecondsSinceEpoch,
          quote.expiresAt.microsecondsSinceEpoch,
        ],
        SpendCommand(:final quote) => [
          'spend',
          quote.id,
          quote.walletId,
          quote.categoryId,
          _recipientFingerprint(quote),
          quote.amount.minorUnits,
          quote.createdAt.microsecondsSinceEpoch,
          quote.expiresAt.microsecondsSinceEpoch,
          // Exclude approval so the same quote key remains retryable.
        ],
      });

  static String _fingerprintForRequest(TransactionRequest request) =>
      switch (request) {
        DepositRequest() => _commandFingerprint(
          DepositCommand(
            commandId: request.idempotencyKey,
            quote: request.quote,
          ),
        ),
        OutgoingPaymentRequest() => _commandFingerprint(
          SpendCommand(commandId: request.idempotencyKey, quote: request.quote),
        ),
      };

  static List<Object?> _recipientFingerprint(PaymentQuote quote) =>
      switch (quote.recipient) {
        PhoneRecipient(:final phoneNumber) => ['phone', phoneNumber.value],
        TillRecipient(:final tillNumber) => ['till', tillNumber],
        PaybillRecipient(:final paybillNumber, :final accountReference) => [
          'paybill',
          paybillNumber,
          accountReference,
        ],
      };

  static String _providerFingerprint(ProviderResolution resolution) =>
      jsonEncode([
        resolution.requestId.trim(),
        resolution.outcome.name,
        resolution.identifiers.merchantRequestId?.trim(),
        resolution.identifiers.checkoutRequestId?.trim(),
        resolution.identifiers.originatorConversationId?.trim(),
        resolution.identifiers.conversationId?.trim(),
        resolution.identifiers.transactionReceipt?.trim(),
        resolution.description,
        resolution.reportedAmount?.minorUnits,
      ]);
}

final class _RunPlan {
  const _RunPlan._({
    required this.memo,
    this.dispatchRequest,
    this.conflict = false,
  });

  const _RunPlan.conflict() : this._(memo: null, conflict: true);

  const _RunPlan.cached(FundsCommandMemo memo) : this._(memo: memo);

  const _RunPlan.immediate(FundsCommandMemo memo) : this._(memo: memo);

  const _RunPlan.dispatch(FundsCommandMemo memo, TransactionRequest request)
    : this._(memo: memo, dispatchRequest: request);

  final FundsCommandMemo? memo;
  final TransactionRequest? dispatchRequest;
  final bool conflict;
}

final class _ResolutionPlan {
  const _ResolutionPlan(this.memo);
  final FundsCommandMemo memo;
}

final class _ReservationUpdate {
  const _ReservationUpdate({
    required this.reservations,
    required this.globalReserved,
    required this.categories,
  });

  final List<PaymentReservation> reservations;
  final Money globalReserved;
  final List<CategoryBalance> categories;
}

final class _IdentifierConflict implements Exception {
  const _IdentifierConflict(this.message);
  final String message;
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? get firstWhereOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
