import 'package:clean_flutter_project/components/characters/domain/models/character.dart';
import 'package:clean_flutter_project/components/characters/domain/models/character_error.dart';
import 'package:flutter/foundation.dart' hide Page;
import 'package:flutter/widgets.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';

/// State model: each field is a state of the screen.
enum CharactersStateStatus { initial, full, error, loading }

class CharactersState {
  const CharactersState._({required this.status, this.full, this.error});

  const CharactersState.initial() : this._(status: CharactersStateStatus.initial);
  const CharactersState.full(List<Character> full) : this._(status: CharactersStateStatus.full, full: full);
  const CharactersState.error(CharacterError error) : this._(status: CharactersStateStatus.error, error: error);
  const CharactersState.loading() : this._(status: CharactersStateStatus.loading);

  final CharactersStateStatus status;
  final List<Character>? full;
  final CharacterError? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharactersState &&
          status == other.status &&
          listEquals(full, other.full) &&
          error == other.error;

  @override
  int get hashCode => Object.hash(status, Object.hashAll([Object.hashAll(full ?? const []), error, ]));

  @override
  String toString() => 'CharactersState.${status.name}';
}

/// One widget for each state of [CharactersState]; a state without a builder shows [orElse].
class CharactersStateBuilder<M extends StateStreamable<CharactersState>> extends StatelessWidget {
  const CharactersStateBuilder({super.key, this.initial, this.full, this.error, this.loading, this.orElse});

  final Widget Function()? initial;
  final Widget Function(List<Character> full)? full;
  final Widget Function(CharacterError error)? error;
  final Widget Function()? loading;
  final Widget Function()? orElse;

  @override
  Widget build(BuildContext context) => BlocBuilder<M, CharactersState>(
        builder: (context, state) =>
            switch (state.status) {
              CharactersStateStatus.initial => initial?.call(),
              CharactersStateStatus.full => full?.call(state.full!),
              CharactersStateStatus.error => error?.call(state.error!),
              CharactersStateStatus.loading => loading?.call(),
            } ??
            orElse?.call() ??
            const SizedBox.shrink(),
      );
}
