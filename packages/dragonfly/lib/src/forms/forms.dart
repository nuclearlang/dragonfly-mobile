import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../i18n/translations.dart';

/// A check of one field: the error message, or null when [value] is valid. [values] has every field
/// of the form (for rules that compare fields).
typedef Rule = String? Function(Object? value, Map<String, Object?> values);

/// A remote check of one field: the error message, or null when [value] is valid.
typedef FieldCheck = FutureOr<String?> Function(Object? value);

/// The rules of form models, like zod or class-validator. Every message is a translation key
/// (`dragonfly.form.<rule>`) or the text given in `message`. An empty optional field passes every rule
/// except [required].
abstract final class Rules {
  static bool isEmpty(Object? v) => v == null || (v is String && v.trim().isEmpty) || (v is Iterable && v.isEmpty);

  static String _msg(String? message, String rule, [Map<String, Object?>? args]) =>
      (message ?? 'dragonfly.form.$rule').tr(args);

  /// Not empty; a boolean must be true (accept the terms).
  static Rule required({String? message}) =>
      (v, _) => isEmpty(v) || v == false ? _msg(message, 'required') : null;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static Rule email({String? message}) =>
      (v, _) => isEmpty(v) || _email.hasMatch('$v') ? null : _msg(message, 'email');

  static Rule url({String? message}) => (v, _) {
    if (isEmpty(v)) return null;
    final u = Uri.tryParse('$v');
    return u != null && u.hasScheme && u.host.isNotEmpty ? null : _msg(message, 'url');
  };

  /// A number (int and double fields have it without writing it).
  static Rule number({String? message}) =>
      (v, _) => isEmpty(v) || asDouble(v) != null ? null : _msg(message, 'number');

  static Rule minLength(int n, {String? message}) =>
      (v, _) => isEmpty(v) || '$v'.length >= n ? null : _msg(message, 'minLength', {'n': n});

  static Rule maxLength(int n, {String? message}) =>
      (v, _) => isEmpty(v) || '$v'.length <= n ? null : _msg(message, 'maxLength', {'n': n});

  static Rule min(num n, {String? message}) =>
      (v, _) => isEmpty(v) || (asDouble(v) ?? n) >= n ? null : _msg(message, 'min', {'n': n});

  static Rule max(num n, {String? message}) =>
      (v, _) => isEmpty(v) || (asDouble(v) ?? n) <= n ? null : _msg(message, 'max', {'n': n});

  static Rule pattern(String regex, {String? message}) {
    final re = RegExp(regex);
    return (v, _) => isEmpty(v) || re.hasMatch('$v') ? null : _msg(message, 'pattern');
  }

  /// Equal to the field [other] (repeat the password).
  static Rule matches(String other, {String? message}) =>
      (v, values) => v == values[other] || (isEmpty(v) && isEmpty(values[other])) ? null : _msg(message, 'matches');

  /// The value of a number field: an int, or the text of a text field.
  static int? asInt(Object? v) => v is int
      ? v
      : v is num
      ? v.toInt()
      : int.tryParse('${v ?? ''}'.trim());

  static double? asDouble(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.trim());
}

/// Validators for a plain `TextFormField(validator: ...)`, with the same messages as [Rules].
abstract final class Validators {
  static String? Function(String?) _of(Rule r) =>
      (v) => r(v, const {});

  static String? Function(String?) required([String? message]) => _of(Rules.required(message: message));

  static String? Function(String?) email([String? message]) => _of(Rules.email(message: message));

  static String? Function(String?) minLength(int n, [String? message]) => _of(Rules.minLength(n, message: message));

  static String? Function(String?) maxLength(int n, [String? message]) => _of(Rules.maxLength(n, message: message));

  static String? Function(String?) pattern(String regex, [String? message]) =>
      _of(Rules.pattern(regex, message: message));

  /// The first message of [validators].
  static String? Function(String?) all(List<String? Function(String?)> validators) => (v) {
    for (final f in validators) {
      final m = f(v);
      if (m != null) return m;
    }
    return null;
  };
}

enum FormStatus { editing, submitting, submitted, failed }

/// The state of a form: the value and the error of each field.
@immutable
class FormValues {
  const FormValues({
    this.values = const {},
    this.errors = const {},
    this.touched = const {},
    this.checking = const {},
    this.attempted = false,
    this.status = FormStatus.editing,
  });

  final Map<String, Object?> values;

  /// Every field that is invalid now (shown with [errorOf]).
  final Map<String, String> errors;

  /// The fields the user left at least once.
  final Set<String> touched;

  /// The fields whose remote check is running.
  final Set<String> checking;

  /// Submit was pressed at least once: from then on every error shows.
  final bool attempted;
  final FormStatus status;

  /// The error [field] shows: once the user left it or pressed submit.
  String? errorOf(String field) => attempted || touched.contains(field) ? errors[field] : null;

  bool get valid => errors.isEmpty && checking.isEmpty;

