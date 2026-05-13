import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  LocalConversations,
  LocalMessages,
  LocalContacts,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Conversations
  Future<List<LocalConversation>> getAllConversations() {
    return (select(localConversations)
          ..orderBy([
            (t) => OrderingTerm.desc(t.pinned),
            (t) => OrderingTerm.desc(t.lastMsgTime),
          ]))
        .get();
  }

  Stream<List<LocalConversation>> watchConversations() {
    return (select(localConversations)
          ..orderBy([
            (t) => OrderingTerm.desc(t.pinned),
            (t) => OrderingTerm.desc(t.lastMsgTime),
          ]))
        .watch();
  }

  Future<void> upsertConversation(LocalConversationsCompanion entry) {
    return into(localConversations).insertOnConflictUpdate(entry);
  }

  Future<void> deleteConversation(int id) {
    return (delete(localConversations)..where((t) => t.id.equals(id))).go();
  }

  // Messages
  Stream<List<LocalMessage>> watchMessages(int conversationId) {
    return (select(localMessages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.seq)])
          ..limit(100))
        .watch();
  }

  Future<List<LocalMessage>> getMessages(int conversationId, {int limit = 50, int offset = 0}) {
    return (select(localMessages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.desc(t.seq)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<void> upsertMessage(LocalMessagesCompanion entry) {
    return into(localMessages).insertOnConflictUpdate(entry);
  }

  Future<void> insertMessage(LocalMessagesCompanion entry) {
    return into(localMessages).insert(entry);
  }

  // Contacts
  Future<List<LocalContact>> getAllContacts() {
    return (select(localContacts)..orderBy([(t) => OrderingTerm.asc(t.alias)])).get();
  }

  Stream<List<LocalContact>> watchContacts() {
    return (select(localContacts)..orderBy([(t) => OrderingTerm.asc(t.alias)])).watch();
  }

  Future<void> upsertContact(LocalContactsCompanion entry) {
    return into(localContacts).insertOnConflictUpdate(entry);
  }

  Future<void> deleteContact(int friendId) {
    return (delete(localContacts)..where((t) => t.friendId.equals(friendId))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dataDir = Directory('${Directory.current.path}/.mychat_data/inst_$pid');
    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }
    final file = File('${dataDir.path}/mychat.db');

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    return NativeDatabase.createInBackground(file);
  });
}

// Tables

class LocalConversations extends Table {
  IntColumn get id => integer()();
  IntColumn get type => integer()(); // 1=single 2=group
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get avatarUrl => text().withDefault(const Constant(''))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get muted => boolean().withDefault(const Constant(false))();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get lastMsgTime => integer().withDefault(const Constant(0))();
  TextColumn get lastMsgPreview => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalMessages extends Table {
  IntColumn get id => integer()();
  IntColumn get conversationId => integer()();
  IntColumn get senderId => integer()();
  IntColumn get seq => integer()();
  IntColumn get contentType => integer()(); // 1=text 2=image 3=voice 4=file
  TextColumn get content => text()();
  IntColumn get replyToId => integer().nullable()();
  BoolColumn get recalled => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalContacts extends Table {
  IntColumn get id => integer()();
  IntColumn get friendId => integer()();
  TextColumn get alias => text().withDefault(const Constant(''))();
  TextColumn get nickname => text().withDefault(const Constant(''))();
  TextColumn get avatarUrl => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
