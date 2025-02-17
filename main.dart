import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gerenciador de Planetas',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color.fromARGB(255, 0, 102, 255),
          secondary: Color.fromARGB(255, 68, 149, 255),
        ),
      ),
      home: const PlanetListPage(),
    );
  }
}

class Planet {
  int? id;
  String name;
  double distanceFromSun;
  double size;
  String? nickname;

  Planet({
    this.id,
    required this.name,
    required this.distanceFromSun,
    required this.size,
    this.nickname,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'distanceFromSun': distanceFromSun,
      'size': size,
      'nickname': nickname,
    };
  }

  factory Planet.fromMap(Map<String, dynamic> map) {
    return Planet(
      id: map['id'],
      name: map['name'],
      distanceFromSun: map['distanceFromSun'],
      size: map['size'],
      nickname: map['nickname'],
    );
  }
}

class PlanetDetailPage extends StatelessWidget {
  final Planet planet;
  final Function(int) onDelete;

  const PlanetDetailPage({super.key, required this.planet, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final double distanceKm = planet.distanceFromSun * 149597870.7;
    final double planetSize = planet.size * 1000.0;
    final double area = 4 * 3.1416 * (planetSize / 2) * (planetSize / 2);

    return Scaffold(
      appBar: AppBar(title: Text('${planet.name} - ${planet.nickname ?? ''}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distância do Sol:'),
            Text('Unidade Astronômica: ${planet.distanceFromSun} UA'),
            Text('Quilômetros: ${distanceKm.toStringAsFixed(2)} km'),
            const SizedBox(height: 20),
            Text('Tamanho do Planeta:'),
            Text('Diâmetro: ${planetSize} km'),
            Text('Área Superficial: ${area.toStringAsFixed(2)} km²'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                onDelete(planet.id!);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Deletar Planeta', style: TextStyle(color: Color.fromARGB(255, 20, 20, 20)),),
            ),
          ],
        ),
      ),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('planets.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE planets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        distanceFromSun REAL NOT NULL,
        size REAL NOT NULL,
        nickname TEXT
      )
    ''');
  }

  Future<void> insertPlanet(Planet planet) async {
    final db = await instance.database;
    await db.insert('planets', planet.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Planet>> fetchPlanets() async {
    final db = await instance.database;
    final result = await db.query('planets');
    return result.map((map) => Planet.fromMap(map)).toList();
  }

  Future<void> deletePlanet(int id) async {
    final db = await instance.database;
    await db.delete('planets', where: 'id = ?', whereArgs: [id]);
  }
}

class PlanetListPage extends StatefulWidget {
  const PlanetListPage({super.key});

  @override
  State<PlanetListPage> createState() => _PlanetListPageState();
}

class _PlanetListPageState extends State<PlanetListPage> {
  List<Planet> planets = [];

  @override
  void initState() {
    super.initState();
    _loadPlanets();
  }

  Future<void> _loadPlanets() async {
    final fetchedPlanets = await DatabaseHelper.instance.fetchPlanets();
    setState(() {
      planets = fetchedPlanets;
    });
  }

  void _addPlanet() async {
    final Planet? newPlanet = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (ctx) => const PlanetFormPage()), 
    );
    if (newPlanet != null) {
      await DatabaseHelper.instance.insertPlanet(newPlanet);
      _loadPlanets();
    }
  }

  void _deletePlanet(int id) async {
    await DatabaseHelper.instance.deletePlanet(id);
    _loadPlanets();
  }

  void _viewPlanetDetail(Planet planet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlanetDetailPage(
          planet: planet,
          onDelete: (id) {
            _deletePlanet(id);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planetas')),
      body: ListView.builder(
        itemCount: planets.length,
        itemBuilder: (context, index) {
          final planet = planets[index];
          return Card(
            child: ListTile(
              title: Text(planet.name),
              subtitle: Text('Tamanho: ${planet.size * 1000} km'),
              onTap: () => _viewPlanetDetail(planet),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deletePlanet(planet.id!),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPlanet,
        child: const Icon(Icons.add),
      ),
    );
  }
}


class PlanetFormPage extends StatefulWidget {
  const PlanetFormPage({super.key});

  @override
  State<PlanetFormPage> createState() => _PlanetFormPageState();
}

class _PlanetFormPageState extends State<PlanetFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  void _savePlanet() {
    if (_formKey.currentState!.validate()) {
      final newPlanet = Planet(
        name: _nameController.text,
        distanceFromSun: double.parse(_distanceController.text),
        size: double.parse(_sizeController.text),
        nickname: _nicknameController.text.isNotEmpty ? _nicknameController.text : null,
      );
      Navigator.pop(context, newPlanet);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Planeta')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) => value!.isEmpty ? 'Nome obrigatório' : null,
              ),
              TextFormField(
                controller: _distanceController,
                decoration: const InputDecoration(labelText: 'Distância (UA)'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Distância obrigatória' : null,
              ),
              TextFormField(
                controller: _sizeController,
                decoration: const InputDecoration(labelText: 'Diâmetro (km)'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Tamanho obrigatório' : null,
              ),
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(labelText: 'Apelido (Opcional)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _savePlanet,
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
