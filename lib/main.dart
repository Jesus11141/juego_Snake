import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

void main() {
  runApp(SnakeGame());
}

class FoodItem {
  final Offset position;
  final String type;
  final bool isBad;
  final DateTime createdAt;
  
  FoodItem(this.position, this.type, this.isBad) : createdAt = DateTime.now();
}

class StarItem {
  final Offset position;
  final DateTime createdAt;
  
  StarItem(this.position) : createdAt = DateTime.now();
}

class EnemySnake {
  List<Offset> body;
  final DateTime createdAt;
  String direction;
  
  EnemySnake(Offset startPos) : 
    body = [startPos],
    createdAt = DateTime.now(),
    direction = 'right';
}

class SnakeGame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juego de Jacob',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Arial',
      ),
      home: GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int boardSize = 20;
  List<Offset> snake = [Offset(10, 10)];
  List<FoodItem> foods = [];
  List<StarItem> stars = [];
  List<EnemySnake> enemies = [];
  String direction = 'right';
  bool gameRunning = false;
  int score = 0;
  Timer? gameTimer;
  Timer? bonusTimer;
  Timer? itemTimer;
  Timer? enemyTimer;
  bool bonusMode = false;
  String difficulty = 'medio';
  bool showMenu = true;
  
  Map<String, int> speeds = {
    'facil': 300,
    'medio': 200,
    'dificil': 120,
  };
  
  List<String> fruitTypes = ['🍎', '🍊', '🍌', '🍇', '🍓', '🥝'];
  List<String> badFruits = ['💀', '☠️', '🤢'];

  @override
  void initState() {
    super.initState();
    generateFood();
  }
  
  void selectDifficulty(String diff) {
    setState(() {
      difficulty = diff;
      showMenu = false;
    });
    startGame();
  }

  void startGame() {
    snake = [Offset(10, 10)];
    direction = 'right';
    score = 0;
    gameRunning = true;
    bonusMode = false;
    foods.clear();
    stars.clear();
    enemies.clear();
    generateFood();
    
    gameTimer = Timer.periodic(Duration(milliseconds: speeds[difficulty]!), (timer) {
      moveSnake();
    });
    
    // Removido el bonus automático cada 30 segundos
    
    itemTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (gameRunning) {
        manageItems();
        generateRandomItems();
      }
      if (!gameRunning) timer.cancel();
    });
    
    // Timer para serpientes enemigas solo en difícil
    if (difficulty == 'dificil') {
      enemyTimer = Timer.periodic(Duration(seconds: 15), (timer) {
        if (gameRunning) {
          spawnEnemySnake();
        }
        if (!gameRunning) timer.cancel();
      });
    }
  }

  void generateFood() {
    Random random = Random();
    
    // Asegurar al menos 5 frutas en pantalla (3 buenas, 2 malas)
    while (foods.length < 5) {
      Offset pos = _getRandomPosition();
      bool isBad = foods.where((f) => f.isBad).length < 2;
      
      if (isBad && random.nextBool()) {
        String type = badFruits[random.nextInt(badFruits.length)];
        foods.add(FoodItem(pos, type, true));
      } else {
        String type = fruitTypes[random.nextInt(fruitTypes.length)];
        foods.add(FoodItem(pos, type, false));
      }
    }
  }
  
  void manageItems() {
    DateTime now = DateTime.now();
    
    foods.removeWhere((food) => 
      food.isBad && now.difference(food.createdAt).inSeconds >= 10);
    
    stars.removeWhere((star) => 
      now.difference(star.createdAt).inSeconds >= 10);
    
    // Remover serpientes enemigas después de 10 segundos
    enemies.removeWhere((enemy) => 
      now.difference(enemy.createdAt).inSeconds >= 10);
  }
  
  void spawnEnemySnake() {
    if (difficulty != 'dificil' || bonusMode) return;
    
    Random random = Random();
    Offset startPos = Offset(0, 0); // Inicializar
    
    // Generar en los bordes del mapa
    int side = random.nextInt(4);
    switch (side) {
      case 0: // Arriba
        startPos = Offset(random.nextInt(boardSize).toDouble(), 0);
        break;
      case 1: // Abajo
        startPos = Offset(random.nextInt(boardSize).toDouble(), boardSize - 1);
        break;
      case 2: // Izquierda
        startPos = Offset(0, random.nextInt(boardSize).toDouble());
        break;
      case 3: // Derecha
        startPos = Offset(boardSize - 1, random.nextInt(boardSize).toDouble());
        break;
    }
    
    enemies.add(EnemySnake(startPos));
  }
  
  void moveEnemies() {
    for (var enemy in enemies) {
      Offset playerHead = snake.first;
      Offset enemyHead = enemy.body.first;
      
      // IA simple: moverse hacia el jugador
      double dx = playerHead.dx - enemyHead.dx;
      double dy = playerHead.dy - enemyHead.dy;
      
      String newDirection;
      if (dx.abs() > dy.abs()) {
        newDirection = dx > 0 ? 'right' : 'left';
      } else {
        newDirection = dy > 0 ? 'down' : 'up';
      }
      
      enemy.direction = newDirection;
      
      Offset newHead = enemyHead;
      switch (enemy.direction) {
        case 'up':
          newHead = Offset(enemyHead.dx, enemyHead.dy - 1);
          break;
        case 'down':
          newHead = Offset(enemyHead.dx, enemyHead.dy + 1);
          break;
        case 'left':
          newHead = Offset(enemyHead.dx - 1, enemyHead.dy);
          break;
        case 'right':
          newHead = Offset(enemyHead.dx + 1, enemyHead.dy);
          break;
      }
      
      // Verificar límites
      if (newHead.dx < 0 || newHead.dx >= boardSize || 
          newHead.dy < 0 || newHead.dy >= boardSize) {
        continue; // No mover si está fuera de límites
      }
      
      enemy.body.insert(0, newHead);
      
      // Mantener tamaño de 3 segmentos
      if (enemy.body.length > 3) {
        enemy.body.removeLast();
      }
    }
  }
  
  void generateRandomItems() {
    if (bonusMode) return;
    
    Random random = Random();
    
    // Mantener siempre 5 frutas en pantalla
    if (foods.length < 5) {
      generateFood();
    }
    
    // Frecuencias aumentadas para más acción
    Map<String, int> starChance = {
      'facil': 80,   // Más frecuente
      'medio': 60,   // Más frecuente
      'dificil': 40, // Más frecuente
    };
    
    if (stars.isEmpty && random.nextInt(starChance[difficulty]!) == 0) {
      stars.add(StarItem(_getRandomPosition()));
    }
    
    // Ya no generar frutas malas aquí, se manejan en generateFood()
  }
  
  Offset _getRandomPosition() {
    Random random = Random();
    Offset pos;
    do {
      pos = Offset(
        random.nextInt(boardSize - 2).toDouble() + 1, // Evitar bordes
        random.nextInt(boardSize - 2).toDouble() + 1, // Evitar bordes
      );
    } while (snake.contains(pos) || 
             foods.any((f) => f.position == pos) ||
             stars.any((s) => s.position == pos));
    return pos;
  }
  
  void activateBonus() {
    // Cancelar bonus anterior si existe
    bonusTimer?.cancel();
    
    setState(() {
      bonusMode = true;
      foods.clear();
      
      // Generar 12 frutas para más abundancia
      Random random = Random();
      for (int i = 0; i < 12; i++) {
        Offset pos = _getRandomPosition();
        String type = fruitTypes[random.nextInt(fruitTypes.length)];
        foods.add(FoodItem(pos, type, false));
      }
    });
    
    // Cambiar velocidad durante bonus (más rápido)
    gameTimer?.cancel();
    gameTimer = Timer.periodic(Duration(milliseconds: (speeds[difficulty]! * 0.7).round()), (timer) {
      moveSnake();
    });
    
    // Timer fijo de 7 segundos que NO se cancela
    bonusTimer = Timer(Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          bonusMode = false;
          foods.clear();
          generateFood();
        });
        
        // Restaurar velocidad normal
        gameTimer?.cancel();
        gameTimer = Timer.periodic(Duration(milliseconds: speeds[difficulty]!), (timer) {
          moveSnake();
        });
      }
    });
  }

  void moveSnake() {
    setState(() {
      Offset newHead = snake.first;
      
      switch (direction) {
        case 'up':
          newHead = Offset(newHead.dx, newHead.dy - 1);
          break;
        case 'down':
          newHead = Offset(newHead.dx, newHead.dy + 1);
          break;
        case 'left':
          newHead = Offset(newHead.dx - 1, newHead.dy);
          break;
        case 'right':
          newHead = Offset(newHead.dx + 1, newHead.dy);
          break;
      }

      if (difficulty == 'dificil') {
        if (newHead.dx < 0 || newHead.dx >= boardSize || 
            newHead.dy < 0 || newHead.dy >= boardSize) {
          gameOver();
          return;
        }
      } else {
        // Atravesar paredes al lado exactamente opuesto
        if (newHead.dx < 0) {
          newHead = Offset(boardSize - 1, newHead.dy);
        } else if (newHead.dx >= boardSize) {
          newHead = Offset(0, newHead.dy);
        } else if (newHead.dy < 0) {
          newHead = Offset(newHead.dx, boardSize - 1);
        } else if (newHead.dy >= boardSize) {
          newHead = Offset(newHead.dx, 0);
        }
      }

      snake.insert(0, newHead);
      
      // Verificar colisión consigo mismo DESPUÉS de insertar
      if (snake.skip(1).contains(newHead)) {
        gameOver();
        return;
      }

      // Verificar colisión con serpientes enemigas (solo cabeza con cabeza)
      for (var enemy in enemies) {
        if (newHead == enemy.body.first) {
          gameOver();
          return;
        }
      }
      
      // Mover serpientes enemigas a la misma velocidad
      if (difficulty == 'dificil') {
        moveEnemies();
      }

      StarItem? eatenStar;
      for (var star in stars) {
        if (newHead == star.position) {
          eatenStar = star;
          break;
        }
      }
      
      if (eatenStar != null) {
        stars.remove(eatenStar);
        activateBonus();
        snake.removeLast(); // No crecer al comer estrella
        return;
      }

      FoodItem? eatenFood;
      for (var food in foods) {
        if (newHead == food.position) {
          eatenFood = food;
          break;
        }
      }
      
      if (eatenFood != null) {
        if (eatenFood.isBad && !bonusMode) { // Inmune en bonus
          gameOver();
          return;
        }
        
        score += bonusMode ? 20 : 10;
        foods.remove(eatenFood);
        
        // En bonus, generar nueva fruta inmediatamente
        if (bonusMode) {
          Random random = Random();
          Offset pos = _getRandomPosition();
          String type = fruitTypes[random.nextInt(fruitTypes.length)];
          foods.add(FoodItem(pos, type, false));
        } else {
          // Generar nueva fruta para mantener 5 en pantalla
          Random random = Random();
          Offset pos = _getRandomPosition();
          bool shouldBeBad = foods.where((f) => f.isBad).length < 2 && random.nextBool();
          
          if (shouldBeBad) {
            String type = badFruits[random.nextInt(badFruits.length)];
            foods.add(FoodItem(pos, type, true));
          } else {
            String type = fruitTypes[random.nextInt(fruitTypes.length)];
            foods.add(FoodItem(pos, type, false));
          }
        }
      } else {
        snake.removeLast();
      }
    });
  }

  void gameOver() {
    gameTimer?.cancel();
    gameRunning = false;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¡Juego Terminado!'),
        content: Text('Puntuación: $score'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              startGame();
            },
            child: Text('Jugar de Nuevo'),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyMenu() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.blue.shade700, Colors.purple.shade500],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Juego de Jacob\n🐍',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 50),
              Text(
                'Selecciona Dificultad:',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              SizedBox(height: 30),
              _buildDifficultyButton('FÁCIL (Atraviesa paredes)', 'facil', Colors.green),
              SizedBox(height: 20),
              _buildDifficultyButton('MEDIO (Atraviesa paredes)', 'medio', Colors.orange),
              SizedBox(height: 20),
              _buildDifficultyButton('DIFÍCIL (Sin atravesar)', 'dificil', Colors.red),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDifficultyButton(String text, String diff, Color color) {
    return ElevatedButton(
      onPressed: () => selectDifficulty(diff),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showMenu) {
      return _buildDifficultyMenu();
    }
    
    return Scaffold(
      body: GestureDetector(
        onPanUpdate: (details) {
          if (!gameRunning) return;
          
          double dx = details.delta.dx;
          double dy = details.delta.dy;
          
          if (dx.abs() > dy.abs()) {
            setState(() => direction = dx > 0 ? 'right' : 'left');
          } else {
            setState(() => direction = dy > 0 ? 'down' : 'up');
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: bonusMode 
                ? [Colors.orange.shade900, Colors.orange.shade700, Colors.yellow.shade500]
                : [Colors.green.shade900, Colors.green.shade700, Colors.green.shade500],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            image: _hasBackgroundImage() ? DecorationImage(
              image: AssetImage('assets/images/background.png'),
              fit: BoxFit.cover,
              opacity: 0.3, // Transparencia para ver el juego
            ) : null,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Juego de Jacob\nCreado por su papá Raul',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: Offset(2, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      if (bonusMode)
                        Column(
                          children: [
                            Text(
                              '✨ BONUS JACOB! ✨',
                              style: TextStyle(
                                color: Colors.yellow,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'INMUNE + VELOCIDAD (15s)',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    '🏆 Puntuación: $score',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: bonusMode ? Colors.yellow.withOpacity(0.6) : Colors.white.withOpacity(0.3), 
                        width: 3
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: CustomPaint(
                        painter: GamePainter(snake, foods, stars, enemies),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
                if (!gameRunning)
                  Column(
                    children: [
                      Container(
                        margin: EdgeInsets.all(16),
                        child: ElevatedButton(
                          onPressed: () => setState(() => showMenu = true),
                          child: Text(
                            '🎮 Cambiar Dificultad',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 8,
                          ),
                        ),
                      ),
                      Text(
                        'Desliza en la pantalla para mover',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                if (gameRunning)
                  Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildControlButton('up', Icons.keyboard_arrow_up),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildControlButton('left', Icons.keyboard_arrow_left),
                            SizedBox(width: 40),
                            _buildControlButton('right', Icons.keyboard_arrow_right),
                          ],
                        ),
                        SizedBox(height: 12),
                        _buildControlButton('down', Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(String dir, IconData icon) {
    return GestureDetector(
      onTap: () => setState(() => direction = dir),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 36),
      ),
    );
  }

  bool _hasBackgroundImage() {
    // Cambiar a true cuando coloques tu imagen en assets/images/background.png
    return false; // Cambiar a true para activar imagen de fondo
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    bonusTimer?.cancel();
    itemTimer?.cancel();
    enemyTimer?.cancel();
    super.dispose();
  }
}

class GamePainter extends CustomPainter {
  final List<Offset> snake;
  final List<FoodItem> foods;
  final List<StarItem> stars;
  final List<EnemySnake> enemies;
  
  GamePainter(this.snake, this.foods, this.stars, this.enemies);
  
  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 20;
    
    // Dibujar estrellas
    for (var star in stars) {
      final center = Offset(star.position.dx * cellSize + cellSize/2, star.position.dy * cellSize + cellSize/2);
      
      final starPaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          cellSize * 0.5,
          [Colors.yellow.shade300, Colors.orange.shade600],
          [0.0, 1.0],
        );
      
      _drawStar(canvas, center, cellSize * 0.4, starPaint);
    }
    
    // Dibujar frutas 3D
    for (var food in foods) {
      final center = Offset(food.position.dx * cellSize + cellSize/2, food.position.dy * cellSize + cellSize/2);
      
      if (food.isBad) {
        // Dibujar emoji de fruta mala
        final textPainter = TextPainter(
          text: TextSpan(
            text: food.type,
            style: TextStyle(
              fontSize: cellSize * 0.9,
              fontFamily: 'Noto Color Emoji',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        
        // Efecto de peligro (aura roja)
        final dangerPaint = Paint()
          ..color = Colors.red.withOpacity(0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
        
        canvas.drawCircle(center, cellSize * 0.5, dangerPaint);
        
        // Sombra del emoji
        final shadowPainter = TextPainter(
          text: TextSpan(
            text: food.type,
            style: TextStyle(
              fontSize: cellSize * 0.9,
              fontFamily: 'Noto Color Emoji',
              foreground: Paint()
                ..color = Colors.black.withOpacity(0.5)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        shadowPainter.layout();
        
        // Dibujar sombra
        shadowPainter.paint(
          canvas,
          Offset(
            center.dx - textPainter.width / 2 + 2,
            center.dy - textPainter.height / 2 + 2,
          ),
        );
        
        // Dibujar emoji principal
        textPainter.paint(
          canvas,
          Offset(
            center.dx - textPainter.width / 2,
            center.dy - textPainter.height / 2,
          ),
        );
      } else {
        // Dibujar emoji de fruta real
        final textPainter = TextPainter(
          text: TextSpan(
            text: food.type,
            style: TextStyle(
              fontSize: cellSize * 0.8,
              fontFamily: 'Noto Color Emoji',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        
        // Sombra del emoji
        final shadowPainter = TextPainter(
          text: TextSpan(
            text: food.type,
            style: TextStyle(
              fontSize: cellSize * 0.8,
              fontFamily: 'Noto Color Emoji',
              foreground: Paint()
                ..color = Colors.black.withOpacity(0.3)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        shadowPainter.layout();
        
        // Dibujar sombra
        shadowPainter.paint(
          canvas,
          Offset(
            center.dx - textPainter.width / 2 + 2,
            center.dy - textPainter.height / 2 + 2,
          ),
        );
        
        // Dibujar emoji principal
        textPainter.paint(
          canvas,
          Offset(
            center.dx - textPainter.width / 2,
            center.dy - textPainter.height / 2,
          ),
        );
        
        // Efecto de brillo encima
        final shinePaint = Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1);
        
        canvas.drawCircle(
          Offset(center.dx - cellSize*0.1, center.dy - cellSize*0.1),
          cellSize * 0.08,
          shinePaint,
        );
      }
    }
    
    // Dibujar serpientes enemigas
    for (var enemy in enemies) {
      for (int i = 0; i < enemy.body.length; i++) {
        final segment = enemy.body[i];
        final isHead = i == 0;
        final center = Offset(segment.dx * cellSize + cellSize/2, segment.dy * cellSize + cellSize/2);
        
        if (isHead) {
          // Cabeza enemiga (roja)
          final headPaint = Paint()
            ..shader = ui.Gradient.radial(
              center,
              cellSize * 0.45,
              [Colors.red.shade300, Colors.red.shade700],
              [0.0, 1.0],
            );
          
          canvas.drawCircle(center, cellSize * 0.45, headPaint);
          
          // Ojos rojos
          final eyePaint = Paint()..color = Colors.yellow;
          final pupilPaint = Paint()..color = Colors.red;
          
          canvas.drawCircle(
            Offset(center.dx - cellSize*0.15, center.dy - cellSize*0.1),
            cellSize * 0.08,
            eyePaint,
          );
          canvas.drawCircle(
            Offset(center.dx + cellSize*0.15, center.dy - cellSize*0.1),
            cellSize * 0.08,
            eyePaint,
          );
          
          canvas.drawCircle(
            Offset(center.dx - cellSize*0.15, center.dy - cellSize*0.1),
            cellSize * 0.04,
            pupilPaint,
          );
          canvas.drawCircle(
            Offset(center.dx + cellSize*0.15, center.dy - cellSize*0.1),
            cellSize * 0.04,
            pupilPaint,
          );
        } else {
          // Cuerpo enemigo (rojo oscuro)
          final bodyPaint = Paint()
            ..shader = ui.Gradient.radial(
              center,
              cellSize * 0.4,
              [Colors.red.shade400, Colors.red.shade800],
              [0.0, 1.0],
            );
          
          canvas.drawCircle(center, cellSize * 0.4, bodyPaint);
        }
      }
    }
    
    // Dibujar la culebra del jugador
    for (int i = 0; i < snake.length; i++) {
      final segment = snake[i];
      final isHead = i == 0;
      final center = Offset(segment.dx * cellSize + cellSize/2, segment.dy * cellSize + cellSize/2);
      
      if (isHead) {
        final headPaint = Paint()
          ..shader = ui.Gradient.radial(
            center,
            cellSize * 0.45,
            [Colors.green.shade300, Colors.green.shade600],
            [0.0, 1.0],
          );
        
        canvas.drawCircle(center, cellSize * 0.45, headPaint);
        
        // Ojos
        final eyePaint = Paint()..color = Colors.white;
        final pupilPaint = Paint()..color = Colors.black;
        
        canvas.drawCircle(
          Offset(center.dx - cellSize*0.15, center.dy - cellSize*0.1),
          cellSize * 0.08,
          eyePaint,
        );
        canvas.drawCircle(
          Offset(center.dx + cellSize*0.15, center.dy - cellSize*0.1),
          cellSize * 0.08,
          eyePaint,
        );
        
        canvas.drawCircle(
          Offset(center.dx - cellSize*0.15, center.dy - cellSize*0.1),
          cellSize * 0.04,
          pupilPaint,
        );
        canvas.drawCircle(
          Offset(center.dx + cellSize*0.15, center.dy - cellSize*0.1),
          cellSize * 0.04,
          pupilPaint,
        );
      } else {
        final bodyPaint = Paint()
          ..shader = ui.Gradient.radial(
            center,
            cellSize * 0.4,
            [Colors.lightGreen.shade300, Colors.green.shade500],
            [0.0, 1.0],
          );
        
        canvas.drawCircle(center, cellSize * 0.4, bodyPaint);
        
        final patternPaint = Paint()..color = Colors.green.shade700.withOpacity(0.3);
        canvas.drawCircle(center, cellSize * 0.2, patternPaint);
      }
    }
  }
  
  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    final double angle = (3.14159 * 2) / 5;
    
    for (int i = 0; i < 5; i++) {
      double x = center.dx + radius * cos(i * angle - 3.14159 / 2);
      double y = center.dy + radius * sin(i * angle - 3.14159 / 2);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      // Punto interno
      double innerX = center.dx + (radius * 0.4) * cos((i + 0.5) * angle - 3.14159 / 2);
      double innerY = center.dy + (radius * 0.4) * sin((i + 0.5) * angle - 3.14159 / 2);
      path.lineTo(innerX, innerY);
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}