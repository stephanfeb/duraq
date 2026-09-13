import '../../duraq/test/support/contract_suite.dart';

import 'support/isar_backend.dart';

/// The shared suite from `duraq`, run against the Isar backend.
void main() {
  contractSuite('Isar', isarBackend('contract'));
}
