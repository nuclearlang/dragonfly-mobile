import 'package:flutter_bloc/flutter_bloc.dart';

/// Base of the classes of the `statemanager` kind: a Cubit whose state is a state model.
abstract class StateManager<S> extends Cubit<S> {
  StateManager(super.initialState);

  /// Emits only while the manager is open (a screen that was closed does not receive late results).
  @override
  void emit(S state) {
    if (!isClosed) super.emit(state);
  }
}
