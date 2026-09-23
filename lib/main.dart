import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:page_transition/page_transition.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

// Fix for images not loading in release APK
// Release builds have stricter SSL certificate validation that can block
// valid HTTPS image URLs from Cloudinary and other CDNs
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

// Global navigator key for navigation from anywhere in the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cache SharedPreferences instance
  await StorageService.init();

  // Apply the SSL fix for release builds
  HttpOverrides.global = MyHttpOverrides();
  
  // Enable edge-to-edge mode to allow drawing behind the system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // Fully transparent to see our own black bar
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  
  runApp(const AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: MeetingApp(),
  ));
}

// Splash screen to check authentication
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Artificial delay removed for performance
    // await Future.delayed(const Duration(seconds: 1));

    final isAuthenticated = await AuthService.isAuthenticated();

    if (!mounted) return;

    if (isAuthenticated) {
      Navigator.of(context).pushReplacement(
        PageTransition(
          type: PageTransitionType.fade,
          duration: const Duration(milliseconds: 400),
          child: const MainNavigationScreen(),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageTransition(
          type: PageTransitionType.fade,
          duration: const Duration(milliseconds: 400),
          child: const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aadvi Fashion Institute',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5a189a), // Use primary purple for text on white
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: Color(0xFF5a189a),
            ),
          ],
        ),
      ),
    );
  }
}

class MeetingApp extends StatelessWidget {
  const MeetingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Aadvi Fashion Institute',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme, // optional, can keep
            themeMode: ThemeMode.light, // 🔴 FORCE LIGHT MODE
            debugShowCheckedModeBanner: false,
            navigatorKey:
                navigatorKey, // Global navigator key for navigation from anywhere
            // Global SafeArea wrapper for all screens
            // This ensures all screens respect system UI insets (status bar, notch, etc.)
            // Note: Individual screens can still override this if needed
            builder: (context, child) {
              return Column(
                children: [
                   // This container acts as the black status bar background
                   // it uses the system padding to perfectly match the status bar height
                  Container(
                    height: MediaQuery.of(context).padding.top,
                    color: Colors.black,
                  ),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true, // Remove top padding for children so they don't add more space
                      child: child!,
                    ),
                  ),
                ],
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
