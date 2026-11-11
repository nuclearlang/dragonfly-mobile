import 'package:bloc_test/bloc_test.dart';
import 'package:clean_flutter_project/components/characters/characters_component.dart';
import 'package:clean_flutter_project/components/characters/data/character_repository.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_error.dart';
import 'package:clean_flutter_project/components/characters/domain/usecases/get_page_usecase.dart';
import 'package:clean_flutter_project/components/characters/presentation/list/character_list_screen.dart';
import 'package:clean_flutter_project/components/characters/presentation/list/managers/characters_manager.dart';
import 'package:clean_flutter_project/components/characters/presentation/list/state_models/characters_state.dart';
import 'package:clean_flutter_project/dragonfly.g.dart';
import 'package:clean_flutter_project/shared/models/page.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:dragonfly/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

/// Tests of the characters component: the repository is a mock (mocktail); everything else is the real code.
Character character(String name, String status) {
  return Character(
    id: 1,
    name: name,
    status: status,
    species: 'Human',
    type: '',
    gender: 'Male',
    origin: Origin(name: 'Earth', url: ''),
    location: Location(name: 'Earth', url: ''),
    image: '',
    episode: [],
    url: '',
    created: '',
  );
}

Page<Character> page() {
  return Page(
    info: PageInfo(count: 2, pages: 1),
    results: [character('Rick', 'Alive'), character('Birdperson', 'Dead')],
  );
}

class MockCharacterRepository extends Mock implements CharacterRepository {}

void main() {
  group('CharactersTest', () {
    setUp(() async {
      await DragonflyTest.start(dragonflyConfig(), registerDragonfly);
      DragonflyTest.replace<CharacterRepository>(MockCharacterRepository());
    });

    setUp(() async {
      when(() => inject<CharacterRepository>().getPage(1)).thenReturnAsync(Right(page()));
    });

    test('GetPageUseCase keeps only the alive characters', () async {
      final result = await inject<GetPageUseCase>().exec(1);
      expect(result, isOkWith([character('Rick', 'Alive')]));
    });

    test('a failed request is an error of the component', () async {
      when(() => inject<CharacterRepository>().getPage(2)).thenReturnAsync(Left(CharacterError(message: 'down')));
      expect(
        await inject<CharactersComponent>().getPage(2),
        isErrWith(CharacterError(message: 'down')),
      );
    });

    blocTest(
      'the manager loads the alive characters',
      build: () => inject<CharactersManager>(),
      act: (manager) async {
        manager.loadPage(1);
      },
      expect: () => [CharactersState.full([character('Rick', 'Alive')])],
    );

    testWidgets('the list shows the alive characters', (tester) async {
      await tester.pumpScreen(CharacterListScreen());
      expect(find.text('Rick'), findsOneWidget);
      expect(find.text('Birdperson'), findsNothing);
    });
  });
}
