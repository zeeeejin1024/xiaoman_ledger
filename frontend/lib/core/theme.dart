import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' as m;

// ============================================================
// 动画 Token
// ============================================================
class AppAnimations {
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 300);
  static const staggerStepMs = 40;
}

// ============================================================
// 8dp 间距系统
// ============================================================
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

// ============================================================
// 6 套配色方案（每套独立 premium/highlight/gradient/bgGlow）
// ============================================================
class AppColorScheme {
  final String name;
  final Color bg,
      bgDeep,
      card,
      cardAlt,
      accent,
      accentDark,
      ink,
      ink2,
      gray,
      navBg;
  final Color success, danger, info;
  final Color premium, premiumLight, premiumDark, highlight, bgGlowColor;
  final List<Color>? heroGradient;
  final List<Color> buttonGradient;
  final Alignment? bgGlowPos;
  final Brightness brightness;

  const AppColorScheme({
    required this.name,
    required this.bg,
    required this.bgDeep,
    required this.card,
    required this.cardAlt,
    required this.accent,
    required this.accentDark,
    required this.ink,
    required this.ink2,
    required this.gray,
    required this.navBg,
    required this.success,
    required this.danger,
    required this.info,
    required this.premium,
    required this.premiumLight,
    required this.premiumDark,
    required this.highlight,
    required this.bgGlowColor,
    this.heroGradient,
    required this.buttonGradient,
    this.bgGlowPos,
    this.brightness = Brightness.light,
  });

