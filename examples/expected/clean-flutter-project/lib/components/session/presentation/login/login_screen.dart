import 'package:clean_flutter_project/components/characters/presentation/favorites/favorites_screen.dart';
import 'package:clean_flutter_project/components/session/presentation/login/managers/login_form_manager.dart';
import 'package:clean_flutter_project/components/session/presentation/login/managers/login_manager.dart';
import 'package:clean_flutter_project/components/session/presentation/login/state_models/login_state.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';

/// DragonflyForm binds its fields to LoginForm by name and validates with LoginFormManager; with a
/// valid form, onSubmit passes the form model to LoginManager (the business logic).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider<LoginManager>(create: (_) => inject<LoginManager>()),
          BlocProvider<LoginFormManager>(create: (_) => inject<LoginFormManager>()),
        ],
        child: _LoginScreenView(),
      );
}

class _LoginScreenView extends StatelessWidget {
  const _LoginScreenView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('session.login.title'.tr())),
      body: LoginStateBuilder<LoginManager>(
        initial: () => Padding(
          padding: EdgeInsets.all(24),
          child: DragonflyForm(
            manager: context.read<LoginFormManager>(),
            onSubmit: (form) => context.read<LoginManager>().login(form),
            child: Column(
              children: [
                FormTextField(
                  'user',
                  label: 'session.login.user'.tr(),
                  autofillHints: [AutofillHints.username],
                ),
                FormTextField(
                  'pass',
                  label: 'session.login.pass'.tr(),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                ),
                SizedBox(height: 24),
                FormSubmit(child: Text('session.login.submit'.tr())),
              ],
            ),
          ),
        ),
        loading: () => Center(child: CircularProgressIndicator()),
        done: (auth) => Center(
          child: FilledButton(
            onPressed: () => context.goTo(FavoritesScreen()),
            child: Text('session.login.hi'.tr({'name': auth.name})),
          ),
        ),
        error: (e) => Center(child: Text(e.message)),
      ),
    );
  }
}
