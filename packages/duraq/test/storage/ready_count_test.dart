import '../support/ready_count_suite.dart';
import '../support/storage_backend.dart';

/// The shared suite, run against the SQLite backend. Its body lives in
/// `test/support/ready_count_suite.dart`, where `duraq_isar` runs the same one
/// against Isar, so both backends are held to one description.
void main() {
  readySuite('SQLite', openSqlite);
}
