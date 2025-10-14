import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(CyberTapApp());
}

class CyberTapApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyber Tap 2077',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        fontFamily: 'Orbitron',
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

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  int score = 0;
  int timeLeft = 10;
  bool isPlaying = false;
  Timer? gameTimer;
  int gamesPlayed = 0;
  List<int> highScores = [];

  // Audio
  final AudioPlayer audioPlayer = AudioPlayer();

  // Animation controllers
  late AnimationController pulseController;
  late AnimationController shakeController;
  late AnimationController glowController;
  late AnimationController particleController;
  late Animation<double> pulseAnimation;
  late Animation<double> shakeAnimation;
  late Animation<double> glowAnimation;

  // Visual effects
  List<Particle> particles = [];
  double buttonScale = 1.0;
  Color currentGlowColor = Colors.purpleAccent;

  // Ads
  late BannerAd bannerAdTop;
  late BannerAd bannerAdBottom;
  InterstitialAd? interstitialAd;
  bool isBannerTopReady = false;
  bool isBannerBottomReady = false;

  @override
  void initState() {
    super.initState();
    _loadHighScores();
    _initAnimations();
    _loadBannerAds();
    _loadInterstitialAd();
  }

  void _initAnimations() {
    // Pulse animation for idle button
    pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: pulseController,
      curve: Curves.easeInOut,
    ));

    // Shake animation for taps
    shakeController = AnimationController(
      duration: Duration(milliseconds: 100),
      vsync: this,
    );
    shakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: shakeController,
      curve: Curves.elasticIn,
    ));

    // Glow animation
    glowController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    )..repeat(reverse: true);
    glowAnimation = Tween<double>(
      begin: 10,
      end: 30,
    ).animate(CurvedAnimation(
      parent: glowController,
      curve: Curves.easeInOut,
    ));

    // Particle animation
    particleController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  Future<void> _loadHighScores() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      highScores = (prefs.getStringList('highScores') ?? [])
          .map((e) => int.parse(e))
          .toList()
        ..sort((a, b) => b.compareTo(a));
      if (highScores.length > 10) {
        highScores = highScores.sublist(0, 10);
      }
    });
  }

  Future<void> _saveScore(int newScore) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    highScores.add(newScore);
    highScores.sort((a, b) => b.compareTo(a));
    if (highScores.length > 10) {
      highScores = highScores.sublist(0, 10);
    }
    await prefs.setStringList('highScores', highScores.map((e) => e.toString()).toList());
  }

  void _loadBannerAds() {
    bannerAdTop = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => isBannerTopReady = true),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    )..load();

    bannerAdBottom = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => isBannerBottomReady = true),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => interstitialAd = ad,
        onAdFailedToLoad: (error) => print('InterstitialAd failed: $error'),
      ),
    );
  }

  void _playTapSound() {
    // Play a synthetic beep sound (Flutter can generate simple sounds)
    HapticFeedback.lightImpact();
    // For real implementation, you'd load actual sound files
  }

  void _createParticleEffect(Offset tapPosition) {
    for (int i = 0; i < 10; i++) {
      particles.add(Particle(
        position: tapPosition,
        velocity: Offset(
          (Random().nextDouble() - 0.5) * 400,
          (Random().nextDouble() - 0.5) * 400,
        ),
        color: Colors.purpleAccent.withOpacity(0.8),
        size: Random().nextDouble() * 10 + 5,
      ));
    }
  }

  void startGame() {
    setState(() {
      score = 0;
      timeLeft = 10;
      isPlaying = true;
      particles.clear();
    });

    gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        timeLeft--;
        if (timeLeft <= 0) {
          endGame();
        }
      });
    });
  }

  void endGame() {
    gameTimer?.cancel();
    setState(() {
      isPlaying = false;
    });

    _saveScore(score);
    gamesPlayed++;

    if (gamesPlayed % 2 == 0 && interstitialAd != null) {
      interstitialAd!.show();
      _loadInterstitialAd();
    }

    _showScoreDialog();
  }

  void _showScoreDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.purpleAccent, width: 2),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade900.withOpacity(0.9),
                Colors.black87,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CYBER SCORE',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.purpleAccent,
                  letterSpacing: 3,
                ),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.purpleAccent),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$score TAPS',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'LEADERBOARD',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.purpleAccent,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 10),
              Container(
                height: 150,
                child: ListView.builder(
                  itemCount: highScores.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '#${index + 1}',
                            style: TextStyle(
                              color: index == 0 ? Colors.amber :
                                     index == 1 ? Colors.grey[300] :
                                     index == 2 ? Colors.orange[700] :
                                     Colors.purple[300],
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 20),
                          Text(
                            '${highScores[index]} taps',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'CONTINUE',
                  style: TextStyle(
                    fontSize: 18,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void onTap() {
    if (!isPlaying) {
      startGame();
    } else {
      setState(() {
        score++;
        buttonScale = 0.9;
        currentGlowColor = Color.lerp(
          Colors.purpleAccent,
          Colors.cyanAccent,
          Random().nextDouble(),
        )!;
      });

      _playTapSound();
      shakeController.forward().then((_) {
        shakeController.reset();
      });

      Future.delayed(Duration(milliseconds: 50), () {
        setState(() {
          buttonScale = 1.0;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0C29),
              Color(0xFF302B63),
              Color(0xFF24243E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Banner Ad
              if (isBannerTopReady)
                Container(
                  height: bannerAdTop.size.height.toDouble(),
                  child: AdWidget(ad: bannerAdTop),
                ),

              // Score Display
              Container(
                margin: EdgeInsets.all(20),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.purpleAccent, width: 2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purpleAccent.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.purpleAccent, Colors.cyanAccent],
                      ).createShader(bounds),
                      child: Text(
                        'SCORE: $score',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer, color: Colors.cyanAccent),
                        SizedBox(width: 10),
                        Text(
                          '$timeLeft',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: timeLeft <= 3 ? Colors.redAccent : Colors.cyanAccent,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Game Button Area
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          shakeAnimation.value * (Random().nextBool() ? 1 : -1),
                          shakeAnimation.value * (Random().nextBool() ? 1 : -1),
                        ),
                        child: AnimatedBuilder(
                          animation: pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: isPlaying ? buttonScale : pulseAnimation.value,
                              child: GestureDetector(
                                onTapDown: (_) => onTap(),
                                child: AnimatedBuilder(
                                  animation: glowAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      width: 250,
                                      height: 250,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            currentGlowColor,
                                            Colors.purpleAccent.withOpacity(0.5),
                                            Colors.transparent,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: currentGlowColor.withOpacity(0.8),
                                            blurRadius: glowAnimation.value,
                                            spreadRadius: glowAnimation.value / 2,
                                          ),
                                          BoxShadow(
                                            color: Colors.cyanAccent.withOpacity(0.3),
                                            blurRadius: glowAnimation.value * 2,
                                            spreadRadius: glowAnimation.value,
                                          ),
                                        ],
                                      ),
                                      child: Container(
                                        margin: EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: isPlaying ? [
                                              Colors.purpleAccent,
                                              Colors.deepPurple,
                                            ] : [
                                              Colors.purple.shade700,
                                              Colors.purple.shade900,
                                            ],
                                          ),
                                          border: Border.all(
                                            color: Colors.cyanAccent,
                                            width: 3,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            isPlaying ? 'TAP!' : 'START',
                                            style: TextStyle(
                                              fontSize: isPlaying ? 48 : 36,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 4,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.cyanAccent,
                                                  blurRadius: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Bottom Banner Ad
              if (isBannerBottomReady)
                Container(
                  height: bannerAdBottom.size.height.toDouble(),
                  child: AdWidget(ad: bannerAdBottom),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    pulseController.dispose();
    shakeController.dispose();
    glowController.dispose();
    particleController.dispose();
    bannerAdTop.dispose();
    bannerAdBottom.dispose();
    interstitialAd?.dispose();
    gameTimer?.cancel();
    super.dispose();
  }
}

class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double size;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
  });
}