// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'isar_models.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetQueueCollectionCollection on Isar {
  IsarCollection<QueueCollection> get queueCollections => this.collection();
}

const QueueCollectionSchema = CollectionSchema(
  name: r'QueueCollection',
  id: -6448619581353768178,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'lastUpdatedAt': PropertySchema(
      id: 1,
      name: r'lastUpdatedAt',
      type: IsarType.dateTime,
    ),
    r'name': PropertySchema(
      id: 2,
      name: r'name',
      type: IsarType.string,
    )
  },
  estimateSize: _queueCollectionEstimateSize,
  serialize: _queueCollectionSerialize,
  deserialize: _queueCollectionDeserialize,
  deserializeProp: _queueCollectionDeserializeProp,
  idName: r'id',
  indexes: {
    r'name': IndexSchema(
      id: 879695947855722453,
      name: r'name',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'name',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _queueCollectionGetId,
  getLinks: _queueCollectionGetLinks,
  attach: _queueCollectionAttach,
  version: '3.1.0+1',
);

int _queueCollectionEstimateSize(
  QueueCollection object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _queueCollectionSerialize(
  QueueCollection object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeDateTime(offsets[1], object.lastUpdatedAt);
  writer.writeString(offsets[2], object.name);
}

QueueCollection _queueCollectionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = QueueCollection();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.lastUpdatedAt = reader.readDateTime(offsets[1]);
  object.name = reader.readString(offsets[2]);
  return object;
}

P _queueCollectionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _queueCollectionGetId(QueueCollection object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _queueCollectionGetLinks(QueueCollection object) {
  return [];
}

void _queueCollectionAttach(
    IsarCollection<dynamic> col, Id id, QueueCollection object) {
  object.id = id;
}

extension QueueCollectionByIndex on IsarCollection<QueueCollection> {
  Future<QueueCollection?> getByName(String name) {
    return getByIndex(r'name', [name]);
  }

  QueueCollection? getByNameSync(String name) {
    return getByIndexSync(r'name', [name]);
  }

  Future<bool> deleteByName(String name) {
    return deleteByIndex(r'name', [name]);
  }

  bool deleteByNameSync(String name) {
    return deleteByIndexSync(r'name', [name]);
  }

  Future<List<QueueCollection?>> getAllByName(List<String> nameValues) {
    final values = nameValues.map((e) => [e]).toList();
    return getAllByIndex(r'name', values);
  }

  List<QueueCollection?> getAllByNameSync(List<String> nameValues) {
    final values = nameValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'name', values);
  }

  Future<int> deleteAllByName(List<String> nameValues) {
    final values = nameValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'name', values);
  }

  int deleteAllByNameSync(List<String> nameValues) {
    final values = nameValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'name', values);
  }

  Future<Id> putByName(QueueCollection object) {
    return putByIndex(r'name', object);
  }

  Id putByNameSync(QueueCollection object, {bool saveLinks = true}) {
    return putByIndexSync(r'name', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByName(List<QueueCollection> objects) {
    return putAllByIndex(r'name', objects);
  }

  List<Id> putAllByNameSync(List<QueueCollection> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'name', objects, saveLinks: saveLinks);
  }
}

extension QueueCollectionQueryWhereSort
    on QueryBuilder<QueueCollection, QueueCollection, QWhere> {
  QueryBuilder<QueueCollection, QueueCollection, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension QueueCollectionQueryWhere
    on QueryBuilder<QueueCollection, QueueCollection, QWhereClause> {
  QueryBuilder<QueueCollection, QueueCollection, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterWhereClause> nameEqualTo(
      String name) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'name',
        value: [name],
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterWhereClause>
      nameNotEqualTo(String name) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [],
              upper: [name],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [name],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [name],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [],
              upper: [name],
              includeUpper: false,
            ));
      }
    });
  }
}

extension QueueCollectionQueryFilter
    on QueryBuilder<QueueCollection, QueueCollection, QFilterCondition> {
  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      lastUpdatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      lastUpdatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      lastUpdatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      lastUpdatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUpdatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterFilterCondition>
      nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }
}

extension QueueCollectionQueryObject
    on QueryBuilder<QueueCollection, QueueCollection, QFilterCondition> {}

extension QueueCollectionQueryLinks
    on QueryBuilder<QueueCollection, QueueCollection, QFilterCondition> {}

extension QueueCollectionQuerySortBy
    on QueryBuilder<QueueCollection, QueueCollection, QSortBy> {
  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy>
      sortByLastUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy>
      sortByLastUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy>
      sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }
}

extension QueueCollectionQuerySortThenBy
    on QueryBuilder<QueueCollection, QueueCollection, QSortThenBy> {
  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy>
      thenByLastUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy>
      thenByLastUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QAfterSortBy>
      thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }
}

extension QueueCollectionQueryWhereDistinct
    on QueryBuilder<QueueCollection, QueueCollection, QDistinct> {
  QueryBuilder<QueueCollection, QueueCollection, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QDistinct>
      distinctByLastUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdatedAt');
    });
  }

  QueryBuilder<QueueCollection, QueueCollection, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }
}

extension QueueCollectionQueryProperty
    on QueryBuilder<QueueCollection, QueueCollection, QQueryProperty> {
  QueryBuilder<QueueCollection, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<QueueCollection, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<QueueCollection, DateTime, QQueryOperations>
      lastUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdatedAt');
    });
  }

  QueryBuilder<QueueCollection, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetQueueEntryCollectionCollection on Isar {
  IsarCollection<QueueEntryCollection> get queueEntryCollections =>
      this.collection();
}