  FormValues copyWith({
    Map<String, Object?>? values,
    Map<String, String>? errors,
    Set<String>? touched,
    Set<String>? checking,
    bool? attempted,
    FormStatus? status,
  }) => FormValues(
    values: values ?? this.values,
    errors: errors ?? this.errors,
    touched: touched ?? this.touched,
    checking: checking ?? this.checking,
    attempted: attempted ?? this.attempted,
    status: status ?? this.status,
  );
}

/// The state of one form: validates each field against the rules of its form model on every change,
/// and runs the remote checks ([checkOf], the `@validate` methods of the `formmanager` kind) after the
/// rules pass, [debounce] after the last keystroke. It knows nothing of the business: [submit] gives
/// the valid form model to whoever handles it (a statemanager).
abstract class FormManager<F> extends Cubit<FormValues> {
  FormManager(this.rules, this.initial, this._build)
    : super(FormValues(values: initial, errors: _sync(rules, initial)));

  /// The rules of each field, in the order they are checked; every field of the form model is a key.
  final Map<String, List<Rule>> rules;
  final Map<String, Object?> initial;
  final F Function(Map<String, Object?> values) _build;

  final Map<String, Timer> _timers = {};
  final Map<String, Future<void>> _running = {};
  final Map<String, String> _remote = {};

  Duration get debounce => const Duration(milliseconds: 400);

  /// The remote check of [field] (the `@validate` method of the `formmanager` kind, an API call through
  /// the component), or null when the field has none. It returns the error message (a translation key
  /// or the text) or null.
  FieldCheck? checkOf(String field) => null;

  /// The form model with the current values (valid only after [submit] accepted them).
  F get form => _build(state.values);

  static Map<String, String> _sync(Map<String, List<Rule>> rules, Map<String, Object?> values) {
    final errors = <String, String>{};
    for (final MapEntry(key: field, value: list) in rules.entries) {
      for (final rule in list) {
        final m = rule(values[field], values);
        if (m != null) {
          errors[field] = m;
          break;
        }
      }
    }
    return errors;
  }

  /// The errors of the rules, and of the remote checks for the fields whose rules pass.
  Map<String, String> _errors(Map<String, Object?> values) => {..._remote, ..._sync(rules, values)};

  /// The user changed [field].
  void change(String field, Object? value) {
    assert(rules.containsKey(field), '$runtimeType has no field "$field" (it has ${rules.keys.join(', ')})');
    final values = {...state.values, field: value};
    _remote.remove(field);
    _timers.remove(field)?.cancel();
    final errors = _errors(values);
    final remote = checkOf(field) != null && !errors.containsKey(field) && !Rules.isEmpty(value);
    final checking = {...state.checking}..remove(field);
    if (remote) {
      checking.add(field);
      _timers[field] = Timer(debounce, () => _run(field, value));
    }
    emit(state.copyWith(values: values, errors: errors, checking: checking, status: FormStatus.editing));
  }

  /// The user left [field]: its error shows from now on.
  void touch(String field) {
    if (!state.touched.contains(field)) emit(state.copyWith(touched: {...state.touched, field}));
  }

  Future<void> _run(String field, Object? value) {
    _timers.remove(field);
    return _running[field] =
        () async {
          final message = await checkOf(field)!(value);
          if (isClosed || state.values[field] != value) return; // the user typed again: this answer is old
          if (message != null) _remote[field] = message.tr();
          emit(state.copyWith(errors: _errors(state.values), checking: {...state.checking}..remove(field)));
        }().whenComplete(() {
          _running.remove(field); // not `=>`: whenComplete would wait for the removed future, itself
        });
  }

  /// Validates every field (the remote checks too, without waiting for the debounce) and, when all
  /// pass, gives the form model to [onValid]. True when [onValid] ran without errors.
  Future<bool> submit(FutureOr<void> Function(F form) onValid) async {
    if (state.status == FormStatus.submitting) return false;
    emit(state.copyWith(attempted: true));
    for (final f in _timers.keys.toList()) {
      _timers.remove(f)!.cancel();
      unawaited(_run(f, state.values[f]));
    }
    await Future.wait(_running.values.toList());
    if (isClosed || !state.valid) return false;
    emit(state.copyWith(status: FormStatus.submitting));
    try {
      await onValid(form);
      if (!isClosed) emit(state.copyWith(status: FormStatus.submitted));
      return true;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(status: FormStatus.failed));
      rethrow;
    }
  }

  /// Back to the initial values, without errors shown.
  void reset() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _remote.clear();
    emit(FormValues(values: initial, errors: _sync(rules, initial)));
  }

  @override
  Future<void> close() {
    for (final t in _timers.values) {
      t.cancel();
    }
    return super.close();
  }
}

/// A form bound to its manager: the fields inside ([FormTextField], [FormCheckbox], [FormInput]) are
/// found by the name of the form model's field, and [FormSubmit] validates and calls [onSubmit] with
/// the valid form model.
class DragonflyForm<F> extends StatelessWidget {
  const DragonflyForm({super.key, required this.manager, required this.child, this.onSubmit});

  final FormManager<F> manager;
  final FutureOr<void> Function(F form)? onSubmit;
  final Widget child;

  /// Validates and, when valid, calls [onSubmit].
  Future<bool> submit() => manager.submit(onSubmit ?? (_) {});