  // ============================================================
  // 1. unfinishedRing「未满之圆」— 月白、石墨蓝与蔷薇莓
  // ============================================================
  static const warmAmber = AppColorScheme(
    name: '未满之圆',
    bg: Color(0xFFF4F4F0),
    bgDeep: Color(0xFFECEDEA),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF8F8F4),
    accent: Color(0xFF273640),
    accentDark: Color(0xFF1E2B33),
    ink: Color(0xFF24343D),
    ink2: Color(0xFF53636A),
    gray: Color(0xFF7C898E),
    navBg: Color(0xFFFAFAF6),
    success: Color(0xFF5F8B76),
    danger: Color(0xFFB45B6C),
    info: Color(0xFF587A86),
    premium: Color(0xFF273640),
    premiumLight: Color(0xFF8FA8AF),
    premiumDark: Color(0xFF1E2B33),
    highlight: Color(0xFFB45B6C),
    bgGlowColor: Color(0xFFD2DEE0),
    heroGradient: [Color(0xFF344C57), Color(0xFF273640)],
    buttonGradient: [Color(0xFFC87382), Color(0xFFB45B6C)],
    bgGlowPos: Alignment(-0.6, -0.5),
  );

  // ============================================================
  // 2. forestGreen「森林绿」— 翡翠绿，零金色
  // ============================================================
  static const forestGreen = AppColorScheme(
    name: '森林绿',
    bg: Color(0xFFF4F7F3),
    bgDeep: Color(0xFFECF2EA),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF8FAF7),
    accent: Color(0xFF5B9A7A),
    accentDark: Color(0xFF4A8A6A),
    ink: Color(0xFF1A2A1A),
    ink2: Color(0xFF405840),
    gray: Color(0xFF809880),
    navBg: Color(0xFFFFFFFF),
    success: Color(0xFF4A8A68),
    danger: Color(0xFFE07050),
    info: Color(0xFF7BA8C0),
    premium: Color(0xFF3D7A5A),
    premiumLight: Color(0xFF6BAA84),
    premiumDark: Color(0xFF28553C),
    highlight: Color(0xFFD4884A),
    bgGlowColor: Color(0xFFA8D8C0),
    heroGradient: [Color(0xFFD4E8D0), Color(0xFFA8CCA0)],
    buttonGradient: [Color(0xFF6AAA80), Color(0xFF4A8A68)],
    bgGlowPos: Alignment(0.7, -0.3),
  );

  // ============================================================
  // 3. mistBlue「雾蓝」— 蓝宝石，零金色
  // ============================================================
  static const mistBlue = AppColorScheme(
    name: '雾蓝',
    bg: Color(0xFFF5F7FA),
    bgDeep: Color(0xFFEDF1F6),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF8FAFC),
    accent: Color(0xFF7098B8),
    accentDark: Color(0xFF5A80A0),
    ink: Color(0xFF1A2430),
    ink2: Color(0xFF405060),
    gray: Color(0xFF8090A0),
    navBg: Color(0xFFFFFFFF),
    success: Color(0xFF5B9A7A),
    danger: Color(0xFFE8785C),
    info: Color(0xFF5A98B8),
    premium: Color(0xFF5090B0),
    premiumLight: Color(0xFF78B8D0),
    premiumDark: Color(0xFF387098),
    highlight: Color(0xFFE08850),
    bgGlowColor: Color(0xFFB0D0E8),
    heroGradient: [Color(0xFFD8E8F4), Color(0xFFA8C8E0)],
    buttonGradient: [Color(0xFF7AA8C8), Color(0xFF5A88A8)],
    bgGlowPos: Alignment(-0.6, -0.5),
  );

  // ============================================================
  // 4. roseGold「玫瑰金」— 玫瑰铜，零金色
  // ============================================================
  static const roseGold = AppColorScheme(
    name: '玫瑰金',
    bg: Color(0xFFFBF6F5),
    bgDeep: Color(0xFFF7EFEC),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFFCF8F7),
    accent: Color(0xFFD48878),
    accentDark: Color(0xFFC07060),
    ink: Color(0xFF2A1A18),
    ink2: Color(0xFF584040),
    gray: Color(0xFF988880),
    navBg: Color(0xFFFFFFFF),
    success: Color(0xFF7AAA80),
    danger: Color(0xFFD87868),
    info: Color(0xFFA0B8D0),
    premium: Color(0xFFC87068),
    premiumLight: Color(0xFFE09890),
    premiumDark: Color(0xFFA05850),
    highlight: Color(0xFFD49050),
    bgGlowColor: Color(0xFFF0D0C8),
    heroGradient: [Color(0xFFF3D8D0), Color(0xFFE0B8AC)],
    buttonGradient: [Color(0xFFD89888), Color(0xFFC07868)],
    bgGlowPos: Alignment(0.5, -0.4),
  );

  // ============================================================
  // 5. darkInk「深墨」— 炭黑蓝灰，雾青结构色
  // ============================================================
  static const darkInk = AppColorScheme(
    name: '深墨',
    bg: Color(0xFF1A1D2A),
    bgDeep: Color(0xFF141720),
    card: Color(0xFF242736),
    cardAlt: Color(0xFF282B3A),
    accent: Color(0xFF8FA8AF),
    accentDark: Color(0xFF6F8E97),
    ink: Color(0xFFFFFFFF),
    ink2: Color(0xFFC8C5CD),
    gray: Color(0xFF98959E),
    navBg: Color(0xFF1E2030),
    success: Color(0xFF68A880),
    danger: Color(0xFFD47B8B),
    info: Color(0xFF86AAB2),
    premium: Color(0xFF587A86),
    premiumLight: Color(0xFF9BBBC1),
    premiumDark: Color(0xFF3E5F69),
    highlight: Color(0xFFD47B8B),
    bgGlowColor: Color(0xFF3A3850),
    heroGradient: [Color(0xFF282C42), Color(0xFF181B2A)],
    buttonGradient: [Color(0xFFD47B8B), Color(0xFFB45B6C)],
    bgGlowPos: null, // dark uses center ambient
    brightness: Brightness.dark,
  );

  // ============================================================
  // 6. deepNight「极夜」— 纯黑极简，雾青与蔷薇莓
  // ============================================================
  static const deepNight = AppColorScheme(
    name: '极夜',
    bg: Color(0xFF0D0F16),
    bgDeep: Color(0xFF080A10),
    card: Color(0xFF161822),
    cardAlt: Color(0xFF1A1C26),
    accent: Color(0xFF86AAB2),
    accentDark: Color(0xFF668E98),
    ink: Color(0xFFFFFFFF),
    ink2: Color(0xFFD0CDD8),
    gray: Color(0xFFA09CA8),
    navBg: Color(0xFF10121A),
    success: Color(0xFF78B090),
    danger: Color(0xFFE18A9A),
    info: Color(0xFF91B8C0),
    premium: Color(0xFF587A86),
    premiumLight: Color(0xFFA6C4C9),
    premiumDark: Color(0xFF3E5F69),
    highlight: Color(0xFFE18A9A),
    bgGlowColor: Color(0xFF2A2838),
    heroGradient: [Color(0xFF181A26), Color(0xFF0B0D14)],
    buttonGradient: [Color(0xFFE18A9A), Color(0xFFB45B6C)],
    bgGlowPos: null, // dark uses center ambient
    brightness: Brightness.dark,
  );

  static const List<AppColorScheme> all = [
    warmAmber,
    forestGreen,
    mistBlue,
    roseGold,
    darkInk,
    deepNight,
  ];
}