const QueueEntryCollectionSchema = CollectionSchema(
  name: r'QueueEntryCollection',
  id: 1139774818245501000,
  properties: {
    r'attempts': PropertySchema(
      id: 0,
      name: r'attempts',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'data': PropertySchema(
      id: 2,
      name: r'data',
      type: IsarType.string,
    ),
    r'entryId': PropertySchema(
      id: 3,
      name: r'entryId',
      type: IsarType.string,
    ),
    r'errorMessage': PropertySchema(
      id: 4,
      name: r'errorMessage',
      type: IsarType.string,
    ),
    r'expirationTimestamp': PropertySchema(
      id: 5,
      name: r'expirationTimestamp',
      type: IsarType.long,
    ),
    r'expiresAt': PropertySchema(
      id: 6,
      name: r'expiresAt',
      type: IsarType.dateTime,
    ),
    r'lastUpdatedAt': PropertySchema(
      id: 7,
      name: r'lastUpdatedAt',
      type: IsarType.dateTime,
    ),
    r'nextRetryAt': PropertySchema(
      id: 8,
      name: r'nextRetryAt',
      type: IsarType.dateTime,
    ),
    r'priority': PropertySchema(
      id: 9,
      name: r'priority',
      type: IsarType.long,
    ),
    r'queueName': PropertySchema(
      id: 10,
      name: r'queueName',
      type: IsarType.string,
    ),
    r'retrievalKey': PropertySchema(
      id: 11,
      name: r'retrievalKey',
      type: IsarType.string,
    ),
    r'retryTimestamp': PropertySchema(
      id: 12,
      name: r'retryTimestamp',
      type: IsarType.long,
    ),
    r'scheduledFor': PropertySchema(
      id: 13,
      name: r'scheduledFor',
      type: IsarType.dateTime,
    ),
    r'scheduledTimestamp': PropertySchema(
      id: 14,
      name: r'scheduledTimestamp',
      type: IsarType.long,
    ),
    r'status': PropertySchema(
      id: 15,
      name: r'status',
      type: IsarType.string,
      enumMap: _QueueEntryCollectionstatusEnumValueMap,
    )
  },
  estimateSize: _queueEntryCollectionEstimateSize,
  serialize: _queueEntryCollectionSerialize,
  deserialize: _queueEntryCollectionDeserialize,
  deserializeProp: _queueEntryCollectionDeserializeProp,
  idName: r'id',
  indexes: {
    r'entryId': IndexSchema(
      id: 3733379884318738402,
      name: r'entryId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'entryId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'queueName': IndexSchema(
      id: -6255641391181223237,
      name: r'queueName',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'queueName',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'expiresAt': IndexSchema(
      id: 4994901953235663716,
      name: r'expiresAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'expiresAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'scheduledFor': IndexSchema(
      id: -13963062187374339,
      name: r'scheduledFor',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'scheduledFor',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'nextRetryAt': IndexSchema(
      id: -8739505323881011336,
      name: r'nextRetryAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'nextRetryAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'attempts': IndexSchema(
      id: 2067170731140038399,
      name: r'attempts',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'attempts',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'priority': IndexSchema(
      id: -6477851841645083544,
      name: r'priority',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'priority',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'status': IndexSchema(
      id: -107785170620420283,
      name: r'status',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'status',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'retrievalKey_status_priority': IndexSchema(
      id: -8394728564768144936,
      name: r'retrievalKey_status_priority',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'retrievalKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'status',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'priority',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'expiration_index': IndexSchema(
      id: -5757265293708658063,
      name: r'expiration_index',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'expirationTimestamp',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'scheduled_index': IndexSchema(
      id: -639176907899392,
      name: r'scheduled_index',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'scheduledTimestamp',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'retry_index': IndexSchema(
      id: -3566064736063068951,
      name: r'retry_index',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'retryTimestamp',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _queueEntryCollectionGetId,
  getLinks: _queueEntryCollectionGetLinks,
  attach: _queueEntryCollectionAttach,
  version: '3.1.0+1',
);

int _queueEntryCollectionEstimateSize(
  QueueEntryCollection object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.data.length * 3;
  bytesCount += 3 + object.entryId.length * 3;
  {
    final value = object.errorMessage;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.queueName.length * 3;
  bytesCount += 3 + object.retrievalKey.length * 3;
  bytesCount += 3 + object.status.name.length * 3;
  return bytesCount;
}

void _queueEntryCollectionSerialize(
  QueueEntryCollection object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.attempts);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.data);
  writer.writeString(offsets[3], object.entryId);
  writer.writeString(offsets[4], object.errorMessage);
  writer.writeLong(offsets[5], object.expirationTimestamp);
  writer.writeDateTime(offsets[6], object.expiresAt);
  writer.writeDateTime(offsets[7], object.lastUpdatedAt);
  writer.writeDateTime(offsets[8], object.nextRetryAt);
  writer.writeLong(offsets[9], object.priority);
  writer.writeString(offsets[10], object.queueName);
  writer.writeString(offsets[11], object.retrievalKey);
  writer.writeLong(offsets[12], object.retryTimestamp);
  writer.writeDateTime(offsets[13], object.scheduledFor);
  writer.writeLong(offsets[14], object.scheduledTimestamp);
  writer.writeString(offsets[15], object.status.name);
}

QueueEntryCollection _queueEntryCollectionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = QueueEntryCollection();
  object.attempts = reader.readLong(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.data = reader.readString(offsets[2]);
  object.entryId = reader.readString(offsets[3]);
  object.errorMessage = reader.readStringOrNull(offsets[4]);
  object.expiresAt = reader.readDateTimeOrNull(offsets[6]);
  object.id = id;
  object.lastUpdatedAt = reader.readDateTime(offsets[7]);
  object.nextRetryAt = reader.readDateTimeOrNull(offsets[8]);
  object.priority = reader.readLong(offsets[9]);
  object.queueName = reader.readString(offsets[10]);
  object.scheduledFor = reader.readDateTimeOrNull(offsets[13]);
  object.status = _QueueEntryCollectionstatusValueEnumMap[
          reader.readStringOrNull(offsets[15])] ??
      EntryStatus.pending;
  return object;
}

P _queueEntryCollectionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readDateTime(offset)) as P;
    case 8:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readLongOrNull(offset)) as P;
    case 13:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 14:
      return (reader.readLongOrNull(offset)) as P;
    case 15:
      return (_QueueEntryCollectionstatusValueEnumMap[
              reader.readStringOrNull(offset)] ??
          EntryStatus.pending) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _QueueEntryCollectionstatusEnumValueMap = {
  r'pending': r'pending',
  r'processing': r'processing',
  r'completed': r'completed',
  r'failed': r'failed',
  r'expired': r'expired',
  r'deadLetter': r'deadLetter',
};
const _QueueEntryCollectionstatusValueEnumMap = {
  r'pending': EntryStatus.pending,
  r'processing': EntryStatus.processing,
  r'completed': EntryStatus.completed,
  r'failed': EntryStatus.failed,
  r'expired': EntryStatus.expired,
  r'deadLetter': EntryStatus.deadLetter,
};

Id _queueEntryCollectionGetId(QueueEntryCollection object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _queueEntryCollectionGetLinks(
    QueueEntryCollection object) {
  return [];
}

void _queueEntryCollectionAttach(
    IsarCollection<dynamic> col, Id id, QueueEntryCollection object) {
  object.id = id;
}

extension QueueEntryCollectionQueryWhereSort
    on QueryBuilder<QueueEntryCollection, QueueEntryCollection, QWhere> {
  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhere>
      anyExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'expiresAt'),
      );
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhere>
      anyScheduledFor() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'scheduledFor'),
      );
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhere>
      anyNextRetryAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'nextRetryAt'),
      );
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhere>
      anyAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'attempts'),
      );
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhere>
      anyPriority() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'priority'),
      );
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhere>
      anyExpirationTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'expiration_index'),
      );
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhere>
      anyScheduledTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'scheduled_index'),
      );
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhere>
      anyRetryTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'retry_index'),
      );
    });
  }
}

