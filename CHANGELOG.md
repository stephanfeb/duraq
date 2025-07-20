# Changelog

All notable changes to DuraQ will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **BREAKING CHANGE**: `IsarStorage` now requires an external Isar instance instead of creating its own
- `IsarStorage.create()` factory method has been removed
- `IsarStorage` constructor now accepts an `Isar` instance parameter
- `IsarStorage.dispose()` no longer closes the Isar instance (caller responsibility)
- Added `IsarStorage.requiredSchemas` static getter to help users configure Isar with required schemas

### Added
- Support for shared Isar instances across multiple components
- Better integration with external systems that manage Isar lifecycle
- Comprehensive documentation for new Isar usage patterns

### Migration Guide
**Before:**
```dart
final storage = await IsarStorage.create(dbPath: 'path/to/queue.isar');
// ... use storage
await storage.dispose(); // Closed Isar automatically
```

**After:**
```dart
await Isar.initializeIsarCore(download: true);
final isar = await Isar.open([
  ...IsarStorage.requiredSchemas,
  // Add your other schemas here
], directory: 'path/to/db');

final storage = IsarStorage(isar);
// ... use storage
await storage.dispose(); // Releases locks only
await isar.close(); // Caller manages Isar lifecycle
```

## [0.0.1] - 2024-01-24

### Added
- Initial release with core functionality
- Queue management system with type safety
- SQLite storage backend implementation
- Queue entry tracking and metadata
- Comprehensive test suite
- Basic documentation and examples
