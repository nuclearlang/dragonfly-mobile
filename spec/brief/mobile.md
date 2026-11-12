# Platform `mobile` brief: Dragonfly apps

A Dragonfly app has only `.nuc` files and `assets/`; the app is generated in `build/app` (never edit it). You write
the business logic; the framework writes the rest (DI, routing, JSON, states, tests). The views use the UI toolkit's
classes from the type definitions (`Text`, `Scaffold`, `Icons.add`), with `name = value` arguments.

## Work cycle

1. Skeleton first: `dragonfly make component|screen|usecase|repository|model|event|guard|widget|page|test ...`
   (`dragonfly help`). It puts each file in its folder with its kind.
2. Write following this sheet. Unsure about an API: `nuclear defs show <Name> --platform mobile`; a topic:
   `nuclear help mobile`; where each file goes: `nuclear help layout --platform mobile`. Never guess a constructor
   or an argument.
3. `dragonfly check --json` until `[]`, then `dragonfly test`.

## Layout and kinds (the folder gives the kind of a declaration without a header word)

```
main.nuc  config.nuc  config/ (appConfig)  assets/i18n/<locale>/<component>.json
shared/ widgets/ events/ models/ components/ guards/ converters/ screens/
components/<c>/<c>_component.nuc        appcomponent: the facade, the only thing other components see
components/<c>/data/                    repository
components/<c>/domain/models/           model (no word)
components/<c>/domain/usecases/         usecase
components/<c>/presentation/<screen>/   <screen>_screen.nuc, managers/, state_models/ (no word), forms/ (no word)
test/                                   tests (no word)
```

Calls allowed (N0301/N0302): screen → statemanager → appcomponent → usecase → repository/service. Another
component sees only the appcomponent, models, events, guards and screens. Only views (`stateless`/`stateful`)
use `BuildContext` and navigate.

## Pieces

```nuclear
// model (domain/models/): only fields; fromJson/toJson/== are generated. @key("json_name"), @DateConverter
Character
  id: int
  name: string
  status: string

// repository (data/): each method is an HTTP call; :id goes to the path, other params to the query/body
@repository(path = "character")
repository CharacterRepository
  @get(path = ":id")
  getOne(id: int) Result<CharacterError, Character>

  @get(cache = true, ttl = Duration(minutes = 10))
  getPage(page: int, name: string = "") Result<CharacterError, Page<Character>>

// usecase (domain/usecases/): one method exec, returns Result; dependencies in the constructor line
usecase GetPageUseCase
  (repository: CharacterRepository)

  @requires(internet = true)
  exec(page: int) Result<CharacterError, Character[]>
    data = ~repository.getPage(page)
    Ok(data.results)

// appcomponent (<c>_component.nuc): aliases to the use cases
appcomponent CharactersComponent
  getPage() = GetPageUseCase.exec

// state model (state_models/): each field is a state of the screen; a boolean is a state without data
CharactersState
  (full: Character[], error: CharacterError, loading: boolean)

// statemanager (managers/): @state(M.x) emits that state with the value; an Err emits `error`
@stateModel(CharactersState)
statemanager CharactersManager
  (characters: CharactersComponent)
    loadPage(1)

  @state(CharactersState.loading)
  loading()

  @before(loading)
  @state(CharactersState.full)
  loadPage(page: int) Result<CharacterError, Character[]>
    ~characters.getPage(page)

// screen: @screen(route, providers, loggedIn = { forward: X }, acl = {...}, shell = {...}, transition = ...)
@screen(route = "/characters", providers = [CharactersManager])
stateless CharacterListScreen
  build(context: BuildContext) Widget
    Scaffold(
      appBar = AppBar(title = Text("characters.list.title".tr())),
      body = CharactersStateBuilder<CharactersManager>(
        loading = () => Center(child = CircularProgressIndicator()),
        full = (list) => ListView.builder(
          itemCount = list.length,
          itemBuilder = (context, i) => ListTile(
            title = Text(list[i].name),
            onTap = () => context.pushTo(CharacterDetailScreen(id = list[i].id)),
          ),
        ),
        error = (e) => Center(child = Text(e.message)),
      ),
    )
```

- Inside a screen, `Manager.method()` calls the screen's provider; `<State>Builder<Manager>` has one callback per
  state (`initial`, `orElse` optional). A `stateful` has `initState()` and fields.
- Navigation (views only): `context.goTo(Screen(...))`, `~context.pushTo(Screen())`, `context.goBack(value)`.
- Texts: `"component.screen.key".tr()` / `.tr({"n": 2})` from `assets/i18n/<locale>/<component>.json`.
- Logs: `Log.d/i/s/w/e("message", data = {...})`. Popups: `DragonflyDialog(header = ..., child = ...).show(context)`,
  `Popups.toast(context, text)`.
- Session: `SessionManager` (`~session.start(auth, roles = [...])`, `session.get<Auth>()`, `~session.destroy()`).
- Events: `event Name` + fields in `shared/events/`; `Events.publish(Name(...))`; a `component` in
  `shared/components/` with `@on(Name)` on a method receives them; `EventBuilder<Name>` / `EventListener<Name>` in views.
- Access: `guard Name` + `(deps)` + `canActivate() boolean` (may use `~`) in `shared/guards/`;
  `@screen(acl = { roles: ["fan"], guards: [Name], forward: DeniedScreen })`; `@acl(roles = [...])` on a use case.
- Forms: a form model in `forms/` (`@required @email @minLength(n) @matches("field")` on fields), a
  `@form(F) formmanager` in `managers/` (`@validate("field")` = remote check), and in the view
  `DragonflyForm(manager = M, onSubmit = (form) => ..., child = ...)` with `FormTextField("field", label = ...)`
  and `FormSubmit(child = ...)`.
- Tests (`test/`, no word): `@mock([Repo])` on a group; `@test("...")`, `@states("...", expect = [...])`,
  `@widget("...")` on methods; `when(() => Repo.m(1)).thenReturnAsync(Ok(x))`, `expect(r, isOkWith(x))`,
  `~tester.pumpScreen(Screen())`.

## Plugins and Genkit

`config.nuc` enables the optional parts: `plugins(genkit = true, googleAI = true)` (also `firebaseAI`, `vertexAI`,
`openAI`, `anthropic`); a kind or class of a plugin not enabled is N0304. With `genkit`: the provider among the
connections (`GoogleAI(model = "gemini-flash-latest")`, `OpenAI(model = "...", baseUrl = "http://localhost:11434/v1")`)
and the kinds `tools Name` (methods with a doc comment), `chat Name(tools: T)` + `prompt` (`~chat.send(text)`,
`ChatController(chat)` for a screen), `flow Name` + `run(input: I) O` (`~generateObject<Model>(prompt)`),
`remote` (`@remote(url)`, `@flow("path")`/`@stream("path")`), `knowledge Name` + `documents() string[]`
(`~kb.search(q)`). Tests: `startFakeGenkit(["answer"])`. `nuclear help <kind> --platform mobile`.

