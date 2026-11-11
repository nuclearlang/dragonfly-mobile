# Genkit in a Flutter app

The `genkit` plugin of the `flutter` dialect brings **Genkit Dart** into a Dragonfly app: chats with memory and
tools, typed flows with structured output, search by meaning (RAG) and flows of a Genkit server, all written in
Nuclear. This guide follows `examples/examples-flutter-dialect/genkit-assistant`, a chat assistant that keeps notes
and runs on a local Ollama. The full rules are in [flutter.md §6.20](../../spec/flutter.md).

## 1. Enable it

Genkit is a plugin: an app that does not enable it does not carry its packages. Enable `genkit` and one provider in
`config.nuc`; `dragonfly build` adds their packages to the app:

```nuclear
plugins(genkit = true, openAI = true)
```

Then declare the provider among the connections:

```nuclear
appConfig ProjectConfig
  connections: Connection[] = [
    OpenAI(model = "qwen3.5:4b", baseUrl = "http://localhost:11434/v1", apiKey = "ollama", embedder = "embeddinggemma"),
  ]
```

| Plugin | Connection | Notes |
|---|---|---|
| `firebaseAI` | `FirebaseAI(model = "gemini-flash-latest")` | Firebase AI Logic: no API key in the app (App Check); run `flutterfire configure` in the app |
| `googleAI` | `GoogleAI(model = ..., embedder = ..., apiKey = ...)` | Gemini API (`GEMINI_API_KEY`) |
| `vertexAI` | `VertexAI(model = ..., projectId = ..., location = ...)` | Google Cloud |
| `openAI` | `OpenAI(model = ..., apiKey = ..., baseUrl = ...)` | also any OpenAI-compatible server, such as Ollama |
| `anthropic` | `Anthropic(model = ..., apiKey = ...)` | Claude models |

A key written in an app can be read by anyone who has the app. For production, prefer `FirebaseAI` or a remote flow
on your server.

## 2. Tools and a chat

The methods of `tools` with a doc comment are the tools the model can call; the comment is the description and the
parameters become the JSON schema. A method without a comment is a helper:

```nuclear
tools NoteTools
  notes: string[] = []

  // Saves a note with the given text.
  addNote(text: string) string
    notes.add(text)
    "saved note ${notes.length}: ${text}"

  // Lists every saved note, one per line.
  listNotes() string
    if notes.isEmpty
      return "there are no notes"
    numbered(notes)

  numbered(items: string[]) string
    items.asMap().entries.map((e) => "${e.key + 1}. ${e.value}").join("\n")
```

A `chat` keeps the conversation; its dependencies of kind `tools` are its tools:

```nuclear
chat Assistant(notes: NoteTools)
  prompt: string = "You are a helpful assistant. Use the tools to save and list notes. Answer briefly."
```

`~chat.send(text)` answers the whole reply, and `chat.stream(text)` answers it piece by piece. For a screen,
`ChatController` keeps the messages and the streaming state:

```nuclear
@screen(route = "/")
stateful ChatScreen
  controller: ChatController = ChatController(inject<Assistant>())
  input: TextEditingController = TextEditingController()

  send() void
    text = input.text
    input.clear()
    controller.send(text)

  build(context: BuildContext) Widget
    Scaffold(
      appBar = AppBar(title = Text("Assistant")),
      body = ListenableBuilder(
        listenable = controller,
        builder = (context, child) => Column(children = [
          Expanded(child = ListView(children = controller.messages.map((m) => ListTile(
            title = Text(m.text),
            leading = Icon(m.fromUser ? Icons.person : Icons.smart_toy),
          )))),
          if controller.sending LinearProgressIndicator(),
          TextField(controller = input, onSubmitted = (text) => send()),
        ]),
      ),
    )
```

## 3. A flow with structured output

A `flow` is a typed Genkit flow (traced, visible in the Developer UI). `~generateObject<Summary>(prompt)` asks the
model for a model of the app; its schema is generated from the fields:

```nuclear
Summary
  title: string
  points: string[]

flow Summarize
  run(text: string) Summary
    ~generateObject<Summary>("Summarize this text as a title and at most 3 short points: ${text}")
```

```dart
class Summarize extends GenkitFlow<String, Summary> {
  @override
  String get flowName => 'summarize';

  @override
  Future<Summary> run(String text) async {
    return await generateObject<Summary>('Summarize this text as a title and at most 3 short points: $text');
  }
}
```

A class that receives it (`summarize: Summarize` as a dependency) runs it with `~summarize(text)`.

## 4. Knowledge (RAG)

A `knowledge` holds texts searched by meaning with the provider's embedder:

```nuclear
knowledge Faq
  documents() string[]
    [
      "Notes are kept only while the app is open.",
      "The assistant runs on a local Ollama model.",
      "Summaries have a title and at most three points.",
    ]
```

`~faq.search(question, k = 4)` gives the closest texts with their score. `~faq.context(question)` gives them as one
text to put in a prompt.

## 5. Flows of a Genkit server

When the model must run on a server (secret keys, heavy work), deploy the flows with Genkit (Node, Go, Python or
Dart) and call them like an API. A method without a body is a call to the flow at that path:

```nuclear
@remote("http://localhost:3400")
remote StoryFlows
  @flow("tellJoke")
  tellJoke(topic: string) string

  @stream("streamStory")
  story(topic: string) string
```

`~flows.tellJoke("cats")` answers the result; `flows.story("dragons")` is a `Stream<String>` of the pieces.

## 6. Tests

`startFakeGenkit([...])` replaces the provider with a model that gives fixed answers and an embedder without network,
so the tests run offline:

```nuclear
tests AssistantTests
  setUp() void
    startFakeGenkit(["I saved it.", "Hello!"])

  @test("the chat answers and the tools keep notes")
  chatAndTools() void
    notes = NoteTools()
    expect(notes.addNote("buy milk"), "saved note 1: buy milk")
    expect(notes.tools().length, 2)
    chat = Assistant(notes)
    expect(~chat.send("save buy milk"), "I saved it.")
```

## 7. Run it

```sh
ollama pull qwen3.5:4b && ollama pull embeddinggemma   # for the example's local provider
dragonfly build && dragonfly test
dragonfly run
```
