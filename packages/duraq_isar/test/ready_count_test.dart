import '../../duraq/test/support/ready_count_suite.dart';

import 'support/isar_backend.dart';

/// The shared suite from `duraq`, run against the Isar backend.
void main() {
  readySuite('Isar', isarBackend('ready_count'));
}
