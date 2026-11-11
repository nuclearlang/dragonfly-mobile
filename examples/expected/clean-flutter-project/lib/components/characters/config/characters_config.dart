import 'package:dragonfly/dragonfly.dart';

/// Configuration of the characters component: a connection only for its images, and the color of its logs
/// (without logColor, one is chosen by the component's name).
class CharactersConfig extends ComponentConfig {
  @override
  final LogColor logColor = LogColor.mint;
  @override
  final List<Connection> connections = [
    Http(
      connectionName: 'images',
      baseUrl: 'https://rickandmortyapi.com/api/character/avatar/',
    ),
  ];
}
