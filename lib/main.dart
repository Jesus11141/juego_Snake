import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      title: 'Juego UNIBE',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  static const int boardCols = 20;
  int boardRows = 20;
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
  final FocusNode _focusNode = FocusNode();
  
  Map<String, int> speeds = {
    'facil': 180,
    'medio': 130,
    'dificil': 80,
  };
  
  List<String> fruitTypes = ['🍎', '🍊', '🍌', '🍇', '🍓', '🥝'];
  List<String> badFruits = ['💀', '☠️', '🤢'];

  @override
  void initState() {
    super.initState();
    generateFood();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent && gameRunning) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp && direction != 'down')
        setState(() => direction = 'up');
      else if (event.logicalKey == LogicalKeyboardKey.arrowDown && direction != 'up')
        setState(() => direction = 'down');
      else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && direction != 'right')
        setState(() => direction = 'left');
      else if (event.logicalKey == LogicalKeyboardKey.arrowRight && direction != 'left')
        setState(() => direction = 'right');
    }
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
    Offset startPos = Offset(0, 0);
    
    int side = random.nextInt(4);
    switch (side) {
      case 0:
        startPos = Offset(random.nextInt(boardCols).toDouble(), 0);
        break;
      case 1:
        startPos = Offset(random.nextInt(boardCols).toDouble(), boardRows - 1);
        break;
      case 2:
        startPos = Offset(0, random.nextInt(boardRows).toDouble());
        break;
      case 3:
        startPos = Offset(boardCols - 1, random.nextInt(boardRows).toDouble());
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
      if (newHead.dx < 0 || newHead.dx >= boardCols || 
          newHead.dy < 0 || newHead.dy >= boardRows) {
        continue;
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
        random.nextInt(boardCols - 2).toDouble() + 1,
        random.nextInt(boardRows - 2).toDouble() + 1,
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
        if (newHead.dx < 0 || newHead.dx >= boardCols || 
            newHead.dy < 0 || newHead.dy >= boardRows) {
          gameOver();
          return;
        }
      } else {
        if (newHead.dx < 0) {
          newHead = Offset(boardCols - 1, newHead.dy);
        } else if (newHead.dx >= boardCols) {
          newHead = Offset(0, newHead.dy);
        } else if (newHead.dy < 0) {
          newHead = Offset(newHead.dx, boardRows - 1);
        } else if (newHead.dy >= boardRows) {
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
          image: DecorationImage(
            image: AssetImage('assets/images/unibe_logo.jpg'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
          gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.blue.shade700, Colors.red.shade600],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Juego UNIBE\n🐍',
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

  Widget _buildGameBoard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: bonusMode ? Colors.yellow.withOpacity(0.6) : Colors.white.withOpacity(0.3),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: CustomPaint(
          painter: GamePainter(snake, foods, stars, enemies, (rows) {
                          if (rows != boardRows) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => boardRows = rows);
                            });
                          }
                        }),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildControls(bool isWeb) {
    final btnSize = isWeb ? 70.0 : 80.0;
    final iconSize = isWeb ? 32.0 : 36.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isWeb)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('⌨️ Flechas o botones', style: TextStyle(color: Colors.white60, fontSize: 13)),
          ),
        _buildControlButton('up', Icons.keyboard_arrow_up, btnSize, iconSize),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton('left', Icons.keyboard_arrow_left, btnSize, iconSize),
            SizedBox(width: isWeb ? 20 : 40),
            _buildControlButton('right', Icons.keyboard_arrow_right, btnSize, iconSize),
          ],
        ),
        SizedBox(height: 8),
        _buildControlButton('down', Icons.keyboard_arrow_down, btnSize, iconSize),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Juego UNIBE\nUniversidad Iberoamericana del Ecuador',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black.withOpacity(0.5), offset: Offset(2, 2), blurRadius: 4)],
          ),
        ),
        if (bonusMode) ...[
          Text('✨ BONUS UNIBE! ✨', style: TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.bold)),
          Text('INMUNE + VELOCIDAD (15s)', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showMenu) return _buildDifficultyMenu();

    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 700;

    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKey,
        child: GestureDetector(
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
              image: DecorationImage(
                image: AssetImage('assets/images/unibe_logo.jpg'),
                fit: BoxFit.cover,
                opacity: 0.2,
              ),
              gradient: LinearGradient(
                colors: bonusMode
                    ? [Colors.orange.shade900, Colors.orange.shade700, Colors.yellow.shade500]
                    : [Colors.blue.shade900, Colors.blue.shade700, Colors.red.shade500],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: isWeb ? _buildWebLayout() : _buildMobileLayout(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(),
                SizedBox(height: 12),
                _buildScoreWidget(),
                SizedBox(height: 12),
                Expanded(child: _buildGameBoard()),
                if (!gameRunning) _buildChangeDifficultyButton(),
              ],
            ),
          ),
        ),
        Container(
          width: 220,
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (gameRunning) _buildControls(true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: _buildHeader(),
        ),
        _buildScoreWidget(),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: _buildGameBoard(),
          ),
        ),
        if (!gameRunning) _buildChangeDifficultyButton(),
        if (gameRunning)
          Padding(
            padding: EdgeInsets.all(16),
            child: _buildControls(false),
          ),
      ],
    );
  }

  Widget _buildScoreWidget() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        '🏆 Puntuación: $score',
        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildChangeDifficultyButton() {
    return Container(
      margin: EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () => setState(() => showMenu = true),
        child: Text('🎮 Cambiar Dificultad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade600,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 8,
        ),
      ),
    );
  }

  Widget _buildControlButton(String dir, IconData icon, double size, double iconSize) {
    return GestureDetector(
      onTap: () => setState(() => direction = dir),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: [
            BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    bonusTimer?.cancel();
    itemTimer?.cancel();
    enemyTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }
}

class GamePainter extends CustomPainter {
  final List<Offset> snake;
  final List<FoodItem> foods;
  final List<StarItem> stars;
  final List<EnemySnake> enemies;
  final Function(int) onRowsCalculated;
  
  GamePainter(this.snake, this.foods, this.stars, this.enemies, this.onRowsCalculated);
  
  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 20;
    final rows = (size.height / cellSize).ceil();
    onRowsCalculated(rows);
    
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