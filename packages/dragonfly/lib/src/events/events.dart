import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../core.dart';
import '../log/log.dart';

/// Base of the global events (`event` kind). An event is a typed message: whoever publishes it does not
/// know who listens.
abstract class AppEvent {
  const AppEvent();

  /// The name and [toJson] of the event travel instead of the object when it is published from another
  /// Flutter engine (a workmanager task), where only JSON can be sent. The `event` kind writes both;
  /// an event without a name only travels from isolates of the same engine.
  String? get eventName => null;

  Map<String, dynamic> toJson() => const {};
}

/// The backend asked for a newer version of the app.
class ForceUpdate extends AppEvent {
  const ForceUpdate({this.minVersion = ''});

  final String minVersion;
}

/// A session started (`SessionManager.start`); [data] is what was stored with it.
class SessionStarted<T> extends AppEvent {
  const SessionStarted(this.data);

  final T data;
}

/// The session ended (`SessionManager.destroy`, expiration or a 401 of the backend).
class SessionEnded extends AppEvent {
  const SessionEnded({this.expired = false});

  final bool expired;
}

/// A subscription of [Events.subscribe]: [cancel] stops it.
class Subscription {
  Subscription._(this._accepts, this._handler, this._active);

  final bool Function(AppEvent e) _accepts;
  final void Function(AppEvent e) _handler;

  /// Whether the subscriber is in use now (a visible screen). While it is not, it keeps only the last
  /// event and receives it with [resume].
  final bool Function()? _active;
  AppEvent? _pending;

  void _deliver(AppEvent e) {
    if (_active?.call() ?? true) {
      _handler(e);
    } else {
      _pending = e;
    }
  }

  /// Delivers the event that arrived while the subscriber was not in use, if any.
  void resume() {
    final e = _pending;
    _pending = null;
    if (e != null) _handler(e);
  }

  void cancel() => Events._subs.remove(this);
}

/// The global event manager (publish / subscribe), like Guava's EventBus or Node's EventEmitter.
///
/// Delivery is on demand: a subscriber with `active` (every screen, through [EventBuilder],
/// [EventListener] and [GlobalEvents]) receives an event only while it is visible; a hidden one keeps
/// the last event and gets it when it is visible again. Subscribers without `active` (global
/// components, services) always receive it. Events published in another isolate of the app reach the
/// main one.
class Events extends Global {
  Events();

  static final List<Subscription> _subs = [];

  /// The last event of each type, for widgets created after it was published.
  static final Map<Type, AppEvent> _last = {};

  static const String _port = 'dragonfly.events';
  static ReceivePort? _receiver;
  static final Map<String, AppEvent Function(Map<String, dynamic> json)> _decoders = {};

  /// How the event [name] is read back from its JSON (`registerModels` of `dragonfly.g.dart` calls it).
  static void decoder(String name, AppEvent Function(Map<String, dynamic> json) fromJson) => _decoders[name] = fromJson;

  static void publish(AppEvent event) {
    // in a background isolate (Dragonfly was not started there) the event goes to the main isolate; the web has
    // no isolates
    if (!kIsWeb && !Dragonfly.started) {
      final main = IsolateNameServer.lookupPortByName(_port);
      if (main != null) {
        final name = event.eventName;
        // as text: maps sent between engines lose their types
        return main.send(name == null ? event : [name, jsonEncode(event.toJson())]);
      }
    }
    _last[event.runtimeType] = event;
    for (final s in List.of(_subs)) {
      if (s._accepts(event)) s._deliver(event);
    }
  }

  /// Calls [handler] with each event of type [T] published from now on. With [active], only while it
  /// returns true (see [Subscription.resume]).
  static Subscription subscribe<T extends AppEvent>(void Function(T event) handler, {bool Function()? active}) {
    final s = Subscription._((e) => e is T, (e) => handler(e as T), active);
    _subs.add(s);
    return s;
  }

  /// The last event of type [T] published, if any.
  static T? last<T extends AppEvent>() {
    for (final e in _last.values) {
      if (e is T) return e;
    }
    return null;
  }

  /// Receives the events that background isolates of the app publish (called by [Dragonfly.start]).
  @override
  Future<void> init() async {
    if (kIsWeb) return;
    _receiver ??= ReceivePort()..listen(_receive);
    IsolateNameServer.removePortNameMapping(_port);
    IsolateNameServer.registerPortWithName(_receiver!.sendPort, _port);
  }

  static void _receive(Object? message) {
    if (message is! List) return publish(message! as AppEvent);
    final name = message[0] as String;
    final decode = _decoders[name];
    if (decode == null) return Log.w('event $name from another isolate has no decoder: it is not an event of this app');
    publish(decode(jsonDecode(message[1] as String) as Map<String, dynamic>));
  }

  @override
  void register(GetIt di) => di.registerSingleton<Events>(this);

  @override
  Future<void> dispose() async {
    _last.clear();
    _subs.clear();
    if (kIsWeb) return;
    IsolateNameServer.removePortNameMapping(_port);
    _receiver?.close();
    _receiver = null;
  }
}

/// Event subscriptions that follow the screen of a [State]: [onEvent] handlers run while the screen is
/// the visible route; the last event that arrived while it was hidden runs when it is visible again.
/// The subscriptions end with the widget.
mixin EventsOnDemand<W extends StatefulWidget> on State<W> {
  bool _visible = true;
  final List<Subscription> _eventSubs = [];

  void onEvent<T extends AppEvent>(void Function(T event) handler) =>
      _eventSubs.add(Events.subscribe<T>((e) => mounted ? handler(e) : null, active: () => _visible));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute.of makes this widget rebuild when its route stops or starts being the visible one
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    if (visible && !_visible) {
      // after the frame: a handler may navigate or call setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final s in _eventSubs) {
          s.resume();
        }
      });
    }
    _visible = visible;
  }

  @override
  void dispose() {
    for (final s in _eventSubs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Rebuilds with the last event of type [T] (null until one is published) while its screen is visible.
class EventBuilder<T extends AppEvent> extends StatefulWidget {
  const EventBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, T? event) builder;

  @override
  State<EventBuilder<T>> createState() => _EventBuilderState<T>();
}

class _EventBuilderState<T extends AppEvent> extends State<EventBuilder<T>> with EventsOnDemand {
  T? _event = Events.last<T>();

  @override
  void initState() {
    super.initState();
    onEvent<T>((e) => setState(() => _event = e));
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _event);
}

/// Runs [onEvent] for each event of type [T] while its screen is visible (navigate, show a popup...).
class EventListener<T extends AppEvent> extends StatefulWidget {
  const EventListener({super.key, required this.onEvent, required this.child});

  final void Function(BuildContext context, T event) onEvent;
  final Widget child;

  @override
  State<EventListener<T>> createState() => _EventListenerState<T>();
}

class _EventListenerState<T extends AppEvent> extends State<EventListener<T>> with EventsOnDemand {
  @override
  void initState() {
    super.initState();
    onEvent<T>((e) => widget.onEvent(context, e));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
