// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalConversationsTable extends LocalConversations
    with TableInfo<$LocalConversationsTable, LocalConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
      'type', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _avatarUrlMeta =
      const VerificationMeta('avatarUrl');
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
      'avatar_url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
      'pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _mutedMeta = const VerificationMeta('muted');
  @override
  late final GeneratedColumn<bool> muted = GeneratedColumn<bool>(
      'muted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("muted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _unreadCountMeta =
      const VerificationMeta('unreadCount');
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
      'unread_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastMsgTimeMeta =
      const VerificationMeta('lastMsgTime');
  @override
  late final GeneratedColumn<int> lastMsgTime = GeneratedColumn<int>(
      'last_msg_time', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastMsgPreviewMeta =
      const VerificationMeta('lastMsgPreview');
  @override
  late final GeneratedColumn<String> lastMsgPreview = GeneratedColumn<String>(
      'last_msg_preview', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        type,
        name,
        avatarUrl,
        pinned,
        muted,
        unreadCount,
        lastMsgTime,
        lastMsgPreview
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_conversations';
  @override
  VerificationContext validateIntegrity(Insertable<LocalConversation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('avatar_url')) {
      context.handle(_avatarUrlMeta,
          avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta));
    }
    if (data.containsKey('pinned')) {
      context.handle(_pinnedMeta,
          pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta));
    }
    if (data.containsKey('muted')) {
      context.handle(
          _mutedMeta, muted.isAcceptableOrUnknown(data['muted']!, _mutedMeta));
    }
    if (data.containsKey('unread_count')) {
      context.handle(
          _unreadCountMeta,
          unreadCount.isAcceptableOrUnknown(
              data['unread_count']!, _unreadCountMeta));
    }
    if (data.containsKey('last_msg_time')) {
      context.handle(
          _lastMsgTimeMeta,
          lastMsgTime.isAcceptableOrUnknown(
              data['last_msg_time']!, _lastMsgTimeMeta));
    }
    if (data.containsKey('last_msg_preview')) {
      context.handle(
          _lastMsgPreviewMeta,
          lastMsgPreview.isAcceptableOrUnknown(
              data['last_msg_preview']!, _lastMsgPreviewMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalConversation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      avatarUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_url'])!,
      pinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pinned'])!,
      muted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}muted'])!,
      unreadCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unread_count'])!,
      lastMsgTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_msg_time'])!,
      lastMsgPreview: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}last_msg_preview'])!,
    );
  }

  @override
  $LocalConversationsTable createAlias(String alias) {
    return $LocalConversationsTable(attachedDatabase, alias);
  }
}

