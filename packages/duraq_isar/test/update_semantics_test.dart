import '../../duraq/test/support/update_semantics_suite.dart';

import 'support/isar_backend.dart';

/// The shared suite from `duraq`, run against the Isar backend.
void main() {
  updateSuite('Isar', isarBackend('update_semantics'));
}
