import 'package:dragonfly/dragonfly.dart';
import 'package:json_annotation/json_annotation.dart';

part 'force_logout.g.dart';

/// The backend asks to close the session: any response with the header x-app-event: force_logout publishes it
/// (EventInterceptor in project_config).
@JsonSerializable(explicitToJson: true)
class ForceLogout extends AppEvent {
  const ForceLogout({this.reason});

  factory ForceLogout.fromJson(Map<String, dynamic> json) => _$ForceLogoutFromJson(json);

  final String? reason;

  @override
  String get eventName => 'ForceLogout';

  @override
  Map<String, dynamic> toJson() => _$ForceLogoutToJson(this);
}