class LocalConversation extends DataClass
    implements Insertable<LocalConversation> {
  final int id;
  final int type;
  final String name;
  final String avatarUrl;
  final bool pinned;
  final bool muted;
  final int unreadCount;
  final int lastMsgTime;
  final String lastMsgPreview;
  const LocalConversation(
      {required this.id,
      required this.type,
      required this.name,
      required this.avatarUrl,
      required this.pinned,
      required this.muted,
      required this.unreadCount,
      required this.lastMsgTime,
      required this.lastMsgPreview});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<int>(type);
    map['name'] = Variable<String>(name);
    map['avatar_url'] = Variable<String>(avatarUrl);
    map['pinned'] = Variable<bool>(pinned);
    map['muted'] = Variable<bool>(muted);
    map['unread_count'] = Variable<int>(unreadCount);
    map['last_msg_time'] = Variable<int>(lastMsgTime);
    map['last_msg_preview'] = Variable<String>(lastMsgPreview);
    return map;
  }

  LocalConversationsCompanion toCompanion(bool nullToAbsent) {
    return LocalConversationsCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      avatarUrl: Value(avatarUrl),
      pinned: Value(pinned),
      muted: Value(muted),
      unreadCount: Value(unreadCount),
      lastMsgTime: Value(lastMsgTime),
      lastMsgPreview: Value(lastMsgPreview),
    );
  }

  factory LocalConversation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalConversation(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<int>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      avatarUrl: serializer.fromJson<String>(json['avatarUrl']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      muted: serializer.fromJson<bool>(json['muted']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      lastMsgTime: serializer.fromJson<int>(json['lastMsgTime']),
      lastMsgPreview: serializer.fromJson<String>(json['lastMsgPreview']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<int>(type),
      'name': serializer.toJson<String>(name),
      'avatarUrl': serializer.toJson<String>(avatarUrl),
      'pinned': serializer.toJson<bool>(pinned),
      'muted': serializer.toJson<bool>(muted),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'lastMsgTime': serializer.toJson<int>(lastMsgTime),
      'lastMsgPreview': serializer.toJson<String>(lastMsgPreview),
    };
  }

  LocalConversation copyWith(
          {int? id,
          int? type,
          String? name,
          String? avatarUrl,
          bool? pinned,
          bool? muted,
          int? unreadCount,
          int? lastMsgTime,
          String? lastMsgPreview}) =>
      LocalConversation(
        id: id ?? this.id,
        type: type ?? this.type,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        pinned: pinned ?? this.pinned,
        muted: muted ?? this.muted,
        unreadCount: unreadCount ?? this.unreadCount,
        lastMsgTime: lastMsgTime ?? this.lastMsgTime,
        lastMsgPreview: lastMsgPreview ?? this.lastMsgPreview,
      );
  LocalConversation copyWithCompanion(LocalConversationsCompanion data) {
    return LocalConversation(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      muted: data.muted.present ? data.muted.value : this.muted,
      unreadCount:
          data.unreadCount.present ? data.unreadCount.value : this.unreadCount,
      lastMsgTime:
          data.lastMsgTime.present ? data.lastMsgTime.value : this.lastMsgTime,
      lastMsgPreview: data.lastMsgPreview.present
          ? data.lastMsgPreview.value
          : this.lastMsgPreview,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversation(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('pinned: $pinned, ')
          ..write('muted: $muted, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('lastMsgTime: $lastMsgTime, ')
          ..write('lastMsgPreview: $lastMsgPreview')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, name, avatarUrl, pinned, muted,
      unreadCount, lastMsgTime, lastMsgPreview);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalConversation &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.avatarUrl == this.avatarUrl &&
          other.pinned == this.pinned &&
          other.muted == this.muted &&
          other.unreadCount == this.unreadCount &&
          other.lastMsgTime == this.lastMsgTime &&
          other.lastMsgPreview == this.lastMsgPreview);
}

class LocalConversationsCompanion extends UpdateCompanion<LocalConversation> {
  final Value<int> id;
  final Value<int> type;
  final Value<String> name;
  final Value<String> avatarUrl;
  final Value<bool> pinned;
  final Value<bool> muted;
  final Value<int> unreadCount;
  final Value<int> lastMsgTime;
  final Value<String> lastMsgPreview;
  const LocalConversationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.pinned = const Value.absent(),
    this.muted = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.lastMsgTime = const Value.absent(),
    this.lastMsgPreview = const Value.absent(),
  });
  LocalConversationsCompanion.insert({
    this.id = const Value.absent(),
    required int type,
    this.name = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.pinned = const Value.absent(),
    this.muted = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.lastMsgTime = const Value.absent(),
    this.lastMsgPreview = const Value.absent(),
  }) : type = Value(type);
  static Insertable<LocalConversation> custom({
    Expression<int>? id,
    Expression<int>? type,
    Expression<String>? name,
    Expression<String>? avatarUrl,
    Expression<bool>? pinned,
    Expression<bool>? muted,
    Expression<int>? unreadCount,
    Expression<int>? lastMsgTime,
    Expression<String>? lastMsgPreview,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (pinned != null) 'pinned': pinned,
      if (muted != null) 'muted': muted,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (lastMsgTime != null) 'last_msg_time': lastMsgTime,
      if (lastMsgPreview != null) 'last_msg_preview': lastMsgPreview,
    });
  }

  LocalConversationsCompanion copyWith(
      {Value<int>? id,
      Value<int>? type,
      Value<String>? name,
      Value<String>? avatarUrl,
      Value<bool>? pinned,
      Value<bool>? muted,
      Value<int>? unreadCount,
      Value<int>? lastMsgTime,
      Value<String>? lastMsgPreview}) {
    return LocalConversationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      pinned: pinned ?? this.pinned,
      muted: muted ?? this.muted,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMsgTime: lastMsgTime ?? this.lastMsgTime,
      lastMsgPreview: lastMsgPreview ?? this.lastMsgPreview,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (muted.present) {
      map['muted'] = Variable<bool>(muted.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (lastMsgTime.present) {
      map['last_msg_time'] = Variable<int>(lastMsgTime.value);
    }
    if (lastMsgPreview.present) {
      map['last_msg_preview'] = Variable<String>(lastMsgPreview.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('pinned: $pinned, ')
          ..write('muted: $muted, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('lastMsgTime: $lastMsgTime, ')
          ..write('lastMsgPreview: $lastMsgPreview')
          ..write(')'))
        .toString();
  }
}

class $LocalMessagesTable extends LocalMessages
    with TableInfo<$LocalMessagesTable, LocalMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<int> conversationId = GeneratedColumn<int>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<int> senderId = GeneratedColumn<int>(
      'sender_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
      'seq', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _contentTypeMeta =
      const VerificationMeta('contentType');
  @override
  late final GeneratedColumn<int> contentType = GeneratedColumn<int>(
      'content_type', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _replyToIdMeta =
      const VerificationMeta('replyToId');
  @override
  late final GeneratedColumn<int> replyToId = GeneratedColumn<int>(
      'reply_to_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _recalledMeta =
      const VerificationMeta('recalled');
  @override
  late final GeneratedColumn<bool> recalled = GeneratedColumn<bool>(
      'recalled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("recalled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        conversationId,
        senderId,
        seq,
        contentType,
        content,
        replyToId,
        recalled,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_messages';
  @override
  VerificationContext validateIntegrity(Insertable<LocalMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
          _seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('content_type')) {
      context.handle(
          _contentTypeMeta,
          contentType.isAcceptableOrUnknown(
              data['content_type']!, _contentTypeMeta));
    } else if (isInserting) {
      context.missing(_contentTypeMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
          _replyToIdMeta,
          replyToId.isAcceptableOrUnknown(
              data['reply_to_id']!, _replyToIdMeta));
    }
    if (data.containsKey('recalled')) {
      context.handle(_recalledMeta,
          recalled.isAcceptableOrUnknown(data['recalled']!, _recalledMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}conversation_id'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sender_id'])!,
      seq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      contentType: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}content_type'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      replyToId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reply_to_id']),
      recalled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}recalled'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalMessagesTable createAlias(String alias) {
    return $LocalMessagesTable(attachedDatabase, alias);
  }
}

class LocalMessage extends DataClass implements Insertable<LocalMessage> {
  final int id;
  final int conversationId;
  final int senderId;
  final int seq;
  final int contentType;
  final String content;
  final int? replyToId;
  final bool recalled;
  final int createdAt;
  const LocalMessage(
      {required this.id,
      required this.conversationId,
      required this.senderId,
      required this.seq,
      required this.contentType,
      required this.content,
      this.replyToId,
      required this.recalled,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['conversation_id'] = Variable<int>(conversationId);
    map['sender_id'] = Variable<int>(senderId);
    map['seq'] = Variable<int>(seq);
    map['content_type'] = Variable<int>(contentType);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<int>(replyToId);
    }
    map['recalled'] = Variable<bool>(recalled);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  LocalMessagesCompanion toCompanion(bool nullToAbsent) {
    return LocalMessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderId: Value(senderId),
      seq: Value(seq),
      contentType: Value(contentType),
      content: Value(content),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      recalled: Value(recalled),
      createdAt: Value(createdAt),
    );
  }

  factory LocalMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMessage(
      id: serializer.fromJson<int>(json['id']),
      conversationId: serializer.fromJson<int>(json['conversationId']),
      senderId: serializer.fromJson<int>(json['senderId']),
      seq: serializer.fromJson<int>(json['seq']),
      contentType: serializer.fromJson<int>(json['contentType']),
      content: serializer.fromJson<String>(json['content']),
      replyToId: serializer.fromJson<int?>(json['replyToId']),
      recalled: serializer.fromJson<bool>(json['recalled']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationId': serializer.toJson<int>(conversationId),
      'senderId': serializer.toJson<int>(senderId),
      'seq': serializer.toJson<int>(seq),
      'contentType': serializer.toJson<int>(contentType),
      'content': serializer.toJson<String>(content),
      'replyToId': serializer.toJson<int?>(replyToId),
      'recalled': serializer.toJson<bool>(recalled),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  LocalMessage copyWith(
          {int? id,
          int? conversationId,
          int? senderId,
          int? seq,
          int? contentType,
          String? content,
          Value<int?> replyToId = const Value.absent(),
          bool? recalled,
          int? createdAt}) =>
      LocalMessage(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        senderId: senderId ?? this.senderId,
        seq: seq ?? this.seq,
        contentType: contentType ?? this.contentType,
        content: content ?? this.content,
        replyToId: replyToId.present ? replyToId.value : this.replyToId,
        recalled: recalled ?? this.recalled,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalMessage copyWithCompanion(LocalMessagesCompanion data) {
    return LocalMessage(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      seq: data.seq.present ? data.seq.value : this.seq,
      contentType:
          data.contentType.present ? data.contentType.value : this.contentType,
      content: data.content.present ? data.content.value : this.content,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      recalled: data.recalled.present ? data.recalled.value : this.recalled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessage(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('seq: $seq, ')
          ..write('contentType: $contentType, ')
          ..write('content: $content, ')
          ..write('replyToId: $replyToId, ')
          ..write('recalled: $recalled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, conversationId, senderId, seq,
      contentType, content, replyToId, recalled, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMessage &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderId == this.senderId &&
          other.seq == this.seq &&
          other.contentType == this.contentType &&
          other.content == this.content &&
          other.replyToId == this.replyToId &&
          other.recalled == this.recalled &&
          other.createdAt == this.createdAt);
}

class LocalMessagesCompanion extends UpdateCompanion<LocalMessage> {
  final Value<int> id;
  final Value<int> conversationId;
  final Value<int> senderId;
  final Value<int> seq;
  final Value<int> contentType;
  final Value<String> content;
  final Value<int?> replyToId;
  final Value<bool> recalled;
  final Value<int> createdAt;
  const LocalMessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.seq = const Value.absent(),
    this.contentType = const Value.absent(),
    this.content = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.recalled = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LocalMessagesCompanion.insert({
    this.id = const Value.absent(),
    required int conversationId,
    required int senderId,
    required int seq,
    required int contentType,
    required String content,
    this.replyToId = const Value.absent(),
    this.recalled = const Value.absent(),
    required int createdAt,
  })  : conversationId = Value(conversationId),
        senderId = Value(senderId),
        seq = Value(seq),
        contentType = Value(contentType),
        content = Value(content),
        createdAt = Value(createdAt);
  static Insertable<LocalMessage> custom({
    Expression<int>? id,
    Expression<int>? conversationId,
    Expression<int>? senderId,
    Expression<int>? seq,
    Expression<int>? contentType,
    Expression<String>? content,
    Expression<int>? replyToId,
    Expression<bool>? recalled,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (seq != null) 'seq': seq,
      if (contentType != null) 'content_type': contentType,
      if (content != null) 'content': content,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (recalled != null) 'recalled': recalled,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LocalMessagesCompanion copyWith(
      {Value<int>? id,
      Value<int>? conversationId,
      Value<int>? senderId,
      Value<int>? seq,
      Value<int>? contentType,
      Value<String>? content,
      Value<int?>? replyToId,
      Value<bool>? recalled,
      Value<int>? createdAt}) {
    return LocalMessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      seq: seq ?? this.seq,
      contentType: contentType ?? this.contentType,
      content: content ?? this.content,
      replyToId: replyToId ?? this.replyToId,
      recalled: recalled ?? this.recalled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<int>(conversationId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<int>(senderId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<int>(contentType.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<int>(replyToId.value);
    }
    if (recalled.present) {
      map['recalled'] = Variable<bool>(recalled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('seq: $seq, ')
          ..write('contentType: $contentType, ')
          ..write('content: $content, ')
          ..write('replyToId: $replyToId, ')
          ..write('recalled: $recalled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LocalContactsTable extends LocalContacts
    with TableInfo<$LocalContactsTable, LocalContact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _friendIdMeta =
      const VerificationMeta('friendId');
  @override
  late final GeneratedColumn<int> friendId = GeneratedColumn<int>(
      'friend_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
      'alias', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _nicknameMeta =
      const VerificationMeta('nickname');
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
      'nickname', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _avatarUrlMeta =
      const VerificationMeta('avatarUrl');
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
      'avatar_url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns =>
      [id, friendId, alias, nickname, avatarUrl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_contacts';
  @override
  VerificationContext validateIntegrity(Insertable<LocalContact> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('friend_id')) {
      context.handle(_friendIdMeta,
          friendId.isAcceptableOrUnknown(data['friend_id']!, _friendIdMeta));
    } else if (isInserting) {
      context.missing(_friendIdMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
          _aliasMeta, alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta));
    }
    if (data.containsKey('nickname')) {
      context.handle(_nicknameMeta,
          nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta));
    }
    if (data.containsKey('avatar_url')) {
      context.handle(_avatarUrlMeta,
          avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalContact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalContact(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      friendId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}friend_id'])!,
      alias: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}alias'])!,
      nickname: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nickname'])!,
      avatarUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_url'])!,
    );
  }

  @override
  $LocalContactsTable createAlias(String alias) {
    return $LocalContactsTable(attachedDatabase, alias);
  }
}

class LocalContact extends DataClass implements Insertable<LocalContact> {
  final int id;
  final int friendId;
  final String alias;
  final String nickname;
  final String avatarUrl;
  const LocalContact(
      {required this.id,
      required this.friendId,
      required this.alias,
      required this.nickname,
      required this.avatarUrl});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['friend_id'] = Variable<int>(friendId);
    map['alias'] = Variable<String>(alias);
    map['nickname'] = Variable<String>(nickname);
    map['avatar_url'] = Variable<String>(avatarUrl);
    return map;
  }

  LocalContactsCompanion toCompanion(bool nullToAbsent) {
    return LocalContactsCompanion(
      id: Value(id),
      friendId: Value(friendId),
      alias: Value(alias),
      nickname: Value(nickname),
      avatarUrl: Value(avatarUrl),
    );
  }

  factory LocalContact.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalContact(
      id: serializer.fromJson<int>(json['id']),
      friendId: serializer.fromJson<int>(json['friendId']),
      alias: serializer.fromJson<String>(json['alias']),
      nickname: serializer.fromJson<String>(json['nickname']),
      avatarUrl: serializer.fromJson<String>(json['avatarUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'friendId': serializer.toJson<int>(friendId),
      'alias': serializer.toJson<String>(alias),
      'nickname': serializer.toJson<String>(nickname),
      'avatarUrl': serializer.toJson<String>(avatarUrl),
    };
  }

  LocalContact copyWith(
          {int? id,
          int? friendId,
          String? alias,
          String? nickname,
          String? avatarUrl}) =>
      LocalContact(
        id: id ?? this.id,
        friendId: friendId ?? this.friendId,
        alias: alias ?? this.alias,
        nickname: nickname ?? this.nickname,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
  LocalContact copyWithCompanion(LocalContactsCompanion data) {
    return LocalContact(
      id: data.id.present ? data.id.value : this.id,
      friendId: data.friendId.present ? data.friendId.value : this.friendId,
      alias: data.alias.present ? data.alias.value : this.alias,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalContact(')
          ..write('id: $id, ')
          ..write('friendId: $friendId, ')
          ..write('alias: $alias, ')
          ..write('nickname: $nickname, ')
          ..write('avatarUrl: $avatarUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, friendId, alias, nickname, avatarUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalContact &&
          other.id == this.id &&
          other.friendId == this.friendId &&
          other.alias == this.alias &&
          other.nickname == this.nickname &&
          other.avatarUrl == this.avatarUrl);
}

class LocalContactsCompanion extends UpdateCompanion<LocalContact> {
  final Value<int> id;
  final Value<int> friendId;
  final Value<String> alias;
  final Value<String> nickname;
  final Value<String> avatarUrl;
  const LocalContactsCompanion({
    this.id = const Value.absent(),
    this.friendId = const Value.absent(),
    this.alias = const Value.absent(),
    this.nickname = const Value.absent(),
    this.avatarUrl = const Value.absent(),
  });
  LocalContactsCompanion.insert({
    this.id = const Value.absent(),
    required int friendId,
    this.alias = const Value.absent(),
    this.nickname = const Value.absent(),
    this.avatarUrl = const Value.absent(),
  }) : friendId = Value(friendId);
  static Insertable<LocalContact> custom({
    Expression<int>? id,
    Expression<int>? friendId,
    Expression<String>? alias,
    Expression<String>? nickname,
    Expression<String>? avatarUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (friendId != null) 'friend_id': friendId,
      if (alias != null) 'alias': alias,
      if (nickname != null) 'nickname': nickname,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
  }

  LocalContactsCompanion copyWith(
      {Value<int>? id,
      Value<int>? friendId,
      Value<String>? alias,
      Value<String>? nickname,
      Value<String>? avatarUrl}) {
    return LocalContactsCompanion(
      id: id ?? this.id,
      friendId: friendId ?? this.friendId,
      alias: alias ?? this.alias,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (friendId.present) {
      map['friend_id'] = Variable<int>(friendId.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalContactsCompanion(')
          ..write('id: $id, ')
          ..write('friendId: $friendId, ')
          ..write('alias: $alias, ')
          ..write('nickname: $nickname, ')
          ..write('avatarUrl: $avatarUrl')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalConversationsTable localConversations =
      $LocalConversationsTable(this);
  late final $LocalMessagesTable localMessages = $LocalMessagesTable(this);
  late final $LocalContactsTable localContacts = $LocalContactsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [localConversations, localMessages, localContacts];
}

typedef $$LocalConversationsTableCreateCompanionBuilder
    = LocalConversationsCompanion Function({
  Value<int> id,
  required int type,
  Value<String> name,
  Value<String> avatarUrl,
  Value<bool> pinned,
  Value<bool> muted,
  Value<int> unreadCount,
  Value<int> lastMsgTime,
  Value<String> lastMsgPreview,
});
typedef $$LocalConversationsTableUpdateCompanionBuilder
    = LocalConversationsCompanion Function({
  Value<int> id,
  Value<int> type,
  Value<String> name,
  Value<String> avatarUrl,
  Value<bool> pinned,
  Value<bool> muted,
  Value<int> unreadCount,
  Value<int> lastMsgTime,
  Value<String> lastMsgPreview,
});

class $$LocalConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get pinned => $composableBuilder(
      column: $table.pinned, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get muted => $composableBuilder(
      column: $table.muted, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastMsgTime => $composableBuilder(
      column: $table.lastMsgTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMsgPreview => $composableBuilder(
      column: $table.lastMsgPreview,
      builder: (column) => ColumnFilters(column));
}

class $$LocalConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get pinned => $composableBuilder(
      column: $table.pinned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get muted => $composableBuilder(
      column: $table.muted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastMsgTime => $composableBuilder(
      column: $table.lastMsgTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMsgPreview => $composableBuilder(
      column: $table.lastMsgPreview,
      builder: (column) => ColumnOrderings(column));
}

class $$LocalConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<bool> get muted =>
      $composableBuilder(column: $table.muted, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => column);

  GeneratedColumn<int> get lastMsgTime => $composableBuilder(
      column: $table.lastMsgTime, builder: (column) => column);

  GeneratedColumn<String> get lastMsgPreview => $composableBuilder(
      column: $table.lastMsgPreview, builder: (column) => column);
}

class $$LocalConversationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalConversationsTable,
    LocalConversation,
    $$LocalConversationsTableFilterComposer,
    $$LocalConversationsTableOrderingComposer,
    $$LocalConversationsTableAnnotationComposer,
    $$LocalConversationsTableCreateCompanionBuilder,
    $$LocalConversationsTableUpdateCompanionBuilder,
    (
      LocalConversation,
      BaseReferences<_$AppDatabase, $LocalConversationsTable, LocalConversation>
    ),
    LocalConversation,
    PrefetchHooks Function()> {
  $$LocalConversationsTableTableManager(
      _$AppDatabase db, $LocalConversationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalConversationsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> type = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> avatarUrl = const Value.absent(),
            Value<bool> pinned = const Value.absent(),
            Value<bool> muted = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<int> lastMsgTime = const Value.absent(),
            Value<String> lastMsgPreview = const Value.absent(),
          }) =>
              LocalConversationsCompanion(
            id: id,
            type: type,
            name: name,
            avatarUrl: avatarUrl,
            pinned: pinned,
            muted: muted,
            unreadCount: unreadCount,
            lastMsgTime: lastMsgTime,
            lastMsgPreview: lastMsgPreview,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int type,
            Value<String> name = const Value.absent(),
            Value<String> avatarUrl = const Value.absent(),
            Value<bool> pinned = const Value.absent(),
            Value<bool> muted = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<int> lastMsgTime = const Value.absent(),
            Value<String> lastMsgPreview = const Value.absent(),
          }) =>
              LocalConversationsCompanion.insert(
            id: id,
            type: type,
            name: name,
            avatarUrl: avatarUrl,
            pinned: pinned,
            muted: muted,
            unreadCount: unreadCount,
            lastMsgTime: lastMsgTime,
            lastMsgPreview: lastMsgPreview,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalConversationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalConversationsTable,
    LocalConversation,
    $$LocalConversationsTableFilterComposer,
    $$LocalConversationsTableOrderingComposer,
    $$LocalConversationsTableAnnotationComposer,
    $$LocalConversationsTableCreateCompanionBuilder,
    $$LocalConversationsTableUpdateCompanionBuilder,
    (
      LocalConversation,
      BaseReferences<_$AppDatabase, $LocalConversationsTable, LocalConversation>
    ),
    LocalConversation,
    PrefetchHooks Function()>;
typedef $$LocalMessagesTableCreateCompanionBuilder = LocalMessagesCompanion
    Function({
  Value<int> id,
  required int conversationId,
  required int senderId,
  required int seq,
  required int contentType,
  required String content,
  Value<int?> replyToId,
  Value<bool> recalled,
  required int createdAt,
});
typedef $$LocalMessagesTableUpdateCompanionBuilder = LocalMessagesCompanion
    Function({
  Value<int> id,
  Value<int> conversationId,
  Value<int> senderId,
  Value<int> seq,
  Value<int> contentType,
  Value<String> content,
  Value<int?> replyToId,
  Value<bool> recalled,
  Value<int> createdAt,
});

class $$LocalMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get replyToId => $composableBuilder(
      column: $table.replyToId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get recalled => $composableBuilder(
      column: $table.recalled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get replyToId => $composableBuilder(
      column: $table.replyToId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get recalled => $composableBuilder(
      column: $table.recalled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<int> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<bool> get recalled =>
      $composableBuilder(column: $table.recalled, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalMessagesTable,
    LocalMessage,
    $$LocalMessagesTableFilterComposer,
    $$LocalMessagesTableOrderingComposer,
    $$LocalMessagesTableAnnotationComposer,
    $$LocalMessagesTableCreateCompanionBuilder,
    $$LocalMessagesTableUpdateCompanionBuilder,
    (
      LocalMessage,
      BaseReferences<_$AppDatabase, $LocalMessagesTable, LocalMessage>
    ),
    LocalMessage,
    PrefetchHooks Function()> {
  $$LocalMessagesTableTableManager(_$AppDatabase db, $LocalMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> conversationId = const Value.absent(),
            Value<int> senderId = const Value.absent(),
            Value<int> seq = const Value.absent(),
            Value<int> contentType = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<int?> replyToId = const Value.absent(),
            Value<bool> recalled = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
          }) =>
              LocalMessagesCompanion(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            seq: seq,
            contentType: contentType,
            content: content,
            replyToId: replyToId,
            recalled: recalled,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int conversationId,
            required int senderId,
            required int seq,
            required int contentType,
            required String content,
            Value<int?> replyToId = const Value.absent(),
            Value<bool> recalled = const Value.absent(),
            required int createdAt,
          }) =>
              LocalMessagesCompanion.insert(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            seq: seq,
            contentType: contentType,
            content: content,
            replyToId: replyToId,
            recalled: recalled,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalMessagesTable,
    LocalMessage,
    $$LocalMessagesTableFilterComposer,
    $$LocalMessagesTableOrderingComposer,
    $$LocalMessagesTableAnnotationComposer,
    $$LocalMessagesTableCreateCompanionBuilder,
    $$LocalMessagesTableUpdateCompanionBuilder,
    (
      LocalMessage,
      BaseReferences<_$AppDatabase, $LocalMessagesTable, LocalMessage>
    ),
    LocalMessage,
    PrefetchHooks Function()>;
typedef $$LocalContactsTableCreateCompanionBuilder = LocalContactsCompanion
    Function({
  Value<int> id,
  required int friendId,
  Value<String> alias,
  Value<String> nickname,
  Value<String> avatarUrl,
});
typedef $$LocalContactsTableUpdateCompanionBuilder = LocalContactsCompanion
    Function({
  Value<int> id,
  Value<int> friendId,
  Value<String> alias,
  Value<String> nickname,
  Value<String> avatarUrl,
});

class $$LocalContactsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalContactsTable> {
  $$LocalContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get friendId => $composableBuilder(
      column: $table.friendId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nickname => $composableBuilder(
      column: $table.nickname, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnFilters(column));
}

class $$LocalContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalContactsTable> {
  $$LocalContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get friendId => $composableBuilder(
      column: $table.friendId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nickname => $composableBuilder(
      column: $table.nickname, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnOrderings(column));
}

class $$LocalContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalContactsTable> {
  $$LocalContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get friendId =>
      $composableBuilder(column: $table.friendId, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);
}

class $$LocalContactsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalContactsTable,
    LocalContact,
    $$LocalContactsTableFilterComposer,
    $$LocalContactsTableOrderingComposer,
    $$LocalContactsTableAnnotationComposer,
    $$LocalContactsTableCreateCompanionBuilder,
    $$LocalContactsTableUpdateCompanionBuilder,
    (
      LocalContact,
      BaseReferences<_$AppDatabase, $LocalContactsTable, LocalContact>
    ),
    LocalContact,
    PrefetchHooks Function()> {
  $$LocalContactsTableTableManager(_$AppDatabase db, $LocalContactsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> friendId = const Value.absent(),
            Value<String> alias = const Value.absent(),
            Value<String> nickname = const Value.absent(),
            Value<String> avatarUrl = const Value.absent(),
          }) =>
              LocalContactsCompanion(
            id: id,
            friendId: friendId,
            alias: alias,
            nickname: nickname,
            avatarUrl: avatarUrl,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int friendId,
            Value<String> alias = const Value.absent(),
            Value<String> nickname = const Value.absent(),
            Value<String> avatarUrl = const Value.absent(),
          }) =>
              LocalContactsCompanion.insert(
            id: id,
            friendId: friendId,
            alias: alias,
            nickname: nickname,
            avatarUrl: avatarUrl,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalContactsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalContactsTable,
    LocalContact,
    $$LocalContactsTableFilterComposer,
    $$LocalContactsTableOrderingComposer,
    $$LocalContactsTableAnnotationComposer,
    $$LocalContactsTableCreateCompanionBuilder,
    $$LocalContactsTableUpdateCompanionBuilder,
    (
      LocalContact,
      BaseReferences<_$AppDatabase, $LocalContactsTable, LocalContact>
    ),
    LocalContact,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalConversationsTableTableManager get localConversations =>
      $$LocalConversationsTableTableManager(_db, _db.localConversations);
  $$LocalMessagesTableTableManager get localMessages =>
      $$LocalMessagesTableTableManager(_db, _db.localMessages);
  $$LocalContactsTableTableManager get localContacts =>
      $$LocalContactsTableTableManager(_db, _db.localContacts);
}
