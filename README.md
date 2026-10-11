# Budget Buddy

A fresh foundation for a Flutter web-first app that deposits funds through the
M-Pesa Daraja sandbox, allocates them to categories, and pays from those categories.
Each spend uses one complete transaction amount for funding and settlement.

Current stage: **UI-independent funds flows and Signals state**. The local
reference repository and controlled provider exercise commands, reservations,
settlement, and UI state. Screens, hosted storage, and live Daraja execution
remain future work. No app entry point is included at this stage.

- [Prototype spec](doc/funds-prototype-spec.md)
- [Model review](doc/models.md)
- [Design agent prompt](doc/design-agent-prompt.md)
- [Dart model exports](lib/budgetbuddy_models.dart)
- [Flow implementation and boundaries](doc/ui-independent-flows.md)
- [Fixtures and expected UI states](doc/flow-fixtures.md)
- [Application exports](lib/budgetbuddy_flows.dart)
- [Signals controller exports](lib/budgetbuddy_state.dart)

## Development

The project uses FVM-managed Flutter **3.47.5** / Dart **3.13.4** and Signals
**7.1.0**.

```sh
fvm use 3.47.5 --skip-pub-get
fvm flutter pub get
fvm flutter analyze
fvm flutter test
```

The legacy app, platform scaffolds, assets, dependencies, and Firebase bindings
were removed on `rebuild/categorized-funds`, based on local `main` at
`03e51a9d2c6a1093153f5a84f399595bd3589845`. Fresh web/mobile scaffolds will be added
when screen implementation begins.

The original uncommitted work is preserved in Git stash
`Preserve working tree before categorized funds rebuild 2026-10-04`, with an
additional source archive at
`/private/tmp/budgetbuddy-before-rebuild-20261004T161829Z/workspace.tar.gz`.