// ============================================================
// 全局持有 + 向后兼容 getter
// ============================================================
class AppColors {
  static AppColorScheme _s = AppColorScheme.warmAmber;
  static final ValueNotifier<AppColorScheme> notifier =
      ValueNotifier<AppColorScheme>(_s);
  static AppColorScheme get scheme => _s;
  static int get schemeIndex => AppColorScheme.all.indexOf(_s);
  static final systemUiOverride = ValueNotifier<SystemUiOverlayStyle?>(null);
  static void apply(AppColorScheme s) {
    if (identical(_s, s)) return;
    _s = s;
    notifier.value = s;
  }

  static SystemUiOverlayStyle get systemUiOverlayStyle =>
      systemUiOverride.value ?? overlayForScheme(_s);

  static SystemUiOverlayStyle overlayForScheme(AppColorScheme scheme) =>
      SystemUiOverlayStyle(
        statusBarColor: scheme.bg,
        statusBarIconBrightness: scheme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: scheme.brightness,
        systemNavigationBarColor: scheme.navBg,
        systemNavigationBarIconBrightness: scheme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: scheme.ink.withAlpha(18),
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      );

  // --- scheme tokens ---
  static Color get bg => _s.bg;
  static Color get bgDeep => _s.bgDeep;
  static Color get card => _s.card;
  static Color get cardAlt => _s.cardAlt;
  static Color get accent => _s.accent;
  static Color get accentDark => _s.accentDark;
  static Color get ink => _s.ink;
  static Color get ink2 => _s.ink2;
  static Color get gray => _s.gray;
  static Color get navBg => _s.navBg;
  static Color get success => _s.success;
  static Color get danger => _s.danger;
  static Color get info => _s.info;
  static Brightness get brightness => _s.brightness;
  static bool get isDark => brightness == Brightness.dark;

  // --- legacy aliases ---
  static Color get bgEnd => bgDeep;
  static Color get inkSecondary => ink2;
  static Color get inkSoft => ink2;
  static Color get warmGray => gray;
  static Color get lightGray => isDark
      ? Color.lerp(_s.card, Colors.white, 0.06)!
      : Color.lerp(_s.ink, Colors.white, 0.14)!;
  static Color get divider => _s.ink.withAlpha(18);
  static Color get bgSheet => Color.lerp(_s.bg, _s.cardAlt, 0.5)!;

  // --- premium colors (new, scheme-aware) ---
  static Color get premium => _s.premium;
  static Color get premiumLight => _s.premiumLight;
  static Color get premiumDark => _s.premiumDark;

  // --- backward compat: gold aliases → premium (all existing code works unchanged) ---
  static Color get gold => premium;
  static Color get goldLight => premiumLight;
  static Color get goldDark => premiumDark;

  // --- highlight (new, scheme-aware) ---
  static Color get highlight => _s.highlight;
  // backward compat
  static Color get amber => highlight;
  static Color get yellow => highlight;
  static Color get sageLight => Color.lerp(_s.success, Colors.white, 0.35)!;

