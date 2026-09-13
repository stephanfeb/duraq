import '../../duraq/test/support/dequeue_suite.dart';

import 'support/isar_backend.dart';

/// The shared suite from `duraq`, run against the Isar backend.
void main() {
  dequeueSuite('Isar', isarBackend('queue_dequeue'));
}
