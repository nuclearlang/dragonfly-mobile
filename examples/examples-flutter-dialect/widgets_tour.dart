import 'dart:convert';
import 'package:flutter/material.dart';

// A tour of the most common Flutter patterns written in Nuclear.
// Every Flutter and Dart widget and class is imported on its own.

void main() {
  runApp(TourApp());
}

class TourApp extends StatelessWidget {
  const TourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tour',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {'/': (context) => HomePage(), '/form': (context) => SignUpPage()},
    );
  }
}

enum Status {
  alive,
  dead,
  unknown
}

class Character {
  int id;
  String name;
  Status status;

  Character(this.id, this.name, this.status);

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'status': status.name};
  }
}

List<Character> parseCharacters(String body) {
  final list = jsonDecode(body) as List<dynamic>;
  return list.map((dynamic item) {
    final json = item as Map<String, dynamic>;
    return Character(
      json['id'] as int,
      json['name'] as String,
      Status.values.byName(json['status'] as String),
    );
  }).toList();
}

/// Main screen: async loading, list with builder and navigation.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Character> characters = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final body = await Future.delayed(
      Duration(milliseconds: 300),
      () => '[{"id": 1, "name": "Rick", "status": "alive"}]',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      characters = parseCharacters(body);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Characters'),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: () => Navigator.pushNamed(context, '/form'),
          ),
        ],
      ),
      body: loading ? Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: () => load(),
        child: ListView.builder(
          itemCount: characters.length,
          itemBuilder: (context, index) {
            final character = characters[index];
            return ListTile(
              leading: StatusBadge(status: character.status),
              title: Text(character.name),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tapped ${character.name}'))),
            );
          },
        ),
      ),
      floatingActionButton: SpinningLogo(),
    );
  }
}

/// A getter and a match as a value.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final Status status;

  Color get color {
    if (status == Status.alive) {
      return Colors.green;
    } else if (status == Status.dead) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(
        status.name,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Animation: the mixin goes to the State.
class SpinningLogo extends StatefulWidget {
  const SpinningLogo({super.key});

  @override
  State<SpinningLogo> createState() => _SpinningLogoState();
}

class _SpinningLogoState extends State<SpinningLogo> with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: Duration(seconds: 2));
    controller.repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: controller, child: FlutterLogo(size: 48));
  }
}

/// Form: generic GlobalKey, validation and `!`.
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  String email = '';
  bool accepted = false;

  void submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }
    formKey.currentState!.save();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign up')),
      body: Form(
        key: formKey,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                onSaved: (value) {
                  email = value ?? '';
                },
              ),
              SwitchListTile(
                title: Text('I accept the terms'),
                value: accepted,
                onChanged: (value) => setState(() {
                  accepted = value;
                }),
              ),
              ...List.generate(2, (i) => SizedBox(height: 8)),
              FilledButton(onPressed: accepted ? submit : null, child: Text('Send')),
            ],
          ),
        ),
      ),
    );
  }
}

/// A Stream with yield, if inside children and a paint with a cascade.
Stream<int> ticks() async* {
  for (var i = 0; i < 60; i++) {
    await Future.delayed(Duration(seconds: 1));
    yield i;
  }
}

class Clock extends StatelessWidget {
  const Clock({super.key, required this.showLabel});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ticks(),
      builder: (context, snapshot) {
        final seconds = snapshot.data ?? 0;
        return Column(
          children: [
            CustomPaint(painter: Ring(seconds / 60), size: Size(48, 48)),
            if (showLabel) Text('${seconds}s'),
          ],
        );
      },
    );
  }
}

class Ring extends CustomPainter {
  double progress;

  Ring(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final brush = Paint()
      ..color = Colors.indigo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      0,
      progress * 6.28,
      false,
      brush,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
