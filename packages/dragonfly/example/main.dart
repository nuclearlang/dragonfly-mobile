// A small app with the main pieces of dragonfly: a connection, a repository, a state manager and the
// network banner. NuclearLang apps get this code written by the transpiler.
import 'package:dragonfly/dragonfly.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Character {
  const Character(this.name, this.status);

  factory Character.fromJson(Map<String, dynamic> json) =>
      Character(json['name'] as String, json['status'] as String);

  final String name;
  final String status;
}

class CharacterRepository extends Repository {
  CharacterRepository() : super(path: 'character');

  Future<List<Character>> getPage(int page) => send(
        HttpMethod.get,
        '',
        params: {'page': page},
        cache: const Cache(),
        cacheName: 'CharacterRepository.getPage',
        decode: (json) => Decode.list(Character.fromJson)((json as Map<String, dynamic>)['results']),
      );
}

class CharactersManager extends StateManager<List<Character>?> {
  CharactersManager() : super(null) {
    load();
  }

  Future<void> load() async => emit(await inject<CharacterRepository>().getPage(1));
}

class ExampleConfig extends AppConfig {
  @override
  final List<Connection> connections = [Http(baseUrl: 'https://rickandmortyapi.com/api/')];

  @override
  final List<Global> globals = [Events(), NetworkManager()];
}

Future<void> main() async {
  await Dragonfly.start(ExampleConfig());
  Dragonfly.di.registerLazySingleton(CharacterRepository.new);
  runApp(
    MaterialApp(
      builder: (context, child) => NetworkWrapper(child: child!),
      home: BlocProvider(create: (_) => CharactersManager(), child: const CharactersScreen()),
    ),
  );
}

class CharactersScreen extends StatelessWidget {
  const CharactersScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Characters')),
        body: BlocBuilder<CharactersManager, List<Character>?>(
          builder: (context, characters) => characters == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(children: [for (final c in characters) ListTile(title: Text(c.name), subtitle: Text(c.status))]),
        ),
      );
}