  // --- functional shortcuts ---
  static Color get sage => success;
  static Color get green => success;
  static Color get coralRed => danger;
  static Color get red => danger;
  static Color get mistBlue => info;
  static Color get blue => info;
  static Color get coral => danger;

  // --- gradients ---
  static List<Color>? get heroGradient => _s.heroGradient;
  static List<Color> get buttonGradient => _s.buttonGradient;
  static List<Color> get cardAccentGradient => [
    card,
    Color.lerp(card, premiumLight, 0.06)!,
  ];
  static List<Color> get cardGoldTint => cardAccentGradient; // backward compat
  static List<Color> get cardSageTint => [
    card,
    Color.lerp(card, success, 0.06)!,
  ];

  // --- bg glow ---
  static Color get bgGlowColor => _s.bgGlowColor;

  // --- chart palette (hue-rotated from accent) ---
  static Color chartColor(int index) {
    final hueShifts = const [0, 45, 120, 180, 240, 300];
    final hsl = HSLColor.fromColor(_s.accent);
    return hsl
        .withHue((hsl.hue + hueShifts[index % 6]) % 360)
        .withSaturation(0.55)
        .withLightness(isDark ? 0.60 : 0.48)
        .toColor();
  }

  static List<Color> get chartPalette => List.generate(6, chartColor);
}

class AppSystemUiBridge {
  static const _channel = MethodChannel('xiaojia/system_ui');

  static Future<void> apply(
    AppColorScheme scheme, {
    SystemUiOverlayStyle? overlay,
  }) => _channel.invokeMethod('apply', <String, dynamic>{
    'isDark': overlay == null
        ? scheme.brightness == Brightness.dark
        : overlay.statusBarIconBrightness == Brightness.light,
    if (overlay != null)
      'navigationIsDark':
          overlay.systemNavigationBarIconBrightness == Brightness.light,
  });
}

class AppThemeBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, AppColorScheme scheme) builder;

  const AppThemeBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppColorScheme>(
    valueListenable: AppColors.notifier,
    builder: (context, scheme, _) => builder(context, scheme),
  );
}

class AppThemedPage extends StatelessWidget {
  final Widget Function(BuildContext context, AppColorScheme scheme) builder;

  const AppThemedPage({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => AppThemeBuilder(builder: builder);
}

// ============================================================
// 按压缩放组件
// ============================================================
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleTo;
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleTo = 0.96,
  });
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _anim = Tween(
      begin: 1.0,
      end: widget.scaleTo,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, c) => Transform.scale(scale: _anim.value, child: c),
        child: widget.child,
      ),
    );
  }
}

// ============================================================
// 交错列表
// ============================================================
class StaggeredList extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final Duration baseDelay;
  const StaggeredList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.baseDelay = const Duration(milliseconds: 40),
  });
  @override
  State<StaggeredList> createState() => _StaggeredListState();
}

class _StaggeredListState extends State<StaggeredList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 250 + widget.itemCount * widget.baseDelay.inMilliseconds,
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Column(
        children: List.generate(widget.itemCount, (i) {
          final delay =
              i *
              widget.baseDelay.inMilliseconds /
              _ctrl.duration!.inMilliseconds;
          final anim = CurvedAnimation(
            parent: _ctrl,
            curve: Interval(delay, delay + 0.4, curve: Curves.easeOutBack),
          );
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(anim),
              child: widget.itemBuilder(context, i),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================
// 组件
// ============================================================
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final List<Color>? gradient;
  final List<BoxShadow>? shadows;
  final bool goldBorder;
  final VoidCallback? onTap;
  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 18,
    this.gradient,
    this.shadows,
    this.goldBorder = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final defaultShadows = [
      BoxShadow(
        color: AppColors.premium.withAlpha(isDark ? 20 : 8),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: AppColors.ink.withAlpha(isDark ? 25 : 4),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ];
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding ?? EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? AppColors.card.withAlpha(244) : AppColors.card,
          gradient: gradient != null
              ? LinearGradient(
                  colors: gradient!,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: goldBorder
                ? AppColors.premiumLight.withAlpha(180)
                : AppColors.premiumLight.withAlpha(isDark ? 20 : 12),
          ),
          boxShadow: shadows ?? defaultShadows,
        ),
        child: child,
      ),
    );
    if (onTap != null) return PressScale(onTap: onTap, child: card);
    return card;
  }
}

