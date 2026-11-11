import 'package:dragonfly/dragonfly.dart';
import 'package:json_annotation/json_annotation.dart';

part 'force_update_required.g.dart';

/// Global event: any component publishes it with Events.publish(ForceUpdateRequired(...)).
@JsonSerializable(explicitToJson: true)
class ForceUpdateRequired extends AppEvent {
  const ForceUpdateRequired({required this.minVersion});

  factory ForceUpdateRequired.fromJson(Map<String, dynamic> json) => _$ForceUpdateRequiredFromJson(json);

  final String minVersion;

  @override
  String get eventName => 'ForceUpdateRequired';

  @override
  Map<String, dynamic> toJson() => _$ForceUpdateRequiredToJson(this);
}