extension QueueEntryCollectionQueryWhere
    on QueryBuilder<QueueEntryCollection, QueueEntryCollection, QWhereClause> {
  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      entryIdEqualTo(String entryId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'entryId',
        value: [entryId],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      entryIdNotEqualTo(String entryId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entryId',
              lower: [],
              upper: [entryId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entryId',
              lower: [entryId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entryId',
              lower: [entryId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entryId',
              lower: [],
              upper: [entryId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      queueNameEqualTo(String queueName) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'queueName',
        value: [queueName],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      queueNameNotEqualTo(String queueName) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'queueName',
              lower: [],
              upper: [queueName],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'queueName',
              lower: [queueName],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'queueName',
              lower: [queueName],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'queueName',
              lower: [],
              upper: [queueName],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expiresAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'expiresAt',
        value: [null],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expiresAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'expiresAt',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expiresAtEqualTo(DateTime? expiresAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'expiresAt',
        value: [expiresAt],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expiresAtNotEqualTo(DateTime? expiresAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expiresAt',
              lower: [],
              upper: [expiresAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expiresAt',
              lower: [expiresAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expiresAt',
              lower: [expiresAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expiresAt',
              lower: [],
              upper: [expiresAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expiresAtGreaterThan(
    DateTime? expiresAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'expiresAt',
        lower: [expiresAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expiresAtLessThan(
    DateTime? expiresAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'expiresAt',
        lower: [],
        upper: [expiresAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expiresAtBetween(
    DateTime? lowerExpiresAt,
    DateTime? upperExpiresAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'expiresAt',
        lower: [lowerExpiresAt],
        includeLower: includeLower,
        upper: [upperExpiresAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledForIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'scheduledFor',
        value: [null],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledForIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'scheduledFor',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledForEqualTo(DateTime? scheduledFor) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'scheduledFor',
        value: [scheduledFor],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledForNotEqualTo(DateTime? scheduledFor) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'scheduledFor',
              lower: [],
              upper: [scheduledFor],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'scheduledFor',
              lower: [scheduledFor],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'scheduledFor',
              lower: [scheduledFor],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'scheduledFor',
              lower: [],
              upper: [scheduledFor],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledForGreaterThan(
    DateTime? scheduledFor, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'scheduledFor',
        lower: [scheduledFor],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledForLessThan(
    DateTime? scheduledFor, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'scheduledFor',
        lower: [],
        upper: [scheduledFor],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledForBetween(
    DateTime? lowerScheduledFor,
    DateTime? upperScheduledFor, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'scheduledFor',
        lower: [lowerScheduledFor],
        includeLower: includeLower,
        upper: [upperScheduledFor],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      nextRetryAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'nextRetryAt',
        value: [null],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      nextRetryAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'nextRetryAt',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      nextRetryAtEqualTo(DateTime? nextRetryAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'nextRetryAt',
        value: [nextRetryAt],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      nextRetryAtNotEqualTo(DateTime? nextRetryAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'nextRetryAt',
              lower: [],
              upper: [nextRetryAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'nextRetryAt',
              lower: [nextRetryAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'nextRetryAt',
              lower: [nextRetryAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'nextRetryAt',
              lower: [],
              upper: [nextRetryAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      nextRetryAtGreaterThan(
    DateTime? nextRetryAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'nextRetryAt',
        lower: [nextRetryAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      nextRetryAtLessThan(
    DateTime? nextRetryAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'nextRetryAt',
        lower: [],
        upper: [nextRetryAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      nextRetryAtBetween(
    DateTime? lowerNextRetryAt,
    DateTime? upperNextRetryAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'nextRetryAt',
        lower: [lowerNextRetryAt],
        includeLower: includeLower,
        upper: [upperNextRetryAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      attemptsEqualTo(int attempts) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'attempts',
        value: [attempts],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      attemptsNotEqualTo(int attempts) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'attempts',
              lower: [],
              upper: [attempts],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'attempts',
              lower: [attempts],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'attempts',
              lower: [attempts],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'attempts',
              lower: [],
              upper: [attempts],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      attemptsGreaterThan(
    int attempts, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'attempts',
        lower: [attempts],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      attemptsLessThan(
    int attempts, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'attempts',
        lower: [],
        upper: [attempts],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      attemptsBetween(
    int lowerAttempts,
    int upperAttempts, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'attempts',
        lower: [lowerAttempts],
        includeLower: includeLower,
        upper: [upperAttempts],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      priorityEqualTo(int priority) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'priority',
        value: [priority],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      priorityNotEqualTo(int priority) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'priority',
              lower: [],
              upper: [priority],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'priority',
              lower: [priority],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'priority',
              lower: [priority],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'priority',
              lower: [],
              upper: [priority],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      priorityGreaterThan(
    int priority, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'priority',
        lower: [priority],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      priorityLessThan(
    int priority, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'priority',
        lower: [],
        upper: [priority],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      priorityBetween(
    int lowerPriority,
    int upperPriority, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'priority',
        lower: [lowerPriority],
        includeLower: includeLower,
        upper: [upperPriority],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      statusEqualTo(EntryStatus status) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'status',
        value: [status],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      statusNotEqualTo(EntryStatus status) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [],
              upper: [status],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [status],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [status],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [],
              upper: [status],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retrievalKeyEqualToAnyStatusPriority(String retrievalKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'retrievalKey_status_priority',
        value: [retrievalKey],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retrievalKeyNotEqualToAnyStatusPriority(String retrievalKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retrievalKey_status_priority',
              lower: [],
              upper: [retrievalKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retrievalKey_status_priority',
              lower: [retrievalKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retrievalKey_status_priority',
              lower: [retrievalKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retrievalKey_status_priority',
              lower: [],
              upper: [retrievalKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retrievalKeyStatusEqualToAnyPriority(
          String retrievalKey, EntryStatus status) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'retrievalKey_status_priority',
        value: [retrievalKey, status],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retrievalKeyEqualToStatusNotEqualToAnyPriority(
          String retrievalKey, EntryStatus status) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retrievalKey_status_priority',
              lower: [retrievalKey],
              upper: [retrievalKey, status],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retrievalKey_status_priority',
              lower: [retrievalKey, status],
              includeLower: false,
              upper: [retrievalKey],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retrievalKey_status_priority',
              lower: [retrievalKey, status],
              includeLower: false,
              upper: [retrievalKey],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retrievalKey_status_priority',
              lower: [retrievalKey],
              upper: [retrievalKey, status],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retrievalKeyStatusPriorityEqualTo(
          String retrievalKey, EntryStatus status, int priority) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'retrievalKey_status_priority',
        value: [retrievalKey, status, priority],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retrievalKeyStatusEqualToPriorityNotEqualTo(
          String retrievalKey, EntryStatus status, int priority) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retrievalKey_status_priority',
              lower: [retrievalKey, status],
              upper: [retrievalKey, status, priority],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retrievalKey_status_priority',
              lower: [retrievalKey, status, priority],
              includeLower: false,
              upper: [retrievalKey, status],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retrievalKey_status_priority',
              lower: [retrievalKey, status, priority],
              includeLower: false,
              upper: [retrievalKey, status],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retrievalKey_status_priority',
              lower: [retrievalKey, status],
              upper: [retrievalKey, status, priority],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retrievalKeyStatusEqualToPriorityGreaterThan(
    String retrievalKey,
    EntryStatus status,
    int priority, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'retrievalKey_status_priority',
        lower: [retrievalKey, status, priority],
        includeLower: include,
        upper: [retrievalKey, status],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retrievalKeyStatusEqualToPriorityLessThan(
    String retrievalKey,
    EntryStatus status,
    int priority, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'retrievalKey_status_priority',
        lower: [retrievalKey, status],
        upper: [retrievalKey, status, priority],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retrievalKeyStatusEqualToPriorityBetween(
    String retrievalKey,
    EntryStatus status,
    int lowerPriority,
    int upperPriority, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'retrievalKey_status_priority',
        lower: [retrievalKey, status, lowerPriority],
        includeLower: includeLower,
        upper: [retrievalKey, status, upperPriority],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expirationTimestampIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'expiration_index',
        value: [null],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expirationTimestampIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'expiration_index',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expirationTimestampEqualTo(int? expirationTimestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'expiration_index',
        value: [expirationTimestamp],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expirationTimestampNotEqualTo(int? expirationTimestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expiration_index',
              lower: [],
              upper: [expirationTimestamp],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expiration_index',
              lower: [expirationTimestamp],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expiration_index',
              lower: [expirationTimestamp],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expiration_index',
              lower: [],
              upper: [expirationTimestamp],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expirationTimestampGreaterThan(
    int? expirationTimestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'expiration_index',
        lower: [expirationTimestamp],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expirationTimestampLessThan(
    int? expirationTimestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'expiration_index',
        lower: [],
        upper: [expirationTimestamp],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      expirationTimestampBetween(
    int? lowerExpirationTimestamp,
    int? upperExpirationTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'expiration_index',
        lower: [lowerExpirationTimestamp],
        includeLower: includeLower,
        upper: [upperExpirationTimestamp],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledTimestampIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'scheduled_index',
        value: [null],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledTimestampIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'scheduled_index',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledTimestampEqualTo(int? scheduledTimestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'scheduled_index',
        value: [scheduledTimestamp],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledTimestampNotEqualTo(int? scheduledTimestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'scheduled_index',
              lower: [],
              upper: [scheduledTimestamp],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'scheduled_index',
              lower: [scheduledTimestamp],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'scheduled_index',
              lower: [scheduledTimestamp],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'scheduled_index',
              lower: [],
              upper: [scheduledTimestamp],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledTimestampGreaterThan(
    int? scheduledTimestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'scheduled_index',
        lower: [scheduledTimestamp],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledTimestampLessThan(
    int? scheduledTimestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'scheduled_index',
        lower: [],
        upper: [scheduledTimestamp],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      scheduledTimestampBetween(
    int? lowerScheduledTimestamp,
    int? upperScheduledTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'scheduled_index',
        lower: [lowerScheduledTimestamp],
        includeLower: includeLower,
        upper: [upperScheduledTimestamp],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retryTimestampIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'retry_index',
        value: [null],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retryTimestampIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'retry_index',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retryTimestampEqualTo(int? retryTimestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'retry_index',
        value: [retryTimestamp],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retryTimestampNotEqualTo(int? retryTimestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retry_index',
              lower: [],
              upper: [retryTimestamp],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retry_index',
              lower: [retryTimestamp],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retry_index',
              lower: [retryTimestamp],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'retry_index',
              lower: [],
              upper: [retryTimestamp],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retryTimestampGreaterThan(
    int? retryTimestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'retry_index',
        lower: [retryTimestamp],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retryTimestampLessThan(
    int? retryTimestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'retry_index',
        lower: [],
        upper: [retryTimestamp],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterWhereClause>
      retryTimestampBetween(
    int? lowerRetryTimestamp,
    int? upperRetryTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'retry_index',
        lower: [lowerRetryTimestamp],
        includeLower: includeLower,
        upper: [upperRetryTimestamp],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension QueueEntryCollectionQueryFilter on QueryBuilder<QueueEntryCollection,
    QueueEntryCollection, QFilterCondition> {
  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> attemptsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attempts',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> attemptsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attempts',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> attemptsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attempts',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> attemptsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attempts',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> dataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'data',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> dataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'data',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> dataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'data',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> dataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'data',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> dataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'data',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> dataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'data',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
          QAfterFilterCondition>
      dataContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'data',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
          QAfterFilterCondition>
      dataMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'data',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> dataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'data',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> dataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'data',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> entryIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> entryIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> entryIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> entryIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'entryId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> entryIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> entryIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
          QAfterFilterCondition>
      entryIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
          QAfterFilterCondition>
      entryIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'entryId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> entryIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entryId',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> entryIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'entryId',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> errorMessageIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'errorMessage',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> errorMessageIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'errorMessage',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> errorMessageEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'errorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> errorMessageGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'errorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> errorMessageLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'errorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> errorMessageBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'errorMessage',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> errorMessageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'errorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> errorMessageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'errorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
          QAfterFilterCondition>
      errorMessageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'errorMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
          QAfterFilterCondition>
      errorMessageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'errorMessage',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> errorMessageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'errorMessage',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> errorMessageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'errorMessage',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> expirationTimestampIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'expirationTimestamp',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> expirationTimestampIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'expirationTimestamp',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> expirationTimestampEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expirationTimestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> expirationTimestampGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expirationTimestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> expirationTimestampLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expirationTimestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> expirationTimestampBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expirationTimestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> expiresAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'expiresAt',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> expiresAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'expiresAt',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> expiresAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> expiresAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> expiresAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> expiresAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expiresAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> lastUpdatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> lastUpdatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> lastUpdatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> lastUpdatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUpdatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> nextRetryAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'nextRetryAt',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> nextRetryAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'nextRetryAt',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> nextRetryAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nextRetryAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> nextRetryAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'nextRetryAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> nextRetryAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'nextRetryAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> nextRetryAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'nextRetryAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> priorityEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'priority',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> priorityGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'priority',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> priorityLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'priority',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> priorityBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'priority',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> queueNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'queueName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> queueNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'queueName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> queueNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'queueName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> queueNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'queueName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> queueNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'queueName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> queueNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'queueName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
          QAfterFilterCondition>
      queueNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'queueName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
          QAfterFilterCondition>
      queueNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'queueName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> queueNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'queueName',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> queueNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'queueName',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retrievalKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retrievalKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retrievalKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retrievalKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retrievalKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retrievalKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retrievalKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retrievalKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retrievalKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'retrievalKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retrievalKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'retrievalKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
          QAfterFilterCondition>
      retrievalKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'retrievalKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
          QAfterFilterCondition>
      retrievalKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'retrievalKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retrievalKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retrievalKey',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retrievalKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'retrievalKey',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retryTimestampIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'retryTimestamp',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retryTimestampIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'retryTimestamp',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retryTimestampEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retryTimestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retryTimestampGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retryTimestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retryTimestampLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retryTimestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> retryTimestampBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retryTimestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> scheduledForIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'scheduledFor',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> scheduledForIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'scheduledFor',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> scheduledForEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scheduledFor',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> scheduledForGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'scheduledFor',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> scheduledForLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'scheduledFor',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> scheduledForBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'scheduledFor',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> scheduledTimestampIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'scheduledTimestamp',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> scheduledTimestampIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'scheduledTimestamp',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> scheduledTimestampEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scheduledTimestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> scheduledTimestampGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'scheduledTimestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> scheduledTimestampLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'scheduledTimestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> scheduledTimestampBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'scheduledTimestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> statusEqualTo(
    EntryStatus value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> statusGreaterThan(
    EntryStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> statusLessThan(
    EntryStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> statusBetween(
    EntryStatus lower,
    EntryStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
          QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
          QAfterFilterCondition>
      statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection,
      QAfterFilterCondition> statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }
}

extension QueueEntryCollectionQueryObject on QueryBuilder<QueueEntryCollection,
    QueueEntryCollection, QFilterCondition> {}

extension QueueEntryCollectionQueryLinks on QueryBuilder<QueueEntryCollection,
    QueueEntryCollection, QFilterCondition> {}

extension QueueEntryCollectionQuerySortBy
    on QueryBuilder<QueueEntryCollection, QueueEntryCollection, QSortBy> {
  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempts', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByAttemptsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempts', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByErrorMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorMessage', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByErrorMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorMessage', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByExpirationTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expirationTimestamp', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByExpirationTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expirationTimestamp', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByLastUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByLastUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByNextRetryAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRetryAt', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByNextRetryAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRetryAt', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByPriority() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priority', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByPriorityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priority', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByQueueName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'queueName', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByQueueNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'queueName', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByRetrievalKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retrievalKey', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByRetrievalKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retrievalKey', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByRetryTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryTimestamp', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByRetryTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryTimestamp', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByScheduledFor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scheduledFor', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByScheduledForDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scheduledFor', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByScheduledTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scheduledTimestamp', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByScheduledTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scheduledTimestamp', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension QueueEntryCollectionQuerySortThenBy
    on QueryBuilder<QueueEntryCollection, QueueEntryCollection, QSortThenBy> {
  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempts', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByAttemptsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempts', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'data', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByErrorMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorMessage', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByErrorMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorMessage', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByExpirationTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expirationTimestamp', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByExpirationTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expirationTimestamp', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByLastUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByLastUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByNextRetryAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRetryAt', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByNextRetryAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextRetryAt', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByPriority() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priority', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByPriorityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priority', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByQueueName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'queueName', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByQueueNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'queueName', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByRetrievalKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retrievalKey', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByRetrievalKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retrievalKey', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByRetryTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryTimestamp', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByRetryTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryTimestamp', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByScheduledFor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scheduledFor', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByScheduledForDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scheduledFor', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByScheduledTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scheduledTimestamp', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByScheduledTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scheduledTimestamp', Sort.desc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QAfterSortBy>
      thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension QueueEntryCollectionQueryWhereDistinct
    on QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct> {
  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attempts');
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByData({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'data', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByEntryId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entryId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByErrorMessage({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'errorMessage', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByExpirationTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expirationTimestamp');
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expiresAt');
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByLastUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdatedAt');
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByNextRetryAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nextRetryAt');
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByPriority() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'priority');
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByQueueName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'queueName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByRetrievalKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retrievalKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByRetryTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retryTimestamp');
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByScheduledFor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scheduledFor');
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByScheduledTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scheduledTimestamp');
    });
  }

  QueryBuilder<QueueEntryCollection, QueueEntryCollection, QDistinct>
      distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }
}

extension QueueEntryCollectionQueryProperty on QueryBuilder<
    QueueEntryCollection, QueueEntryCollection, QQueryProperty> {
  QueryBuilder<QueueEntryCollection, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<QueueEntryCollection, int, QQueryOperations> attemptsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attempts');
    });
  }

  QueryBuilder<QueueEntryCollection, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<QueueEntryCollection, String, QQueryOperations> dataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'data');
    });
  }

  QueryBuilder<QueueEntryCollection, String, QQueryOperations>
      entryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entryId');
    });
  }

  QueryBuilder<QueueEntryCollection, String?, QQueryOperations>
      errorMessageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'errorMessage');
    });
  }

  QueryBuilder<QueueEntryCollection, int?, QQueryOperations>
      expirationTimestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expirationTimestamp');
    });
  }

  QueryBuilder<QueueEntryCollection, DateTime?, QQueryOperations>
      expiresAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expiresAt');
    });
  }

  QueryBuilder<QueueEntryCollection, DateTime, QQueryOperations>
      lastUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdatedAt');
    });
  }

  QueryBuilder<QueueEntryCollection, DateTime?, QQueryOperations>
      nextRetryAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nextRetryAt');
    });
  }

  QueryBuilder<QueueEntryCollection, int, QQueryOperations> priorityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'priority');
    });
  }

  QueryBuilder<QueueEntryCollection, String, QQueryOperations>
      queueNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'queueName');
    });
  }

  QueryBuilder<QueueEntryCollection, String, QQueryOperations>
      retrievalKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retrievalKey');
    });
  }

  QueryBuilder<QueueEntryCollection, int?, QQueryOperations>
      retryTimestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retryTimestamp');
    });
  }

  QueryBuilder<QueueEntryCollection, DateTime?, QQueryOperations>
      scheduledForProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scheduledFor');
    });
  }

  QueryBuilder<QueueEntryCollection, int?, QQueryOperations>
      scheduledTimestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scheduledTimestamp');
    });
  }

  QueryBuilder<QueueEntryCollection, EntryStatus, QQueryOperations>
      statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetQueueLockCollectionCollection on Isar {
  IsarCollection<QueueLockCollection> get queueLockCollections =>
      this.collection();
}

const QueueLockCollectionSchema = CollectionSchema(
  name: r'QueueLockCollection',
  id: 3146938371808474993,
  properties: {
    r'acquiredAt': PropertySchema(
      id: 0,
      name: r'acquiredAt',
      type: IsarType.dateTime,
    ),
    r'entryId': PropertySchema(
      id: 1,
      name: r'entryId',
      type: IsarType.string,
    ),
    r'expirationTimestamp': PropertySchema(
      id: 2,
      name: r'expirationTimestamp',
      type: IsarType.long,
    ),
    r'expiresAt': PropertySchema(
      id: 3,
      name: r'expiresAt',
      type: IsarType.dateTime,
    ),
    r'lockId': PropertySchema(
      id: 4,
      name: r'lockId',
      type: IsarType.string,
    ),
    r'lockKey': PropertySchema(
      id: 5,
      name: r'lockKey',
      type: IsarType.string,
    ),
    r'queueName': PropertySchema(
      id: 6,
      name: r'queueName',
      type: IsarType.string,
    )
  },
  estimateSize: _queueLockCollectionEstimateSize,
  serialize: _queueLockCollectionSerialize,
  deserialize: _queueLockCollectionDeserialize,
  deserializeProp: _queueLockCollectionDeserializeProp,
  idName: r'id',
  indexes: {
    r'queueName': IndexSchema(
      id: -6255641391181223237,
      name: r'queueName',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'queueName',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'entryId': IndexSchema(
      id: 3733379884318738402,
      name: r'entryId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'entryId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'lockId': IndexSchema(
      id: -1330138948918674398,
      name: r'lockId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'lockId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'expiresAt': IndexSchema(
      id: 4994901953235663716,
      name: r'expiresAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'expiresAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'lockKey_queueName_entryId': IndexSchema(
      id: 1303747257513875957,
      name: r'lockKey_queueName_entryId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'lockKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'queueName',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'entryId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'lock_expiration_index': IndexSchema(
      id: -4050441628147350588,
      name: r'lock_expiration_index',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'expirationTimestamp',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _queueLockCollectionGetId,
  getLinks: _queueLockCollectionGetLinks,
  attach: _queueLockCollectionAttach,
  version: '3.1.0+1',
);

int _queueLockCollectionEstimateSize(
  QueueLockCollection object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.entryId.length * 3;
  bytesCount += 3 + object.lockId.length * 3;
  bytesCount += 3 + object.lockKey.length * 3;
  bytesCount += 3 + object.queueName.length * 3;
  return bytesCount;
}

void _queueLockCollectionSerialize(
  QueueLockCollection object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.acquiredAt);
  writer.writeString(offsets[1], object.entryId);
  writer.writeLong(offsets[2], object.expirationTimestamp);
  writer.writeDateTime(offsets[3], object.expiresAt);
  writer.writeString(offsets[4], object.lockId);
  writer.writeString(offsets[5], object.lockKey);
  writer.writeString(offsets[6], object.queueName);
}

QueueLockCollection _queueLockCollectionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = QueueLockCollection();
  object.acquiredAt = reader.readDateTime(offsets[0]);
  object.entryId = reader.readString(offsets[1]);
  object.expiresAt = reader.readDateTime(offsets[3]);
  object.id = id;
  object.lockId = reader.readString(offsets[4]);
  object.queueName = reader.readString(offsets[6]);
  return object;
}

P _queueLockCollectionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _queueLockCollectionGetId(QueueLockCollection object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _queueLockCollectionGetLinks(
    QueueLockCollection object) {
  return [];
}

void _queueLockCollectionAttach(
    IsarCollection<dynamic> col, Id id, QueueLockCollection object) {
  object.id = id;
}

extension QueueLockCollectionByIndex on IsarCollection<QueueLockCollection> {
  Future<QueueLockCollection?> getByLockId(String lockId) {
    return getByIndex(r'lockId', [lockId]);
  }

  QueueLockCollection? getByLockIdSync(String lockId) {
    return getByIndexSync(r'lockId', [lockId]);
  }

  Future<bool> deleteByLockId(String lockId) {
    return deleteByIndex(r'lockId', [lockId]);
  }

  bool deleteByLockIdSync(String lockId) {
    return deleteByIndexSync(r'lockId', [lockId]);
  }

  Future<List<QueueLockCollection?>> getAllByLockId(List<String> lockIdValues) {
    final values = lockIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'lockId', values);
  }

  List<QueueLockCollection?> getAllByLockIdSync(List<String> lockIdValues) {
    final values = lockIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'lockId', values);
  }

  Future<int> deleteAllByLockId(List<String> lockIdValues) {
    final values = lockIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'lockId', values);
  }

  int deleteAllByLockIdSync(List<String> lockIdValues) {
    final values = lockIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'lockId', values);
  }

  Future<Id> putByLockId(QueueLockCollection object) {
    return putByIndex(r'lockId', object);
  }

  Id putByLockIdSync(QueueLockCollection object, {bool saveLinks = true}) {
    return putByIndexSync(r'lockId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByLockId(List<QueueLockCollection> objects) {
    return putAllByIndex(r'lockId', objects);
  }

  List<Id> putAllByLockIdSync(List<QueueLockCollection> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'lockId', objects, saveLinks: saveLinks);
  }

  Future<QueueLockCollection?> getByLockKeyQueueNameEntryId(
      String lockKey, String queueName, String entryId) {
    return getByIndex(
        r'lockKey_queueName_entryId', [lockKey, queueName, entryId]);
  }

  QueueLockCollection? getByLockKeyQueueNameEntryIdSync(
      String lockKey, String queueName, String entryId) {
    return getByIndexSync(
        r'lockKey_queueName_entryId', [lockKey, queueName, entryId]);
  }

  Future<bool> deleteByLockKeyQueueNameEntryId(
      String lockKey, String queueName, String entryId) {
    return deleteByIndex(
        r'lockKey_queueName_entryId', [lockKey, queueName, entryId]);
  }

  bool deleteByLockKeyQueueNameEntryIdSync(
      String lockKey, String queueName, String entryId) {
    return deleteByIndexSync(
        r'lockKey_queueName_entryId', [lockKey, queueName, entryId]);
  }

  Future<List<QueueLockCollection?>> getAllByLockKeyQueueNameEntryId(
      List<String> lockKeyValues,
      List<String> queueNameValues,
      List<String> entryIdValues) {
    final len = lockKeyValues.length;
    assert(queueNameValues.length == len && entryIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([lockKeyValues[i], queueNameValues[i], entryIdValues[i]]);
    }

    return getAllByIndex(r'lockKey_queueName_entryId', values);
  }

  List<QueueLockCollection?> getAllByLockKeyQueueNameEntryIdSync(
      List<String> lockKeyValues,
      List<String> queueNameValues,
      List<String> entryIdValues) {
    final len = lockKeyValues.length;
    assert(queueNameValues.length == len && entryIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([lockKeyValues[i], queueNameValues[i], entryIdValues[i]]);
    }

    return getAllByIndexSync(r'lockKey_queueName_entryId', values);
  }

  Future<int> deleteAllByLockKeyQueueNameEntryId(List<String> lockKeyValues,
      List<String> queueNameValues, List<String> entryIdValues) {
    final len = lockKeyValues.length;
    assert(queueNameValues.length == len && entryIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([lockKeyValues[i], queueNameValues[i], entryIdValues[i]]);
    }

    return deleteAllByIndex(r'lockKey_queueName_entryId', values);
  }

  int deleteAllByLockKeyQueueNameEntryIdSync(List<String> lockKeyValues,
      List<String> queueNameValues, List<String> entryIdValues) {
    final len = lockKeyValues.length;
    assert(queueNameValues.length == len && entryIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([lockKeyValues[i], queueNameValues[i], entryIdValues[i]]);
    }

    return deleteAllByIndexSync(r'lockKey_queueName_entryId', values);
  }

  Future<Id> putByLockKeyQueueNameEntryId(QueueLockCollection object) {
    return putByIndex(r'lockKey_queueName_entryId', object);
  }

  Id putByLockKeyQueueNameEntryIdSync(QueueLockCollection object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'lockKey_queueName_entryId', object,
        saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByLockKeyQueueNameEntryId(
      List<QueueLockCollection> objects) {
    return putAllByIndex(r'lockKey_queueName_entryId', objects);
  }

  List<Id> putAllByLockKeyQueueNameEntryIdSync(
      List<QueueLockCollection> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'lockKey_queueName_entryId', objects,
        saveLinks: saveLinks);
  }
}

extension QueueLockCollectionQueryWhereSort
    on QueryBuilder<QueueLockCollection, QueueLockCollection, QWhere> {
  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhere>
      anyExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'expiresAt'),
      );
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhere>
      anyExpirationTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'lock_expiration_index'),
      );
    });
  }
}

extension QueueLockCollectionQueryWhere
    on QueryBuilder<QueueLockCollection, QueueLockCollection, QWhereClause> {
  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      queueNameEqualTo(String queueName) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'queueName',
        value: [queueName],
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      queueNameNotEqualTo(String queueName) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'queueName',
              lower: [],
              upper: [queueName],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'queueName',
              lower: [queueName],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'queueName',
              lower: [queueName],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'queueName',
              lower: [],
              upper: [queueName],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      entryIdEqualTo(String entryId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'entryId',
        value: [entryId],
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      entryIdNotEqualTo(String entryId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entryId',
              lower: [],
              upper: [entryId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entryId',
              lower: [entryId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entryId',
              lower: [entryId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'entryId',
              lower: [],
              upper: [entryId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      lockIdEqualTo(String lockId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'lockId',
        value: [lockId],
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      lockIdNotEqualTo(String lockId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockId',
              lower: [],
              upper: [lockId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockId',
              lower: [lockId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockId',
              lower: [lockId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockId',
              lower: [],
              upper: [lockId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      expiresAtEqualTo(DateTime expiresAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'expiresAt',
        value: [expiresAt],
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      expiresAtNotEqualTo(DateTime expiresAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expiresAt',
              lower: [],
              upper: [expiresAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expiresAt',
              lower: [expiresAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expiresAt',
              lower: [expiresAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expiresAt',
              lower: [],
              upper: [expiresAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      expiresAtGreaterThan(
    DateTime expiresAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'expiresAt',
        lower: [expiresAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      expiresAtLessThan(
    DateTime expiresAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'expiresAt',
        lower: [],
        upper: [expiresAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      expiresAtBetween(
    DateTime lowerExpiresAt,
    DateTime upperExpiresAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'expiresAt',
        lower: [lowerExpiresAt],
        includeLower: includeLower,
        upper: [upperExpiresAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      lockKeyEqualToAnyQueueNameEntryId(String lockKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'lockKey_queueName_entryId',
        value: [lockKey],
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      lockKeyNotEqualToAnyQueueNameEntryId(String lockKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockKey_queueName_entryId',
              lower: [],
              upper: [lockKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockKey_queueName_entryId',
              lower: [lockKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockKey_queueName_entryId',
              lower: [lockKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockKey_queueName_entryId',
              lower: [],
              upper: [lockKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      lockKeyQueueNameEqualToAnyEntryId(String lockKey, String queueName) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'lockKey_queueName_entryId',
        value: [lockKey, queueName],
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      lockKeyEqualToQueueNameNotEqualToAnyEntryId(
          String lockKey, String queueName) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockKey_queueName_entryId',
              lower: [lockKey],
              upper: [lockKey, queueName],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockKey_queueName_entryId',
              lower: [lockKey, queueName],
              includeLower: false,
              upper: [lockKey],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockKey_queueName_entryId',
              lower: [lockKey, queueName],
              includeLower: false,
              upper: [lockKey],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockKey_queueName_entryId',
              lower: [lockKey],
              upper: [lockKey, queueName],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      lockKeyQueueNameEntryIdEqualTo(
          String lockKey, String queueName, String entryId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'lockKey_queueName_entryId',
        value: [lockKey, queueName, entryId],
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      lockKeyQueueNameEqualToEntryIdNotEqualTo(
          String lockKey, String queueName, String entryId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockKey_queueName_entryId',
              lower: [lockKey, queueName],
              upper: [lockKey, queueName, entryId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockKey_queueName_entryId',
              lower: [lockKey, queueName, entryId],
              includeLower: false,
              upper: [lockKey, queueName],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockKey_queueName_entryId',
              lower: [lockKey, queueName, entryId],
              includeLower: false,
              upper: [lockKey, queueName],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lockKey_queueName_entryId',
              lower: [lockKey, queueName],
              upper: [lockKey, queueName, entryId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      expirationTimestampEqualTo(int expirationTimestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'lock_expiration_index',
        value: [expirationTimestamp],
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      expirationTimestampNotEqualTo(int expirationTimestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lock_expiration_index',
              lower: [],
              upper: [expirationTimestamp],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lock_expiration_index',
              lower: [expirationTimestamp],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lock_expiration_index',
              lower: [expirationTimestamp],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lock_expiration_index',
              lower: [],
              upper: [expirationTimestamp],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      expirationTimestampGreaterThan(
    int expirationTimestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'lock_expiration_index',
        lower: [expirationTimestamp],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      expirationTimestampLessThan(
    int expirationTimestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'lock_expiration_index',
        lower: [],
        upper: [expirationTimestamp],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterWhereClause>
      expirationTimestampBetween(
    int lowerExpirationTimestamp,
    int upperExpirationTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'lock_expiration_index',
        lower: [lowerExpirationTimestamp],
        includeLower: includeLower,
        upper: [upperExpirationTimestamp],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension QueueLockCollectionQueryFilter on QueryBuilder<QueueLockCollection,
    QueueLockCollection, QFilterCondition> {
  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      acquiredAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acquiredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      acquiredAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acquiredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      acquiredAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acquiredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      acquiredAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acquiredAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      entryIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      entryIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      entryIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      entryIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'entryId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      entryIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      entryIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      entryIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'entryId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      entryIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'entryId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      entryIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'entryId',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      entryIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'entryId',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      expirationTimestampEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expirationTimestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      expirationTimestampGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expirationTimestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      expirationTimestampLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expirationTimestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      expirationTimestampBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expirationTimestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      expiresAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      expiresAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      expiresAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      expiresAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expiresAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lockId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lockId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lockId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lockId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lockId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lockId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lockId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lockId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lockId',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lockId',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lockKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lockKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lockKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lockKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lockKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lockKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lockKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lockKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lockKey',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      lockKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lockKey',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      queueNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'queueName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      queueNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'queueName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      queueNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'queueName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      queueNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'queueName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      queueNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'queueName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      queueNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'queueName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      queueNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'queueName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      queueNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'queueName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      queueNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'queueName',
        value: '',
      ));
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterFilterCondition>
      queueNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'queueName',
        value: '',
      ));
    });
  }
}

extension QueueLockCollectionQueryObject on QueryBuilder<QueueLockCollection,
    QueueLockCollection, QFilterCondition> {}

extension QueueLockCollectionQueryLinks on QueryBuilder<QueueLockCollection,
    QueueLockCollection, QFilterCondition> {}

extension QueueLockCollectionQuerySortBy
    on QueryBuilder<QueueLockCollection, QueueLockCollection, QSortBy> {
  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByAcquiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acquiredAt', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByAcquiredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acquiredAt', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByExpirationTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expirationTimestamp', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByExpirationTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expirationTimestamp', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByLockId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lockId', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByLockIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lockId', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByLockKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lockKey', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByLockKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lockKey', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByQueueName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'queueName', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      sortByQueueNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'queueName', Sort.desc);
    });
  }
}

extension QueueLockCollectionQuerySortThenBy
    on QueryBuilder<QueueLockCollection, QueueLockCollection, QSortThenBy> {
  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByAcquiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acquiredAt', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByAcquiredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acquiredAt', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByExpirationTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expirationTimestamp', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByExpirationTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expirationTimestamp', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByLockId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lockId', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByLockIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lockId', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByLockKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lockKey', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByLockKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lockKey', Sort.desc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByQueueName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'queueName', Sort.asc);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QAfterSortBy>
      thenByQueueNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'queueName', Sort.desc);
    });
  }
}

extension QueueLockCollectionQueryWhereDistinct
    on QueryBuilder<QueueLockCollection, QueueLockCollection, QDistinct> {
  QueryBuilder<QueueLockCollection, QueueLockCollection, QDistinct>
      distinctByAcquiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acquiredAt');
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QDistinct>
      distinctByEntryId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entryId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QDistinct>
      distinctByExpirationTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expirationTimestamp');
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QDistinct>
      distinctByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expiresAt');
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QDistinct>
      distinctByLockId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lockId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QDistinct>
      distinctByLockKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lockKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QueueLockCollection, QueueLockCollection, QDistinct>
      distinctByQueueName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'queueName', caseSensitive: caseSensitive);
    });
  }
}

extension QueueLockCollectionQueryProperty
    on QueryBuilder<QueueLockCollection, QueueLockCollection, QQueryProperty> {
  QueryBuilder<QueueLockCollection, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<QueueLockCollection, DateTime, QQueryOperations>
      acquiredAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acquiredAt');
    });
  }

  QueryBuilder<QueueLockCollection, String, QQueryOperations>
      entryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entryId');
    });
  }

  QueryBuilder<QueueLockCollection, int, QQueryOperations>
      expirationTimestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expirationTimestamp');
    });
  }

  QueryBuilder<QueueLockCollection, DateTime, QQueryOperations>
      expiresAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expiresAt');
    });
  }

  QueryBuilder<QueueLockCollection, String, QQueryOperations> lockIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lockId');
    });
  }

  QueryBuilder<QueueLockCollection, String, QQueryOperations>
      lockKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lockKey');
    });
  }

  QueryBuilder<QueueLockCollection, String, QQueryOperations>
      queueNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'queueName');
    });
  }
}
