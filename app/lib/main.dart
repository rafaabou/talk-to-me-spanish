import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/main_shell.dart';
import 'screens/flashcard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/app_state.dart';
import 'services/progress_service.dart';

void main() {
  runApp(const EszeroApp());
}

class EszeroApp extends StatelessWidget {
  const EszeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Talk To Me Spanish By Mohamed Rafaa Tounekti',
            debugShowCheckedModeBanner: false,
            locale: Locale(state.lang),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
              Locale('pt'),
              Locale('es'),
            ],
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF008000),
                brightness: Brightness.light,
              ),
              fontFamilyFallback: const ['NotoNaskhArabic'],
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF00C853),
                brightness: Brightness.dark,
              ),
              fontFamilyFallback: const ['NotoNaskhArabic'],
              useMaterial3: true,
            ),
            themeMode: state.themeMode,
            builder: (context, child) {
              final baseScale = MediaQuery.of(context).textScaler.scale(1.0);
              return Directionality(
                textDirection:
                    state.isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(baseScale * state.zoom),
                  ),
                  child: _ZoomPinchHandler(
                    initialZoom: state.zoom,
                    onZoomEnd: (zoom) => state.setZoom(zoom),
                    child: child!,
                  ),
                ),
              );
            },
            home: const _AppRoot(),
          );
        },
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  static const MethodChannel _channel = MethodChannel(
    'com.rafaabou.eszero_hero/widget',
  );

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'navigateToFlashcards':
        if (mounted) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const FlashcardScreen()));
        }
        break;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return FutureBuilder<bool>(
          future: ProgressService.instance.getOnboardingDone(),
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.data == true) {
              return const MainShell();
            }
            return const OnboardingScreen();
          },
        );
      },
    );
  }
}

class _ZoomPinchHandler extends StatefulWidget {
  final double initialZoom;
  final ValueChanged<double> onZoomEnd;
  final Widget child;
  const _ZoomPinchHandler({
    required this.initialZoom,
    required this.onZoomEnd,
    required this.child,
  });

  @override
  State<_ZoomPinchHandler> createState() => _ZoomPinchHandlerState();
}

class _ZoomPinchHandlerState extends State<_ZoomPinchHandler> {
  final Map<int, Offset> _pointers = {};
  double _startZoom = 1.0;
  double _startDist = 0.0;
  double _liveZoom = 0.0;

  void _onPointerDown(PointerDownEvent e) {
    if (_pointers.length >= 2) return;
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      _startZoom = widget.initialZoom;
      _startDist = _distanceBetween();
      _liveZoom = _startZoom;
    }
  }

  double _distanceBetween() {
    final pts = _pointers.values.toList();
    return (pts[0] - pts[1]).distance;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2 && _startDist > 0) {
      final target = (_startZoom * (_distanceBetween() / _startDist)).clamp(
        0.8,
        2.0,
      );
      if ((target - _liveZoom).abs() > 0.001) {
        setState(() => _liveZoom = target);
      }
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2 && _liveZoom != 0.0) {
      final finalZoom = _liveZoom;
      setState(() => _liveZoom = 0.0);
      if ((finalZoom - _startZoom).abs() > 0.001) {
        widget.onZoomEnd(finalZoom);
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2 && _liveZoom != 0.0) {
      setState(() => _liveZoom = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = _liveZoom == 0.0 ? 1.0 : _liveZoom / _startZoom;
    Widget child = widget.child;
    if (scale != 1.0) {
      child = Transform.scale(scale: scale, child: child);
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: child,
    );
  }
}
