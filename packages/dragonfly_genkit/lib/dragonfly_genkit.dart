/// Genkit for Dragonfly apps (the `genkit` plugin of the flutter dialect): providers in the project config, tools,
/// flows, chats, remote flows and a knowledge base. The app's generated `dragonfly_genkit.g.dart` starts it.
library;

export 'package:genkit/genkit.dart'
    show Genkit, GenkitPlugin, Message, ModelRef, EmbedderRef, Part, TextPart, Role, Tool, ToolResult;
export 'package:schemantic/schemantic.dart' show SchemanticType;

export 'src/chat.dart';
export 'src/flows.dart';
export 'src/knowledge.dart';
export 'src/providers.dart';
export 'src/remote.dart';
export 'src/runtime.dart';
export 'src/schemas.dart';
export 'src/tools.dart';
