import 'package:clean_flutter_project/components/characters/presentation/list/managers/characters_manager.dart';
import 'package:clean_flutter_project/components/characters/presentation/list/state_models/characters_state.dart';
import 'package:clean_flutter_project/components/characters/presentation/widgets/character_tile.dart';
import 'package:clean_flutter_project/components/session/domain/models/auth.dart';
import 'package:clean_flutter_project/components/session/presentation/login/login_screen.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';

/// Tab 0 of MainShell. GlobalEvents shows the name of whoever signed in and changes only when the
/// session starts or ends (if the screen is not visible, it changes when coming back to it).
class CharacterListScreen extends StatelessWidget {
  const CharacterListScreen({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider<CharactersManager>(create: (_) => inject<CharactersManager>()),
        ],
        child: _CharacterListScreenView(),
      );
}

class _CharacterListScreenView extends StatelessWidget {
  const _CharacterListScreenView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('characters.list.title'.tr()),
        actions: [
          GlobalEvents<Auth>(
            sessionStarted: (auth) => Padding(padding: EdgeInsets.all(16), child: Text(auth.name)),
            sessionEnded: (e) => TextButton(
              onPressed: () => context.goTo(LoginScreen()),
              child: Text('session.login.title'.tr()),
            ),
          ),
        ],
      ),
      body: CharactersStateBuilder<CharactersManager>(
        loading: () => Center(child: CircularProgressIndicator()),
        full: (characters) => ListView.builder(
          itemCount: characters.length,
          itemBuilder: (context, index) => CharacterTile(character: characters[index]),
        ),
        error: (e) => Center(child: Text(e.message)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.read<CharactersManager>().loadPage(2);
          return Popups.toast(context, 'characters.list.loading'.tr({'page': 2}));
        },
        child: Icon(Icons.refresh),
      ),
    );
  }
}
