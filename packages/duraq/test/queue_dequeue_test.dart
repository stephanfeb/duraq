import 'support/dequeue_suite.dart';
import 'support/storage_backend.dart';

/// The shared suite, run against the SQLite backend. Its body lives in
/// `test/support/dequeue_suite.dart`, where `duraq_isar` runs the same one
/// against Isar, so both backends are held to one description.
void main() {
  dequeueSuite('SQLite', openSqlite);
}
