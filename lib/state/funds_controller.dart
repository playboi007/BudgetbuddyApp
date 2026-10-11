import 'dart:async';

import 'package:signals/signals.dart';

import '../application/contracts.dart';
import '../budgetbuddy_models.dart';

enum FundsControllerStatus { initial, loading, ready, failed, disposed }

final class FundsControllerError {
  const FundsControllerError({
    required this.cause,
    this.failure,
    this.stackTrace,
  });

  factory FundsControllerError.from(Object cause, [StackTrace? stackTrace]) =>
      FundsControllerError(
        cause: cause,
        failure: cause is FundsException ? cause.failure : null,
        stackTrace: stackTrace,
      );

  final Object cause;
  final FundsFailure? failure;
  final StackTrace? stackTrace;

  String get message => failure?.message ?? cause.toString();
}

final class FundsCommandState {
  const FundsCommandState({
    this.isBusy = false,
    this.commandId,
    this.result,
    this.error,
    this.approvalRequirement,
  });

  final bool isBusy;
  final String? commandId;
  final CommandResult? result;
  final FundsControllerError? error;

  /// Cleared when its calculation no longer matches the latest snapshot.
  final FundingRequirement? approvalRequirement;

  FundsFailure? get failure => error?.failure ?? result?.failure;
}

/// Signals facade; financial rules stay in the application layer.
final class FundsController {
  FundsController(this._application, {FundsClock? clock})
    : _clock = clock ?? DateTime.now {
    _wallet = computed(() => _data.value?.wallet);
    _categories = computed(
      () => _data.value?.wallet.categories ?? const <CategoryBalance>[],
    );
    _globalAvailable = computed(() => _data.value?.wallet.availableGlobal);
    _total = computed(() => _data.value?.wallet.total);
    _allocated = computed(() => _data.value?.wallet.allocated);
    _reserved = computed(() => _data.value?.wallet.reserved);
    _availableTotal = computed(() => _data.value?.wallet.availableTotal);
    _reservations = computed(
      () => _data.value?.reservations ?? const <PaymentReservation>[],
    );
    _requests = computed(
      () => _data.value?.requests ?? const <TransactionRequest>[],
    );
    _ledger = computed(() => _data.value?.ledger ?? const <LedgerOperation>[]);
    _providerEvents = computed(
      () => _data.value?.providerEvents ?? const <ProviderEvent>[],
    );
  }

  final FundsApplication _application;
  final FundsClock _clock;

  final Signal<FundsData?> _data = signal<FundsData?>(null);
  final Signal<FundsControllerStatus> _loadStatus = signal(
    FundsControllerStatus.initial,
  );
  final Signal<FundsControllerError?> _loadError =
      signal<FundsControllerError?>(null);
  final Signal<FundsControllerError?> _watchError =
      signal<FundsControllerError?>(null);
  final Signal<FundsCommandState> _commandState = signal(
    const FundsCommandState(),
  );

  late final Computed<WalletSnapshot?> _wallet;
  late final Computed<List<CategoryBalance>> _categories;
  late final Computed<Money?> _globalAvailable;
  late final Computed<Money?> _total;
  late final Computed<Money?> _allocated;
  late final Computed<Money?> _reserved;
  late final Computed<Money?> _availableTotal;
  late final Computed<List<PaymentReservation>> _reservations;
  late final Computed<List<TransactionRequest>> _requests;
  late final Computed<List<LedgerOperation>> _ledger;
  late final Computed<List<ProviderEvent>> _providerEvents;

  StreamSubscription<FundsData>? _subscription;
  Future<void>? _initializeFuture;
  bool _disposed = false;
  int _loadGeneration = 0;
  int _snapshotGeneration = 0;
  String? _approvalWalletId;
  String? _approvalRevision;

