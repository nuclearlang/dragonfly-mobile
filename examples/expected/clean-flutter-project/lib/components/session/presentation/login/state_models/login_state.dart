import 'package:clean_flutter_project/components/session/domain/models/auth.dart';
import 'package:flutter/widgets.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';

enum LoginStateStatus { initial, done, error, loading }

class LoginState {
  const LoginState._({required this.status, this.done, this.error});

  const LoginState.initial() : this._(status: LoginStateStatus.initial);
  const LoginState.done(Auth done) : this._(status: LoginStateStatus.done, done: done);
  const LoginState.error(AuthError error) : this._(status: LoginStateStatus.error, error: error);
  const LoginState.loading() : this._(status: LoginStateStatus.loading);

  final LoginStateStatus status;
  final Auth? done;
  final AuthError? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginState &&
          status == other.status &&
          done == other.done &&
          error == other.error;

  @override
  int get hashCode => Object.hash(status, Object.hashAll([done, error, ]));

  @override
  String toString() => 'LoginState.${status.name}';
}

/// One widget for each state of [LoginState]; a state without a builder shows [orElse].
class LoginStateBuilder<M extends StateStreamable<LoginState>> extends StatelessWidget {
  const LoginStateBuilder({super.key, this.initial, this.done, this.error, this.loading, this.orElse});

  final Widget Function()? initial;
  final Widget Function(Auth done)? done;
  final Widget Function(AuthError error)? error;
  final Widget Function()? loading;
  final Widget Function()? orElse;

  @override
  Widget build(BuildContext context) => BlocBuilder<M, LoginState>(
        builder: (context, state) =>
            switch (state.status) {
              LoginStateStatus.initial => initial?.call(),
              LoginStateStatus.done => done?.call(state.done!),
              LoginStateStatus.error => error?.call(state.error!),
              LoginStateStatus.loading => loading?.call(),
            } ??
            orElse?.call() ??
            const SizedBox.shrink(),
      );
}
