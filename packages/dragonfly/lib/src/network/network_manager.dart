import 'dart:async';
import 'dart:io' as io;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../core.dart';

enum NetworkType { none, wifi, mobile, ethernet, other }

enum NetworkQuality { none, weak, strong }

@immutable
class NetworkStatus {
  const NetworkStatus({this.type = NetworkType.other, this.quality = NetworkQuality.strong, this.latency});

  static const offline = NetworkStatus(type: NetworkType.none, quality: NetworkQuality.none);

  final NetworkType type;
  final NetworkQuality quality;

  /// Time of the last probe.
  final Duration? latency;

  bool get online => quality != NetworkQuality.none;

  @override
  bool operator ==(Object other) => other is NetworkStatus && other.type == type && other.quality == quality;

  @override
  int get hashCode => Object.hash(type, quality);

  @override
  String toString() => 'NetworkStatus($type, $quality)';
}

/// Whether the device can reach the internet, the connection type and its quality. It probes only when
/// the connectivity changes (debounced) or when [check] is called, to save battery and data.
class NetworkManager extends Global {
  NetworkManager({
    this.probeHost = 'example.com',
    this.weakAfter = const Duration(milliseconds: 600),
    this.debounce = const Duration(milliseconds: 500),
    Connectivity? connectivity,
  }) : connectivity = connectivity ?? Connectivity(),
       _fixed = null;

  /// A manager that always reports [status] and never asks the system (tests, previews).
  NetworkManager.fixed(NetworkStatus status)
    : probeHost = '',
      weakAfter = Duration.zero,
      debounce = Duration.zero,
      connectivity = Connectivity(),
      _fixed = status;

  final NetworkStatus? _fixed;

  /// Host resolved to know that the internet (not only the local network) is reachable.
  final String probeHost;

  /// A probe slower than this is a weak connection.
  final Duration weakAfter;
  final Duration debounce;

  final Connectivity connectivity;
  final ValueNotifier<NetworkStatus> status = ValueNotifier(const NetworkStatus());
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _timer;

  bool get online => status.value.online;

  @override
  void register(GetIt di) => di.registerSingleton<NetworkManager>(this);

  @override
  Future<void> init() async {
    if (_fixed != null) {
      status.value = _fixed;
      return;
    }
    _sub = connectivity.onConnectivityChanged.listen((r) {
      _timer?.cancel();
      _timer = Timer(debounce, () => check(r));
    });
    // the first probe does not delay the start of the app; until it answers, the status is online
    unawaited(check());
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _sub?.cancel();
  }

  /// Probes now and updates [status].
  Future<NetworkStatus> check([List<ConnectivityResult>? results]) async {
    if (_fixed != null) return status.value;
    final r = results ?? await connectivity.checkConnectivity();
    final type = typeOf(r);
    if (type == NetworkType.none) return status.value = NetworkStatus.offline;
    // a browser cannot resolve names: it trusts what the browser reports
    if (kIsWeb) return status.value = NetworkStatus(type: type);
    final watch = Stopwatch()..start();
    try {
      final found = await io.InternetAddress.lookup(probeHost).timeout(weakAfter * 4);
      if (found.isEmpty) return status.value = NetworkStatus.offline;
    } on Object {
      return status.value = NetworkStatus.offline;
    }
    final latency = watch.elapsed;
    final quality = latency > weakAfter ? NetworkQuality.weak : NetworkQuality.strong;
    return status.value = NetworkStatus(type: type, quality: quality, latency: latency);
  }

  static NetworkType typeOf(List<ConnectivityResult> r) {
    if (r.contains(ConnectivityResult.wifi)) return NetworkType.wifi;
    if (r.contains(ConnectivityResult.ethernet)) return NetworkType.ethernet;
    if (r.contains(ConnectivityResult.mobile)) return NetworkType.mobile;
    if (r.isEmpty || r.every((x) => x == ConnectivityResult.none)) return NetworkType.none;
    return NetworkType.other;
  }
}

/// Rebuilds when the network status changes.
class NetworkBuilder extends StatelessWidget {
  const NetworkBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, NetworkStatus status) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<NetworkStatus>(
    valueListenable: inject<NetworkManager>().status,
    builder: (c, s, _) => builder(c, s),
  );
}

/// Wraps the whole app: shows [offline] (a banner by default) over it while there is no internet.
class NetworkWrapper extends StatelessWidget {
  const NetworkWrapper({super.key, required this.child, this.offline});

  final Widget child;
  final Widget? offline;

  @override
  Widget build(BuildContext context) => NetworkBuilder(
    builder: (context, status) => Stack(
      children: [
        child,
        if (!status.online)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child:
                offline ??
                const Material(
                  color: Colors.black87,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No internet connection', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
          ),
      ],
    ),
  );
}