class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const GoldButton({super.key, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) => PressScale(
    onTap: onTap,
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.buttonGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.highlight.withAlpha(AppColors.isDark ? 160 : 80),
            blurRadius: AppColors.isDark ? 28 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ),
    ),
  );
}

class PremiumBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;
  const PremiumBar({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
  });
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.info;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: AppAnimations.normal,
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: c.withAlpha(35),
          valueColor: AlwaysStoppedAnimation(c),
        ),
      ),
    );
  }
}

class NavIcon extends StatelessWidget {
  final int index;
  final bool active;
  const NavIcon({super.key, required this.index, this.active = false});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppAnimations.normal,
    curve: Curves.easeOutCubic,
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: active
        ? BoxDecoration(
            color: AppColors.highlight.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          )
        : null,
    child: Icon(
      _icons[index],
      size: 24,
      color: active ? AppColors.info : AppColors.gray,
    ),
  );
  static const _icons = [
    Icons.home_rounded,
    Icons.bar_chart_rounded,
    Icons.savings_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.receipt_long_rounded,
    Icons.person_rounded,
  ];
}

typedef FrostedCard = PremiumCard;
typedef GlassCard = PremiumCard;
typedef AppCard = PremiumCard;
typedef GradientButton = GoldButton;
typedef PremiumProgressBar = PremiumBar;
typedef GlassBackground = PremiumBackground;
typedef GradientScaffold = PremiumBackground;

// ============================================================
// 高级背景（径向柔光叠加）
// ============================================================
class PremiumBackground extends StatelessWidget {
  final Widget child;
  const PremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bg, AppColors.bgDeep],
        ),
      ),
      child: child,
    );
  }
}

class HeroAmount extends StatelessWidget {
  final double amount;
  final String prefix;
  final double size;
  final Color? color;
  const HeroAmount({
    super.key,
    required this.amount,
    this.prefix = '¥',
    this.size = 30,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Text(
    '$prefix${amount.toStringAsFixed(2)}',
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color ?? AppColors.ink,
      letterSpacing: -0.5,
      height: 1.1,
    ),
  );
}

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: m.ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: AppColors.brightness,
  ),
  scaffoldBackgroundColor: AppColors.bg,
  fontFamily: 'sans-serif',
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: AppColors.ink,
    scrolledUnderElevation: 0,
    systemOverlayStyle: AppColors.systemUiOverlayStyle,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.navBg,
    selectedItemColor: AppColors.info,
    unselectedItemColor: AppColors.gray,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.navBg,
    indicatorColor: AppColors.info.withAlpha(24),
    elevation: 0,
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: states.contains(WidgetState.selected)
            ? AppColors.info
            : AppColors.gray,
      ),
    ),
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        color: states.contains(WidgetState.selected)
            ? AppColors.info
            : AppColors.gray,
        size: 22,
      ),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.highlight,
      foregroundColor: Colors.white,
      elevation: 0,
      shadowColor: AppColors.highlight.withAlpha(80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      minimumSize: const Size(double.infinity, 52),
      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.isDark
        ? AppColors.card.withAlpha(220)
        : Colors.white.withAlpha(200),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: AppColors.premiumLight.withAlpha(AppColors.isDark ? 20 : 25),
      ),
    ),
    elevation: 24,
    shadowColor: AppColors.premium.withAlpha(25),
  ),
  dividerTheme: DividerThemeData(
    color: AppColors.divider,
    thickness: 0.5,
    space: 0,
  ),
  textTheme: TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      height: 1.15,
      letterSpacing: -0.5,
    ),
    headlineLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      height: 1.2,
      letterSpacing: -0.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.3,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.ink2,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.gray,
      height: 1.4,
    ),
  ),
);
