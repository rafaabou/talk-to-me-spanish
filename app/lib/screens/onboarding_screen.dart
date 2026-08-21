import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import '../services/app_state.dart';
import '../services/progress_service.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = _Translations.of(context);
    final pages = [
      _OnboardingPage(
        icon: Icons.menu_book,
        title: t.welcomeTitle,
        body: t.welcomeBody,
      ),
      _OnboardingPage(
        icon: Icons.school,
        title: t.lessonsTitle,
        body: t.lessonsBody,
      ),
      _OnboardingPage(
        icon: Icons.style,
        title: t.flashcardsTitle,
        body: t.flashcardsBody,
      ),
      _OnboardingPage(
        icon: Icons.local_fire_department,
        title: t.streakTitle,
        body: t.streakBody,
      ),
    ];

    return AppSelectionArea(
      child: Scaffold(body: SafeArea(child: _OnboardingPager(pages: pages))),
    );
  }
}

class _OnboardingPager extends StatefulWidget {
  final List<_OnboardingPage> pages;
  const _OnboardingPager({required this.pages});

  @override
  State<_OnboardingPager> createState() => _OnboardingPagerState();
}

class _OnboardingPagerState extends State<_OnboardingPager> {
  final PageController _controller = PageController();
  int _index = 0;

  void _next() {
    if (_index < widget.pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await ProgressService.instance.setOnboardingDone();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => widget.pages[i],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_index > 0)
                TextButton(
                  onPressed:
                      () => _controller.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                  child: Text(_Translations.of(context).back),
                )
              else
                const SizedBox(width: 80),
              Row(
                children: List.generate(
                  widget.pages.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          i == _index
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _next,
                icon: Icon(
                  _index == widget.pages.length - 1
                      ? Icons.check
                      : Icons.arrow_forward,
                ),
                label: Text(
                  _index == widget.pages.length - 1
                      ? _Translations.of(context).start
                      : _Translations.of(context).next,
                ),
              ),
            ],
          ),
        ),
        const CreditFooter(),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Translations {
  final String lang;
  _Translations(this.lang);

  static _Translations of(BuildContext context) =>
      _Translations(context.watch<AppState>().lang);

  String get welcomeTitle =>
      lang == 'ar'
          ? 'مرحباً بك في الإسبانية'
          : lang == 'es'
          ? '¡Bienvenido al Español!'
          : 'Welcome to Spanish';

  String get welcomeBody =>
      lang == 'ar'
          ? 'تعلم الإسبانية خطوة بخطوة مع دروس تفاعلية وبطاقات تعليمية'
          : lang == 'es'
          ? 'Aprende español paso a paso con lecciones interactivas y tarjetas de estudio'
          : 'Learn Spanish step by step with interactive lessons and flashcards';

  String get lessonsTitle =>
      lang == 'ar'
          ? 'دروس منظمة'
          : lang == 'es'
          ? 'Lecciones Estructuradas'
          : 'Structured Lessons';

  String get lessonsBody =>
      lang == 'ar'
          ? '72 درساً من المبتدئ إلى المتقدم مع مفردات وقواعد ومحادثات وتمارين'
          : lang == 'es'
          ? '72 lecciones de principiante a avanzado con vocabulario, gramática, diálogos y ejercicios'
          : '72 lessons from beginner to advanced with vocabulary, grammar, dialogues, and exercises';

  String get flashcardsTitle =>
      lang == 'ar'
          ? 'بطاقات تعليمية ذكية'
          : lang == 'es'
          ? 'Tarjetas Inteligentes'
          : 'Smart Flashcards';

  String get flashcardsBody =>
      lang == 'ar'
          ? 'تكرار متباعد (FSRS) يتكيف مع تقدمك — حدد التكرار 1× / 3× / 7× / 10×'
          : lang == 'es'
          ? 'Repetición espaciada (FSRS) que se adapta a tu progreso — define repetición 1× / 3× / 7× / 10×'
          : 'Spaced repetition (FSRS) that adapts to your progress — set repeat 1× / 3× / 7× / 10×';

  String get streakTitle =>
      lang == 'ar'
          ? 'حافظ على تسلسل الأيام'
          : lang == 'es'
          ? 'Mantén la Racha'
          : 'Keep Your Streak';

  String get streakBody =>
      lang == 'ar'
          ? 'ادرس يومياً لترى تقويم الحرارة والتقدم — يعمل دون اتصال بالإنترنت تماماً'
          : lang == 'es'
          ? 'Estudia a diario para ver el calendario de calor y progreso — funciona totalmente sin conexión'
          : 'Study daily to see the heatmap calendar and progress — works completely offline';

  String get next =>
      lang == 'ar'
          ? 'التالي'
          : lang == 'es'
          ? 'Siguiente'
          : 'Next';
  String get back =>
      lang == 'ar'
          ? 'السابق'
          : lang == 'es'
          ? 'Atrás'
          : 'Back';
  String get start =>
      lang == 'ar'
          ? 'ابدأ'
          : lang == 'es'
          ? 'Empezar'
          : 'Start';
}
