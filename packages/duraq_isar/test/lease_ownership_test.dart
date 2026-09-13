import '../../duraq/test/support/lease_ownership_suite.dart';

import 'support/isar_backend.dart';

/// The shared suite from `duraq`, run against the Isar backend.
void main() {
  leaseSuite('Isar', isarBackend('lease_ownership'));
}
