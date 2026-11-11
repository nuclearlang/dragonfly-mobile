import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bundled assets in memory, with the manifest Flutter writes.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final f in files.keys)
          f: [
            {'asset': f},
          ],
      })!;
    }
    final text = files[key];
    if (text == null) throw FlutterError('no asset $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

class _Store implements DictionaryStore {
  final Map<String, String> files = {};

  @override
  Future<String?> read(String path) async => files[path];

  @override
  Future<void> write(String path, String text) async => files[path] = text;

  @override
  Future<void> prune(String keep) async => files.removeWhere((k, _) => k.contains('/') && !k.startsWith('$keep/'));
}

/// A server that answers each path with a text.
class _Server implements HttpClientAdapter {
  _Server(this.routes);

  final Map<String, String> routes;
  final List<String> asked = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    asked.add(o.uri.path);
    final text = routes[o.uri.path];
    return ResponseBody.fromString(text ?? 'not found', text == null ? 404 : 200);
  }

  @override
  void close({bool force = false}) {}
}

class SignUp {
  const SignUp(this.email, this.pass, this.age);

  final String email;
  final String pass;
  final int age;
}

class SignUpManager extends FormManager<SignUp> {
  SignUpManager()
    : super(
        {
          'email': [Rules.required(), Rules.email()],
          'pass': [Rules.required(), Rules.minLength(6)],
          'repeat': [Rules.matches('pass')],
          'age': [Rules.number(), Rules.min(18)],
        },
        const {'email': '', 'pass': '', 'repeat': '', 'age': ''},
        (v) => SignUp(v['email'] as String, v['pass'] as String, Rules.asInt(v['age'])!),
      );

  final List<String> checks = [];

  @override
  Duration get debounce => Duration.zero;

  @override
  FieldCheck? checkOf(String field) => switch (field) {
    'email' => (v) => emailFree(v as String),
    _ => null,
  };

  Future<String?> emailFree(String value) async {
    checks.add(value);
    return value == 'taken@a.co' ? 'Email taken' : null;
  }
}

