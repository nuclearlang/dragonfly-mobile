import 'package:dragonfly/dragonfly.dart';
import 'package:dragonfly/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

class Note {
  const Note({this.id, required this.title, this.tag = 'home', this.createdAt, this.updatedAt});

  factory Note.fromJson(Map<String, dynamic> j) => Note(
    id: j['id'] as int?,
    title: j['title'] as String,
    tag: j['tag'] as String,
    createdAt: j['createdAt'] as String?,
    updatedAt: j['updatedAt'] as String?,
  );

  final int? id;
  final String title;
  final String tag;
  final String? createdAt;
  final String? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'tag': tag,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

class NotesConfig extends AppConfig {
  @override
  final List<Connection> connections = [Http(baseUrl: 'https://api.test/')];
}

/// `config PlainNotesConfig` + `local: LocalDatabase = LocalDatabase(encrypted = false)`.
class PlainNotesConfig extends ComponentConfig {
  @override
  final LocalDatabase local = const LocalDatabase(encrypted: false);
}

/// `@repository(path = "notes", saveLocal = true)` as the transpiler writes it.
class NoteRepository extends Repository {
  NoteRepository() : super(path: 'notes');

  Future<Note> one(int id) =>
      send(HttpMethod.get, ':id', params: {'id': id}, local: 'NoteRepository.one', decode: Decode.one(Note.fromJson));

  Future<Note> oneAsLocal(int id) =>
      recall('NoteRepository.one', ':id', params: {'id': id}, decode: Decode.one(Note.fromJson));

  Future<List<Note>> byTag(String tag) =>
      send(HttpMethod.get, '', params: {'tag': tag}, local: 'NoteRepository.byTag', decode: Decode.list(Note.fromJson));

  Future<List<Note>> byTagAsLocal(String tag) =>
      recall('NoteRepository.byTag', '', params: {'tag': tag}, decode: Decode.list(Note.fromJson));

  Future<Either<NotFound, Note>> oneAsLocalResult(int id) =>
      attempt(() => oneAsLocal(id), Right.new, (e) => Left(e as NotFound));

