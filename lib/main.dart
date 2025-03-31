import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(const VirtualAquariumApp());
}

class VirtualAquariumApp extends StatelessWidget {
  const VirtualAquariumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Aquarium',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true, // Enable Material 3 design
      ),
      home: const MyHomePage(),
    );
  }
}

class Fish {
  final Color color;
  double dx;
  double dy;
  double speed;
  // Add direction to make movement more natural
  double directionX;
  double directionY;

  Fish({
    required this.color, 
    required this.dx, 
    required this.dy, 
    required this.speed,
  }) : 
    directionX = Random().nextDouble() * 2 - 1,
    directionY = Random().nextDouble() * 2 - 1;
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  List<Fish> fishList = [];
  late AnimationController _controller;
  Color selectedColor = Colors.blue;
  double speed = 2.0;
  final Random _random = Random(); // Create a single Random instance
  // Set container dimensions as constants
  final double containerWidth = 300;
  final double containerHeight = 300;
  final double fishSize = 20;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 50), vsync: this);
    _controller.addListener(_updateFishPositions);
    _controller.repeat();
    _loadSettings();
  }

  void _updateFishPositions() {
    setState(() {
      for (var fish in fishList) {
        // Occasionally change direction for more natural movement
        if (_random.nextDouble() < 0.05) {
          fish.directionX = _random.nextDouble() * 2 - 1;
          fish.directionY = _random.nextDouble() * 2 - 1;
        }
        
        // Move fish based on direction and speed
        fish.dx += fish.directionX * fish.speed;
        fish.dy += fish.directionY * fish.speed;
        
        // Bounce off walls
        if (fish.dx <= 0 || fish.dx >= containerWidth - fishSize) {
          fish.directionX *= -1;
          fish.dx = fish.dx.clamp(0, containerWidth - fishSize);
        }
        if (fish.dy <= 0 || fish.dy >= containerHeight - fishSize) {
          fish.directionY *= -1;
          fish.dy = fish.dy.clamp(0, containerHeight - fishSize);
        }
      }
    });
  }

  Future<void> _addFish() async {
    if (fishList.length < 10) {
      setState(() {
        fishList.add(Fish(
          color: selectedColor,
          dx: _random.nextDouble() * (containerWidth - fishSize),
          dy: _random.nextDouble() * (containerHeight - fishSize),
          speed: speed,
        ));
      });
      
      // Save settings after adding a fish
      await _saveSettings();
    } else {
      // Show a snackbar if fish limit is reached
      Text('Maximum 10 fish allowed!');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final database = await openDatabase(
        join(await getDatabasesPath(), 'aquarium.db'),
        onCreate: (db, version) {
          return db.execute(
            "CREATE TABLE settings (id INTEGER PRIMARY KEY, count INTEGER, speed REAL, color INTEGER)",
          );
        },
        version: 1,
      );
      
      // Clear existing settings first
      await database.delete('settings');
      
      // Then insert new settings
      await database.insert(
        'settings', 
        {
          'id': 1, // Use a consistent ID to ensure only one row
          'count': fishList.length, 
          'speed': speed, 
          'color': selectedColor.value
        }
      );
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final database = await openDatabase(
        join(await getDatabasesPath(), 'aquarium.db'),
        version: 1,
      );
      
      List<Map<String, dynamic>> settings = await database.query('settings');
      if (settings.isNotEmpty) {
        setState(() {
          speed = settings[0]['speed'] as double;
          selectedColor = Color(settings[0]['color'] as int);
          
          // Recreate fish based on saved count
          final int count = settings[0]['count'] as int;
          fishList = List.generate(
            count,
            (_) => Fish(
              color: selectedColor,
              dx: _random.nextDouble() * (containerWidth - fishSize),
              dy: _random.nextDouble() * (containerHeight - fishSize),
              speed: speed,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // Add method to remove all fish
  void _clearAquarium() {
    setState(() {
      fishList.clear();
    });
    _saveSettings();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Aquarium'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: containerWidth,
                height: containerHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.lightBlue, Colors.blue],
                  ),
                ),
                child: Stack(
                  children: fishList.map((fish) => Positioned(
                    left: fish.dx,
                    top: fish.dy,
                    child: Transform.scale(
                      scaleX: fish.directionX < 0 ? -1.0 : 1.0, // Flip fish based on direction
                      child: Container(
                        width: fishSize,
                        height: fishSize,
                        decoration: BoxDecoration(
                          color: fish.color,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10),
                            right: Radius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Fish count: ${fishList.length}/10', 
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _addFish, 
                    child: const Text('Add Fish')
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _clearAquarium,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                    ),
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Fish Speed:'),
              Slider(
                value: speed,
                min: 1,
                max: 5,
                divisions: 4,
                label: speed.toStringAsFixed(1),
                onChanged: (value) {
                  setState(() {
                    speed = value;
                    // Update speed for existing fish
                    for (var fish in fishList) {
                      fish.speed = value;
                    }
                  });
                  _saveSettings();
                },
              ),
              const SizedBox(height: 8),
              const Text('Fish Color:'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Colors.blue, Colors.red, Colors.green, Colors.yellow, Colors.purple, Colors.orange]
                  .map((color) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => selectedColor = color);
                        _saveSettings();
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color ? Colors.black : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ))
                  .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}