  /// The nearest form.
  static DragonflyForm<Object?> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_FormScope>();
    assert(scope != null, 'a form field must be inside a DragonflyForm');
    return scope!.form;
  }

  @override
  Widget build(BuildContext context) => _FormScope(form: this, child: child);
}

class _FormScope extends InheritedWidget {
  const _FormScope({required this.form, required super.child});

  final DragonflyForm<Object?> form;

  @override
  bool updateShouldNotify(_FormScope old) => !identical(old.form.manager, form.manager);
}

/// Rebuilds only when what [field] shows changes (its value, its error, its remote check).
bool _fieldChanged(String field, FormValues a, FormValues b) =>
    a.values[field] != b.values[field] ||
    a.errorOf(field) != b.errorOf(field) ||
    a.checking.contains(field) != b.checking.contains(field);

/// The text field of the form model's field [name]. Number fields keep the text and the form model
/// receives the number.
class FormTextField extends StatefulWidget {
  const FormTextField(
    this.name, {
    super.key,
    this.label,
    this.hint,
    this.decoration,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String name;
  final String? label;
  final String? hint;
  final InputDecoration? decoration;
  final bool obscureText;
  final TextInputType? keyboardType;

  /// [TextInputAction.done] submits the form.
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final int? maxLines;
  final bool enabled;

  @override
  State<FormTextField> createState() => _FormTextFieldState();
}

class _FormTextFieldState extends State<FormTextField> {
  late final TextEditingController _text;
  final FocusNode _focus = FocusNode();
  late DragonflyForm<Object?> _form;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _form = DragonflyForm.of(context);
    if (!_started) {
      _started = true;
      _text = TextEditingController(text: '${_form.manager.state.values[widget.name] ?? ''}');
      _focus.addListener(() => _focus.hasFocus ? null : _form.manager.touch(widget.name));
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    return BlocConsumer<FormManager<Object?>, FormValues>(
      bloc: _form.manager,
      listenWhen: (a, b) => a.values[name] != b.values[name] && '${b.values[name] ?? ''}' != _text.text,
      listener: (_, s) => _text.text = '${s.values[name] ?? ''}', // reset() or a value set by code
      buildWhen: (a, b) => _fieldChanged(name, a, b),
      builder: (context, s) {
        final checking = s.checking.contains(name);
        final base = widget.decoration ?? const InputDecoration();
        return TextField(
          controller: _text,
          focusNode: _focus,
          enabled: widget.enabled,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          onChanged: (t) => _form.manager.change(name, t),
          onSubmitted: widget.textInputAction == TextInputAction.done ? (_) => _form.submit() : null,
          decoration: base.copyWith(
            labelText: widget.label ?? base.labelText,
            hintText: widget.hint ?? base.hintText,
            errorText: s.errorOf(name),
            suffixIcon: checking
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : base.suffixIcon,
          ),
        );
      },
    );
  }
}

/// A checkbox for the boolean field [name] (with `@required`: it must be checked).
class FormCheckbox extends StatelessWidget {
  const FormCheckbox(this.name, {super.key, required this.label});

  final String name;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    final manager = DragonflyForm.of(context).manager;
    return BlocBuilder<FormManager<Object?>, FormValues>(
      bloc: manager,
      buildWhen: (a, b) => _fieldChanged(name, a, b),
      builder: (context, s) {
        final error = s.errorOf(name);
        return CheckboxListTile(
          value: s.values[name] == true,
          title: label,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          subtitle: error == null ? null : Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          onChanged: (v) {
            manager.change(name, v ?? false);
            manager.touch(name);
          },
        );
      },
    );
  }
}

/// Any widget for the field [name] (a dropdown, a date picker...): [builder] receives the value, the
/// error to show and the function that changes the value.
class FormInput<T> extends StatelessWidget {
  const FormInput(this.name, {super.key, required this.builder});

  final String name;
  final Widget Function(BuildContext context, T? value, String? error, void Function(T? value) change) builder;

  @override
  Widget build(BuildContext context) {
    final manager = DragonflyForm.of(context).manager;
    return BlocBuilder<FormManager<Object?>, FormValues>(
      bloc: manager,
      buildWhen: (a, b) => _fieldChanged(name, a, b),
      builder: (context, s) => builder(context, s.values[name] as T?, s.errorOf(name), (v) {
        manager.change(name, v);
        manager.touch(name);
      }),
    );
  }
}

/// The submit button: validates the form, calls `onSubmit` of the [DragonflyForm] when it is valid
/// and shows a spinner meanwhile.
class FormSubmit extends StatelessWidget {
  const FormSubmit({super.key, required this.child, this.style});

  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final form = DragonflyForm.of(context);
    return BlocBuilder<FormManager<Object?>, FormValues>(
      bloc: form.manager,
      buildWhen: (a, b) => (a.status == FormStatus.submitting) != (b.status == FormStatus.submitting),
      builder: (context, s) => FilledButton(
        style: style,
        onPressed: s.status == FormStatus.submitting ? null : form.submit,
        child: s.status == FormStatus.submitting
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : child,
      ),
    );
  }
}
