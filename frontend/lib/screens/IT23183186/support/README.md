# Environmental and disease-analysis support

The tests folder contains this component's test implementations, grouped here as requested. Application screen files remain directly in lib/screens. Small launchers remain in test/ so flutter test discovers each suite exactly once. Relative imports between these suites remain valid; launchers re-export helpers for compatibility. No production app route imports the test implementations, and other members' test helpers remain in test/support.

Run from frontend: flutter test

The nested test analysis configuration permits dev-dependency imports and test-only mock APIs in this folder. It retains all other project analysis rules and does not change production dependencies.
