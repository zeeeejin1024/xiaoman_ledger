class BrandMarkGeometry {
  const BrandMarkGeometry._();

  static const double center = 0.5;
  static const double radius = 0.34;
  static const double strokeWidth = 0.105;
  static const double startAngle = -1.3907963268;
  static const double gap = 0.72;
  static const double sweepAnimationDelta = 0.08;
  static const double markerProgress = 0.55;
  static const double markerProgressDelta = 0.22;
  static const double markerRadius = 0.055;
  static const double gapMarkerAngleOffset = 0.08;
  static const double gapMarkerRadius = 0.027;
  static const double tickOneProgress = 0.14;
  static const double tickTwoProgress = 0.31;
  static const double tickThreeProgress = 0.48;
  static const double tickInnerRadius = 0.42;
  static const double tickOuterRadius = 0.47;
  static const double tickStrokeWidth = 0.025;
  static const double launcherScale = 0.76;
  static const double outerRadius = radius + strokeWidth / 2;

  static const List<double> tickProgresses = [
    tickOneProgress,
    tickTwoProgress,
    tickThreeProgress,
  ];
}