  Future<List<Note>> recent(String tag) =>
      local<Note>().where({'tag': tag}).orderBy('id', desc: true).limit(2).getMany();
}

void main() {
  late LocalTable<Note> notes;

  setUp(() async {
    await DragonflyTest.start(NotesConfig());
    notes = LocalTable<Note>(
      'note',
      Note.fromJson,
      key: 'id',
      generated: true,
      created: 'createdAt',
      updated: 'updatedAt',
    );
    Local.register(notes);
  });

  group('LocalTable', () {
    test('save gives generated keys and stamps, find reads back, remove deletes', () async {
      final a = await notes.save(const Note(title: 'a'));
      final b = await notes.save(const Note(title: 'b'));
      expect(a.id, isNotNull);
      expect(b.id, isNot(a.id));
      expect(a.createdAt, isNotNull);
      expect((await notes.find(a.id!)).getOrElse((_) => throw 'missing').title, 'a');
      expect((await notes.find(99)).isLeft(), isTrue);
      final again = await notes.save(Note(id: a.id, title: 'a2', createdAt: a.createdAt));
      expect(again.createdAt, a.createdAt);
      expect(await notes.count(), 2);
      expect(await notes.remove(a.id!), isTrue);
      expect(await notes.remove(a.id!), isFalse);
      expect((await notes.findAll()).map((n) => n.title), ['a2'].where((t) => t == 'b').toList()..add('b'));
    });

    test('queries: where with operators, orderBy, limit, offset, count, exists, update, delete', () async {
      for (final (title, tag) in [('x1', 'work'), ('x2', 'home'), ('y3', 'work'), ('z4', 'work')]) {
        await notes.save(Note(title: title, tag: tag));
      }
      expect((await notes.where({'tag': 'work'}).orderBy('title', desc: true).getMany()).map((n) => n.title), [
        'z4',
        'y3',
        'x1',
      ]);
      expect((await notes.where({'title': like('x%')}).getMany()).length, 2);
      expect((await notes.where({'title': ilike('Y%')}).getMany()).single.title, 'y3');
      expect((await notes.where({'id': gt(1)}).orderBy('id').limit(1).offset(1).getMany()).single.id, 3);
      expect(
        (await notes.where({
          'tag': oneOf(['home']),
        }).getOne()).getOrElse((_) => throw 'missing').title,
        'x2',
      );
      expect((await notes.where({'tag': 'none'}).getOne()).isLeft(), isTrue);
      expect(await notes.where({'id': between(1, 2)}).count(), 2);
      expect(await notes.where({'tag': ne('work')}).exists(), isTrue);
      expect(await notes.where({'createdAt': null}).exists(), isFalse);
      final page = await notes.where({'tag': 'work'}).orderBy('title').paginate(2, 2);
      expect([page.page, page.size, page.total, page.pages], [2, 2, 3, 2]);
      expect(page.items.map((n) => n.title), ['z4']);
      final read = PageOf.fromJson({...page.toJson((n) => n.toJson())}, (j) => Note.fromJson(j as Map<String, dynamic>));
      expect(read.items.single.title, 'z4');
      expect(await notes.where({'tag': 'work'}).update({'tag': 'done'}), 3);
      expect(await notes.where({'tag': 'done'}).limit(1).count(), 3);
      expect(await notes.where({'tag': 'done'}).delete(), 3);
      expect(await notes.count(), 1);
    });

    test('local of the project config, or of a component config for its tables, says how they are kept', () async {
      expect(Local.settings().encrypted, isTrue);
      await Dragonfly.addConfig(PlainNotesConfig(), component: 'notes');
      expect(Local.settings('notes').encrypted, isFalse);
      expect(Local.settings('other').encrypted, isTrue);
      Local.register(notes, component: 'notes');
      expect(Local.table<Note>().component, 'notes');
    });

    test('a model without a table or without a key is refused with a hint', () async {
      expect(() => Local.table<String>(), throwsA(isA<StateError>()));
      final plain = LocalTable<Note>('plain', Note.fromJson, key: 'id');
      expect(() => plain.save(const Note(title: 'no id')), throwsA(isA<StateError>()));
    });
  });

  group('Repository with saveLocal', () {
    test('send stores the rows and recall answers them without network', () async {
      final repo = NoteRepository();
      DragonflyTest.respond(
        (r) => r.path.endsWith('/notes/7')
            ? (200, {'id': 7, 'title': 'seven', 'tag': 'work'})
            : (
                200,
                [
                  {'id': 7, 'title': 'seven', 'tag': 'work'},
                  {'id': 8, 'title': 'eight', 'tag': 'work'},
                ],
              ),
      );
      await repo.one(7);
      await repo.byTag('work');
      expect(DragonflyTest.requests.length, 2);
      expect((await repo.oneAsLocal(7)).title, 'seven');
      expect((await repo.byTagAsLocal('work')).map((n) => n.id), [7, 8]);
      // a row changed locally is what the call answers now
      await notes.save(const Note(id: 8, title: 'eight!', tag: 'work'));
      expect((await repo.byTagAsLocal('work')).last.title, 'eight!');
      expect((await repo.recent('work')).map((n) => n.id), [8, 7]);
      expect(DragonflyTest.requests.length, 2);
      // a call that never happened, or whose row is gone
      expect(() => repo.oneAsLocal(9), throwsA(isA<NotFound>()));
      expect((await repo.oneAsLocalResult(9)).isLeft(), isTrue);
      await notes.remove(7);
      expect((await repo.byTagAsLocal('work')).map((n) => n.id), [8]);
    });

    test('a value of a model without a table is a clear error', () async {
      // a fresh start: the setUp's table is gone
      await DragonflyTest.start(NotesConfig());
      DragonflyTest.respondWith({'id': 1, 'title': 't', 'tag': 'home'});
      expect(NoteRepository().one(1), throwsA(isA<StateError>()));
    });
  });
}