  ReadonlySignal<FundsData?> get data => _data;
  ReadonlySignal<FundsControllerStatus> get loadStatus => _loadStatus;
  ReadonlySignal<FundsControllerError?> get loadError => _loadError;
  ReadonlySignal<FundsControllerError?> get watchError => _watchError;
  ReadonlySignal<FundsCommandState> get commandState => _commandState;

  ReadonlySignal<WalletSnapshot?> get wallet => _wallet;
  ReadonlySignal<List<CategoryBalance>> get categories => _categories;
  ReadonlySignal<Money?> get globalAvailable => _globalAvailable;
  ReadonlySignal<Money?> get total => _total;
  ReadonlySignal<Money?> get allocated => _allocated;
  ReadonlySignal<Money?> get reserved => _reserved;
  ReadonlySignal<Money?> get availableTotal => _availableTotal;
  ReadonlySignal<List<PaymentReservation>> get reservations => _reservations;
  ReadonlySignal<List<TransactionRequest>> get requests => _requests;
  ReadonlySignal<List<LedgerOperation>> get ledger => _ledger;
  ReadonlySignal<List<ProviderEvent>> get providerEvents => _providerEvents;

  bool get isDisposed => _disposed;

  /// Starts watching before loading so a newer stream event wins a load race.
  Future<void> initialize() {
    _ensureActive();
    final existing = _initializeFuture;
    if (existing != null) return existing;

    try {
      _subscription = _application.watch().listen(
        _acceptWatchSnapshot,
        onError: _handleWatchError,
        onDone: _handleWatchDone,
      );
    } catch (error, stackTrace) {
      _handleWatchError(error, stackTrace);
    }

    final future = refresh();
    _initializeFuture = future;
    return future;
  }

  /// Reloads state; newer snapshots or loads make an older response stale.
  /// Failures retain the last accepted snapshot and populate [loadError].
  Future<void> refresh() async {
    _ensureActive();
    final loadGeneration = ++_loadGeneration;
    final snapshotGeneration = _snapshotGeneration;
    _loadStatus.value = FundsControllerStatus.loading;
    _loadError.value = null;

    try {
      final loaded = await _application.load();
      if (!_mayApplyLoad(loadGeneration, snapshotGeneration)) return;
      _acceptSnapshot(loaded);
    } catch (error, stackTrace) {
      if (!_mayApplyLoad(loadGeneration, snapshotGeneration)) return;
      _loadStatus.value = FundsControllerStatus.failed;
      _loadError.value = FundsControllerError.from(error, stackTrace);
    }
  }

  /// Runs one command; concurrent calls and exceptions return `null`.
  /// If funds change mid-command, stale results cannot expose approval requests.
  Future<CommandResult?> execute(FundsCommand command) async {
    _ensureActive();
    if (_commandState.value.isBusy) return null;

    final snapshotGeneration = _snapshotGeneration;
    _commandState.value = FundsCommandState(
      isBusy: true,
      commandId: command.commandId,
    );
    _approvalWalletId = null;
    _approvalRevision = null;

    try {
      final result = await _application.execute(command);
      if (_disposed) return null;

      final versionUnchanged = _snapshotGeneration == snapshotGeneration;
      final current = _data.peek();
      final resultRevisionMatchesCurrent =
          current != null &&
          current.wallet.wallet.id == result.data.wallet.wallet.id &&
          current.wallet.revision == result.data.wallet.revision;
      final resultMatchesCurrentSnapshot =
          versionUnchanged || resultRevisionMatchesCurrent;
      if (versionUnchanged) {
        _acceptSnapshot(result.data);
      }

      final approvalRequirement =
          resultMatchesCurrentSnapshot &&
              result.disposition == CommandDisposition.requiresGlobalApproval
          ? result.fundingRequirement
          : null;
      if (approvalRequirement != null) {
        _approvalWalletId = result.data.wallet.wallet.id;
        _approvalRevision = result.data.wallet.revision;
      }
      _commandState.value = FundsCommandState(
        isBusy: true,
        commandId: command.commandId,
        result: result,
        approvalRequirement: approvalRequirement,
      );
      return result;
    } catch (error, stackTrace) {
      if (_disposed) return null;
      _approvalWalletId = null;
      _approvalRevision = null;
      _commandState.value = FundsCommandState(
        isBusy: true,
        commandId: command.commandId,
        error: FundsControllerError.from(error, stackTrace),
      );
      return null;
    } finally {
      if (!_disposed && _commandState.value.commandId == command.commandId) {
        final current = _commandState.value;
        _commandState.value = FundsCommandState(
          commandId: current.commandId,
          result: current.result,
          error: current.error,
          approvalRequirement: current.approvalRequirement,
        );
      }
    }
  }

