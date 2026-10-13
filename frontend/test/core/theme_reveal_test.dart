import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/theme_reveal.dart';
import 'package:xiaojia_ledger/main.dart';

void main() {
  test(
    'interactive back gesture finishes reveal before any route is popped',
    () {
      var finished = false;
      final observer = ThemeRevealNavigationObserver()
        ..onNavigation = () => finished = true;
      observer.didStartUserGesture(
        MaterialPageRoute<void>(builder: (_) => const SizedBox()),
        null,
      );
      expect(finished, isTrue);
    },
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.apply(AppColorScheme.mistBlue);
  });
  tearDown(() => AppColors.apply(AppColorScheme.warmAmber));
  late BuildContext trigger;
  Widget app({
    ThemeRevealCapture? capture,
    ThemeRevealSave? save,
    bool reduce = false,
    Widget? probe,
    EdgeInsets insets = EdgeInsets.zero,
    double pixelRatio = 1,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reduce,
        viewPadding: insets,
        devicePixelRatio: pixelRatio,
      ),
      child: ThemeReveal(
        capture: capture,
        save: save,
        child: Builder(
          builder: (context) {
            trigger = context;
            return AppThemeBuilder(
              builder: (_, _) => ColoredBox(
                color: AppColors.bg,
                child: probe ?? const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    ),
  );
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
  }

  Future<ui.Image> image() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(AppColorScheme.mistBlue.bg, BlendMode.src);
    final picture = recorder.endRecording();
    final result = await picture.toImage(800, 600);
    picture.dispose();
    return result;
  }

  testWidgets(
    'capture is installed before applying theme, then cleared after reveal',
    (tester) async {
      final gate = Completer<ui.Image>();
      await tester.pumpWidget(app(capture: (_, _) => gate.future));
      final result = ThemeReveal.change(
        trigger,
        AppColorScheme.deepNight,
        const Offset(300, 400),
      );
      await frames(tester);
      expect(AppColors.scheme, AppColorScheme.mistBlue);
      final old = await tester.runAsync(image);
      gate.complete(old!);
      await frames(tester);
      expect(AppColors.scheme, AppColorScheme.deepNight);
      expect(find.byKey(const ValueKey('theme-reveal-mask')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await frames(tester);
      expect(find.byKey(const ValueKey('theme-reveal-mask')), findsNothing);
      expect(await result, isTrue);
      expect(old.debugDisposed, isTrue);
      expect((await SharedPreferences.getInstance()).getInt('color_scheme'), 5);
    },
  );
  testWidgets('reduced motion and same selection never capture', (
    tester,
  ) async {
    var captures = 0;
    await tester.pumpWidget(
      app(
        reduce: true,
        capture: (_, _) async {
          captures++;
          return image();
        },
      ),
    );
    expect(
      await ThemeReveal.change(
        trigger,
        AppColorScheme.deepNight,
        const Offset(200, 300),
      ),
      isTrue,
    );
    expect(AppColors.scheme, AppColorScheme.deepNight);
    await ThemeReveal.change(
      trigger,
      AppColorScheme.deepNight,
      const Offset(200, 300),
    );
    expect(captures, 0);
    expect(find.byKey(const ValueKey('theme-reveal-mask')), findsNothing);
  });
  testWidgets('capture failure still changes and saves theme', (tester) async {
    await tester.pumpWidget(
      app(capture: (_, _) async => throw StateError('capture unavailable')),
    );
    final result = ThemeReveal.change(
      trigger,
      AppColorScheme.deepNight,
      const Offset(200, 300),
    );
    await frames(tester);
    expect(await result, isTrue);
    expect(AppColors.scheme, AppColorScheme.deepNight);
    expect(find.byKey(const ValueKey('theme-reveal-mask')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'latest choice wins during outstanding capture and only it persists',
    (tester) async {
      final gate = Completer<ui.Image>();
      var count = 0;
      final saved = <int>[];
      await tester.pumpWidget(
        app(
          capture: (_, _) async {
            count++;
            if (count == 1) return gate.future;
            throw StateError('fallback');
          },
          save: (index) async {
            saved.add(index);
            return true;
          },
        ),
      );
      final first = ThemeReveal.change(
        trigger,
        AppColorScheme.deepNight,
        const Offset(200, 300),
      );
      await frames(tester);
      final last = ThemeReveal.change(
        trigger,
        AppColorScheme.roseGold,
        const Offset(300, 300),
      );
      gate.complete((await tester.runAsync(image))!);
      await frames(tester);
      expect(await first, isFalse);
      expect(await last, isTrue);
      expect(AppColors.scheme, AppColorScheme.roseGold);
      expect(saved, [3]);
      expect(find.byKey(const ValueKey('theme-reveal-mask')), findsNothing);
    },
  );
  testWidgets(
    'persistence failure does not revert visual theme or block later save',
    (tester) async {
      var attempt = 0;
      await tester.pumpWidget(
        app(
          reduce: true,
          save: (_) async {
            if (++attempt == 1) throw StateError('disk full');
            return true;
          },
        ),
      );
      expect(
        await ThemeReveal.change(
          trigger,
          AppColorScheme.deepNight,
          const Offset(200, 300),
        ),
        isFalse,
      );
      expect(AppColors.scheme, AppColorScheme.deepNight);
      expect(
        await ThemeReveal.change(
          trigger,
          AppColorScheme.mistBlue,
          const Offset(200, 300),
        ),
        isTrue,
      );
      expect(AppColors.scheme, AppColorScheme.mistBlue);
    },
  );
  testWidgets(
    'cancel while capturing commits latest target without installing stale image',
    (tester) async {
      final gate = Completer<ui.Image>();
      await tester.pumpWidget(app(capture: (_, _) => gate.future));
      final result = ThemeReveal.change(
        trigger,
        AppColorScheme.deepNight,
        const Offset(200, 300),
      );
      await frames(tester);
      ThemeReveal.finish(trigger);
      gate.complete((await tester.runAsync(image))!);
      await frames(tester);
      await result;
      expect(AppColors.scheme, AppColorScheme.deepNight);
      expect(find.byKey(const ValueKey('theme-reveal-mask')), findsNothing);
    },
  );
  testWidgets('real boundary snapshot reveals new pixels inside, old outside', (
    tester,
  ) async {
    final screen = GlobalKey();
    final gate = Completer<ui.Image>();
    RenderRepaintBoundary? capturedBoundary;
    double? capturedRatio;
    await tester.pumpWidget(
      RepaintBoundary(
        key: screen,
        child: app(
          capture: (boundary, ratio) {
            capturedBoundary = boundary;
            capturedRatio = ratio;
            return gate.future;
          },
          pixelRatio: 3,
        ),
      ),
    );
    final result = ThemeReveal.change(
      trigger,
      AppColorScheme.deepNight,
      const Offset(300, 400),
    );
    await frames(tester);
    expect(capturedRatio, lessThanOrEqualTo(2));
    final old = await tester.runAsync(
      () => capturedBoundary!.toImage(pixelRatio: 1),
    );
    final oldBytes = await tester.runAsync(
      () => old!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(
      oldBytes!.getUint8((800 + 1) * 4),
      AppColorScheme.mistBlue.bg.r * 255,
    );
    gate.complete(old!);
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 20));
    final composite = await tester.runAsync(() async {
      final boundary =
          screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final shot = await boundary.toImage(pixelRatio: 1);
      final bytes = await shot.toByteData(format: ui.ImageByteFormat.rawRgba);
      shot.dispose();
      return bytes!;
    });
    Color pixel(int x, int y) {
      final index = (y * 800 + x) * 4;
      return Color.fromARGB(
        composite!.getUint8(index + 3),
        composite.getUint8(index),
        composite.getUint8(index + 1),
        composite.getUint8(index + 2),
      );
    }

    expect(pixel(300, 400), AppColorScheme.deepNight.bg);
    expect(pixel(1, 1), AppColorScheme.mistBlue.bg);
    await tester.pump(const Duration(milliseconds: 400));
    await frames(tester);
    expect(await result, isTrue);
  });
  testWidgets('animation ticks do not rebuild the real stateful page', (
    tester,
  ) async {
    final gate = Completer<ui.Image>();
    var builds = 0;
    await tester.pumpWidget(
      app(
        capture: (_, _) => gate.future,
        probe: _StateProbe(onBuild: () => builds++),
      ),
    );
    final probeState = tester.state(find.byType(_StateProbe));
    final result = ThemeReveal.change(
      trigger,
      AppColorScheme.deepNight,
      const Offset(200, 300),
    );
    await frames(tester);
    gate.complete((await tester.runAsync(image))!);
    await frames(tester);
    final before = builds;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(builds, before);
    expect(tester.state(find.byType(_StateProbe)), same(probeState));
    await tester.pump(const Duration(milliseconds: 400));
    await frames(tester);
    await result;
  });
  testWidgets('system icon modes change by region, not by animation tick', (
    tester,
  ) async {
    final gate = Completer<ui.Image>();
    var notifications = 0;
    void changed() => notifications++;
    AppColors.systemUiOverride.addListener(changed);
    addTearDown(() => AppColors.systemUiOverride.removeListener(changed));
    await tester.pumpWidget(
      app(
        capture: (_, _) => gate.future,
        insets: const EdgeInsets.only(top: 24, bottom: 24),
      ),
    );
    final result = ThemeReveal.change(
      trigger,
      AppColorScheme.deepNight,
      const Offset(400, 550),
    );
    await frames(tester);
    gate.complete((await tester.runAsync(image))!);
    await frames(tester);
    expect(
      AppColors.systemUiOverlayStyle.statusBarIconBrightness,
      Brightness.dark,
    );
    var independent = false;
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      final style = AppColors.systemUiOverlayStyle;
      if (style.systemNavigationBarIconBrightness == Brightness.light &&
          style.statusBarIconBrightness == Brightness.dark) {
        independent = true;
      }
    }
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 40));
    await result;
    expect(independent, isTrue);
    expect(notifications, lessThanOrEqualTo(5));
    expect(AppColors.systemUiOverride.value, isNull);
  });
  testWidgets('background and resize finish animation and release image', (
    tester,
  ) async {
    final gate = Completer<ui.Image>();
    await tester.pumpWidget(app(capture: (_, _) => gate.future));
    final result = ThemeReveal.change(
      trigger,
      AppColorScheme.deepNight,
      const Offset(200, 300),
    );
    await frames(tester);
    final old = (await tester.runAsync(image))!;
    gate.complete(old);
    await frames(tester);
    expect(find.byKey(const ValueKey('theme-reveal-mask')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await frames(tester);
    expect(find.byKey(const ValueKey('theme-reveal-mask')), findsNothing);
    expect(AppColors.systemUiOverride.value, isNull);
    expect(old.debugDisposed, isTrue);
    await result;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  testWidgets('capture cannot leave a selection waiting indefinitely', (
    tester,
  ) async {
    final gate = Completer<ui.Image>();
    await tester.pumpWidget(app(capture: (_, _) => gate.future));
    final result = ThemeReveal.change(
      trigger,
      AppColorScheme.deepNight,
      const Offset(200, 300),
    );
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await frames(tester);
    expect(AppColors.scheme, AppColorScheme.deepNight);
    final old = (await tester.runAsync(image))!;
    gate.complete(old);
    await frames(tester);
    expect(old.debugDisposed, isTrue);
    expect(await result, isTrue);
    expect(find.byKey(const ValueKey('theme-reveal-mask')), findsNothing);
  });
  testWidgets('disposing an active host removes mask and does not throw', (
    tester,
  ) async {
    final gate = Completer<ui.Image>();
    await tester.pumpWidget(app(capture: (_, _) => gate.future));
    final result = ThemeReveal.change(
      trigger,
      AppColorScheme.deepNight,
      const Offset(200, 300),
    );
    await frames(tester);
    final old = (await tester.runAsync(image))!;
    gate.complete(old);
    await frames(tester);
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
    await result;
    expect(old.debugDisposed, isTrue);
    expect(tester.takeException(), isNull);
    expect(AppColors.systemUiOverride.value, isNull);
  });
  testWidgets(
    'root theme rebuild and navigation retain one page tree then clear reveal',
    (tester) async {
      final gate = Completer<ui.Image>();
      var builds = 0;
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: Listenable.merge([
            AppColors.notifier,
            AppColors.systemUiOverride,
          ]),
          builder: (_, _) => MaterialApp(
            theme: appTheme(),
            themeAnimationDuration: Duration.zero,
            navigatorObservers: [themeRevealNavigationObserver],
            builder: (_, child) => ThemeReveal(
              capture: (_, _) => gate.future,
              child: AppSystemUi(scheme: AppColors.scheme, child: child!),
            ),
            home: Builder(
              builder: (context) {
                trigger = context;
                return _StateProbe(onBuild: () => builds++);
              },
            ),
          ),
        ),
      );
      await frames(tester);
      final original = tester.state(find.byType(_StateProbe));
      final result = ThemeReveal.change(
        trigger,
        AppColorScheme.deepNight,
        const Offset(200, 300),
      );
      await frames(tester);
      final old = (await tester.runAsync(image))!;
      gate.complete(old);
      await frames(tester);
      expect(tester.state(find.byType(_StateProbe)), same(original));
      expect(find.byKey(const ValueKey('theme-reveal-mask')), findsOneWidget);
      final before = builds;
      await tester.pump(const Duration(milliseconds: 40));
      expect(builds, before);
      Navigator.of(trigger).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('next page')),
        ),
      );
      await tester.pumpAndSettle();
      await result;
      expect(find.byKey(const ValueKey('theme-reveal-mask')), findsNothing);
      expect(AppColors.systemUiOverride.value, isNull);
      expect(old.debugDisposed, isTrue);
      Navigator.of(trigger).pop();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(_StateProbe)), same(original));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rapid retarget during animation leaves only last theme and last saved index',
    (tester) async {
      final gate = Completer<ui.Image>();
      var count = 0;
      await tester.pumpWidget(
        app(
          capture: (_, _) async {
            if (++count == 1) return gate.future;
            throw StateError('fallback');
          },
        ),
      );
      final first = ThemeReveal.change(
        trigger,
        AppColorScheme.deepNight,
        const Offset(200, 300),
      );
      await frames(tester);
      final old = (await tester.runAsync(image))!;
      gate.complete(old);
      await frames(tester);
      await tester.pump(const Duration(milliseconds: 40));
      final second = ThemeReveal.change(
        trigger,
        AppColorScheme.roseGold,
        const Offset(300, 300),
      );
      final last = ThemeReveal.change(
        trigger,
        AppColorScheme.forestGreen,
        const Offset(400, 300),
      );
      await frames(tester);
      await first;
      expect(await second, isFalse);
      expect(await last, isTrue);
      expect(AppColors.scheme, AppColorScheme.forestGreen);
      expect((await SharedPreferences.getInstance()).getInt('color_scheme'), 1);
      expect(old.debugDisposed, isTrue);
      expect(find.byKey(const ValueKey('theme-reveal-mask')), findsNothing);
    },
  );
  testWidgets('resize clears capture instead of stretching old layout', (
    tester,
  ) async {
    final gate = Completer<ui.Image>();
    await tester.pumpWidget(app(capture: (_, _) => gate.future));
    final result = ThemeReveal.change(
      trigger,
      AppColorScheme.deepNight,
      const Offset(200, 300),
    );
    await frames(tester);
    gate.complete((await tester.runAsync(image))!);
    await frames(tester);
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(tester.view.resetPhysicalSize);
    await frames(tester);
    await result;
    expect(find.byKey(const ValueKey('theme-reveal-mask')), findsNothing);
    expect(AppColors.systemUiOverride.value, isNull);
  });
  testWidgets(
    'cancel during capture waits for its save instead of falsely reporting failure',
    (tester) async {
      final gate = Completer<ui.Image>();
      final disk = Completer<bool>();
      bool? completion;
      await tester.pumpWidget(
        app(capture: (_, _) => gate.future, save: (_) => disk.future),
      );
      final result = ThemeReveal.change(
        trigger,
        AppColorScheme.deepNight,
        const Offset(200, 300),
      );
      result.then((value) => completion = value);
      await frames(tester);
      ThemeReveal.finish(trigger);
      gate.complete((await tester.runAsync(image))!);
      await frames(tester);
      expect(completion, isNull);
      disk.complete(true);
      await frames(tester);
      expect(await result, isTrue);
      expect(completion, isTrue);
    },
  );
  testWidgets(
    'scroll position and input are retained, user scroll ends frozen snapshot',
    (tester) async {
      final gate = Completer<ui.Image>();
      final scroll = ScrollController(initialScrollOffset: 100);
      final input = TextEditingController(text: 'keep this record');
      addTearDown(scroll.dispose);
      addTearDown(input.dispose);
      await tester.pumpWidget(
        app(
          capture: (_, _) => gate.future,
          probe: Material(
            child: ListView(
              controller: scroll,
              children: [
                TextField(controller: input),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      );
      final result = ThemeReveal.change(
        trigger,
        AppColorScheme.deepNight,
        const Offset(200, 300),
      );
      await frames(tester);
      gate.complete((await tester.runAsync(image))!);
      await frames(tester);
      expect(scroll.offset, 100);
      expect(input.text, 'keep this record');
      await tester.drag(find.byType(ListView), const Offset(0, -50));
      await tester.pumpAndSettle();
      await result;
      expect(find.byKey(const ValueKey('theme-reveal-mask')), findsNothing);
      expect(scroll.offset, greaterThan(100));
      expect(input.text, 'keep this record');
    },
  );
}

class _StateProbe extends StatefulWidget {
  final VoidCallback onBuild;
  const _StateProbe({required this.onBuild});
  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return const SizedBox.expand();
  }
}
