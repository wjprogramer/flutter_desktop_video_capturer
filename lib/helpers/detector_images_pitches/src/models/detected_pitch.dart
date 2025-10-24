class DetectedPitch {
  DetectedPitch({
    required this.xCenter,
    required this.x0,
    required this.x1,
    required this.yUnits,
    required this.yNorm,
    required this.w,
    required this.h,
  });

  /// 0..1
  final double xCenter;

  /// 0..1
  final double x0;

  /// 0..1
  final double x1;

  /// 以灰線間距為 1，由下往上；可為負
  final double yUnits;

  /// 投影到 0..1（夾在 0..1）
  final double yNorm;

  final double w;

  final double h;

  Map<String, dynamic> toJson() => {
    'x_center': xCenter,
    'x0': x0,
    'x1': x1,
    'y_line_units': yUnits,
    'y_norm_0_1': yNorm,
    'w': w,
    'h': h,
  };
}