void main() {
  group('translations', () {
    final bundle = _Bundle({
      'assets/i18n/es/shop.json': jsonEncode({
        'home': {'title': 'Tienda', 'items': '{n} productos'},
      }),
      'assets/i18n/en/shop.json': jsonEncode({
        'home': {'title': 'Shop', 'only': 'English only'},
      }),
    });

    test('one dictionary per component, the fallback, Dragonfly texts and the key', () async {
      final t = Translations(locales: ['es', 'en'], fallback: 'en', bundle: bundle, store: _Store());
      addTearDown(t.dispose);
      await t.init();
      await Translations.use('es');
      expect('shop.home.title'.tr(), 'Tienda');
      expect('shop.home.items'.tr({'n': 3}), '3 productos');
      expect('shop.home.only'.tr(), 'English only');
      expect('dragonfly.dialog.accept'.tr(), 'Aceptar');
      expect('shop.nothing'.tr(), 'shop.nothing');
      await Translations.use('en');
      expect('shop.home.title'.tr(), 'Shop');
      expect(Translations.locale, const Locale('en'));
      expect(() => Translations.use('fr'), throwsArgumentError);
    });

    test('the saved locale wins over the device one', () async {
      final store = _Store()..files['locale'] = 'es';
      final t = Translations(locales: ['en', 'es'], bundle: bundle, store: store);
      addTearDown(t.dispose);
      await t.init();
      expect('shop.home.title'.tr(), 'Tienda');
    });

    test('remote dictionaries: each version in its folder, used over the bundled ones', () async {
      final server = _Server({
        '/i18n/manifest.json': jsonEncode({
          'version': '2',
          'locales': {
            'es': ['shop'],
            'fr': ['shop'],
          },
        }),
        '/i18n/2/es/shop.json': jsonEncode({
          'home': {'title': 'Tienda 2'},
        }),
      });
      final store = _Store()
        ..files['locale'] = 'es'
        ..files['1/es/shop.json'] = '{}';
      final remote = RemoteDictionaries(url: 'https://x.dev/i18n', client: Dio()..httpClientAdapter = server);
      final t = Translations(locales: ['es', 'en'], bundle: bundle, store: store, remote: remote);
      addTearDown(t.dispose);
      await t.init();
      expect(await Translations.refresh(), isTrue, reason: 'waits for the download init started');
      expect(await Translations.refresh(), isFalse, reason: 'version 2 is already here');
      expect('shop.home.title'.tr(), 'Tienda 2');
      expect('shop.home.items'.tr({'n': 1}), '1 productos', reason: 'what the remote lacks stays bundled');
      expect(store.files['current'], '2');
      expect(store.files.containsKey('1/es/shop.json'), isFalse, reason: 'old versions are removed');
      expect(server.asked, isNot(contains('/i18n/2/fr/shop.json')), reason: 'only the app locales');
    });

    test('a server that sends unsafe names changes nothing', () async {
      final server = _Server({
        '/i18n/manifest.json': jsonEncode({
          'version': '../../x',
          'locales': {
            'es': ['shop'],
          },
        }),
      });
      final store = _Store();
      final remote = RemoteDictionaries(url: 'https://x.dev/i18n', client: Dio()..httpClientAdapter = server);
      final t = Translations(locales: ['es'], bundle: bundle, store: store, remote: remote);
      addTearDown(t.dispose);
      await t.init();
      expect(await Translations.refresh(), isFalse);
      expect(store.files, isEmpty);
    });
  });

  group('forms', () {
    test('rules, errors after touching or submitting, remote checks', () async {
      final m = SignUpManager();
      expect(m.state.errors.keys, containsAll(['email', 'pass']));
      expect(m.state.errorOf('email'), isNull, reason: 'untouched fields show no error');
      m.change('email', 'nope');
      m.touch('email');
      expect(m.state.errorOf('email'), 'Invalid email');
      m.change('email', 'taken@a.co');
      expect(m.state.checking, {'email'});
      await pumpEventQueue();
      expect(m.state.errorOf('email'), 'Email taken');
      m.change('pass', '123456');
      m.change('repeat', '12345');
      m.change('age', 'x');
      SignUp? sent;
      expect(await m.submit((f) => sent = f), isFalse);
      expect(m.state.errorOf('repeat'), 'Does not match');
      expect(m.state.errorOf('age'), 'Must be a number');
      m.change('email', 'ana@a.co');
      m.change('repeat', '123456');
      m.change('age', '17');
      expect(await m.submit((f) => sent = f), isFalse);
      expect(m.state.errorOf('age'), 'Must be at least 18');
      m.change('age', '20');
      expect(await m.submit((f) => sent = f), isTrue);
      expect([sent!.email, sent!.age], ['ana@a.co', 20]);
      expect(m.checks, ['taken@a.co', 'ana@a.co']);
      expect(m.state.status, FormStatus.submitted);
      m.reset();
      expect([m.state.values['email'], m.state.attempted], ['', false]);
      await m.close();
    });

    test('Validators for a plain TextFormField', () {
      final v = Validators.all([Validators.required(), Validators.email()]);
      expect(v(''), 'Required');
      expect(v('nope'), 'Invalid email');
      expect(v('a@b.co'), isNull);
      expect(Validators.minLength(3)('ab'), 'At least 3 characters');
    });

    testWidgets('the fields bind to the form model by name', (tester) async {
      final m = SignUpManager();
      SignUp? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DragonflyForm(
              manager: m,
              onSubmit: (form) => sent = form,
              child: const Column(
                children: [
                  FormTextField('email', label: 'Email'),
                  FormTextField('pass', label: 'Password', obscureText: true),
                  FormTextField('repeat'),
                  FormTextField('age', keyboardType: TextInputType.number),
                  FormSubmit(child: Text('Send')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsNWidgets(2));
      expect(sent, isNull);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'ana@a.co');
      await tester.enterText(fields.at(1), 'secret1');
      await tester.enterText(fields.at(2), 'secret1');
      await tester.enterText(fields.at(3), '30');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsNothing);
      expect(sent?.age, 30);
      m.reset();
      await tester.pump();
      expect(find.text('ana@a.co'), findsNothing, reason: 'reset empties the text fields');
      await m.close();
    });
  });

  group('dialogs', () {
    Future<BuildContext> app(WidgetTester tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return ctx;
    }

    testWidgets('a message: icon of its type and a close button, no footer', (tester) async {
      final ctx = await app(tester);
      var closed = 0;
      DragonflyDialog(onClose: () => closed++, child: const Text('Hello')).show(ctx);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.text('Close'), findsNothing);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
      expect(closed, 1);
    });

    testWidgets('onAccept adds the footer with Close and Accept', (tester) async {
      final ctx = await app(tester);
      var accepted = false;
      final result = DragonflyDialog.danger(
        size: DragonflyDialog.small,
        header: const Text('Delete'),
        onAccept: () => accepted = true,
        child: const Text('Sure?'),
      ).show(ctx);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect([accepted, await result], [true, true]);
    });

    testWidgets('autoClose, toast and snackbar go away by themselves', (tester) async {
      final ctx = await app(tester);
      DragonflyDialog.success(autoClose: const Duration(seconds: 2), child: const Text('Saved')).show(ctx);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      Popups.toast(ctx, 'Copied', type: PopupType.warning);
      await tester.pump();
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Copied'), findsNothing);
      Popups.snackbar(ctx, 'Offline', type: PopupType.danger);
      await tester.pump();
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('confirm returns whether the user accepted', (tester) async {
      final ctx = await app(tester);
      final r = Popups.confirm(ctx, 'Leave', 'Unsaved changes');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(await r, isFalse);
    });
  });
}