  /// Previews funding from the latest snapshot; backend validation stays authoritative.
  /// Global shortfalls need explicit approval, invalidated when funds change.
  FundingRequirement? previewFunding(PaymentQuote quote) {
    final current = _data.peek();
    if (current == null ||
        quote.walletId != current.wallet.wallet.id ||
        !quote.isValidAt(_clock())) {
      return null;
    }

    CategoryBalance? selected;
    for (final category in current.wallet.categories) {
      if (category.category.id == quote.categoryId) {
        selected = category;
        break;
      }
    }
    if (selected == null || selected.category.isArchived) return null;

    return FundingRequirement(
      quote: quote,
      categoryAvailable: selected.available,
      globalAvailable: current.wallet.availableGlobal,
    );
  }

  /// Cancels observation and disposes computed Signals owned by this facade.
  /// Source Signals keep terminal values; callers must dispose effects they created.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _loadStatus.value = FundsControllerStatus.disposed;
    _approvalWalletId = null;
    _approvalRevision = null;
    final command = _commandState.value;
    if (command.isBusy) {
      _commandState.value = FundsCommandState(
        commandId: command.commandId,
        result: command.result,
        error: command.error,
        approvalRequirement: command.approvalRequirement,
      );
    }
    final subscription = _subscription;
    _subscription = null;
    try {
      await subscription?.cancel();
    } finally {
      for (final computedSignal in [
        _wallet,
        _categories,
        _globalAvailable,
        _total,
        _allocated,
        _reserved,
        _availableTotal,
        _reservations,
        _requests,
        _ledger,
        _providerEvents,
      ]) {
        computedSignal.dispose();
      }
    }
  }

  bool _mayApplyLoad(int loadGeneration, int snapshotGeneration) =>
      !_disposed &&
      loadGeneration == _loadGeneration &&
      snapshotGeneration == _snapshotGeneration;

  void _acceptWatchSnapshot(FundsData snapshot) {
    if (_disposed) return;
    _acceptSnapshot(snapshot);
    _watchError.value = null;
  }

  void _acceptSnapshot(FundsData snapshot) {
    if (_disposed) return;
    _snapshotGeneration++;
    _data.value = snapshot;
    _loadStatus.value = FundsControllerStatus.ready;
    _loadError.value = null;

    final command = _commandState.value;
    if (command.approvalRequirement != null &&
        (snapshot.wallet.wallet.id != _approvalWalletId ||
            snapshot.wallet.revision != _approvalRevision)) {
      _approvalWalletId = null;
      _approvalRevision = null;
      _commandState.value = FundsCommandState(
        isBusy: command.isBusy,
        commandId: command.commandId,
        result: command.result,
        error: command.error,
      );
    }
  }

  void _handleWatchError(Object error, [StackTrace? stackTrace]) {
    if (_disposed) return;
    _watchError.value = FundsControllerError.from(error, stackTrace);
  }

  void _handleWatchDone() {
    if (_disposed) return;
    _watchError.value = FundsControllerError.from(
      StateError('Funds watch stream completed.'),
    );
  }

  void _ensureActive() {
    if (_disposed) throw StateError('FundsController has been disposed.');
  }
}
