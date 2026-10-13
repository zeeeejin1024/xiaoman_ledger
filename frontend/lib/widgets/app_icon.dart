import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppIconGenerator {
  static Future<void> generateAllSizes() async {
    final sizes = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };

    final dir = await getApplicationDocumentsDirectory();

    for (final entry in sizes.entries) {
      final size = entry.value;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      );

      _drawIcon(canvas, size);

      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final file = File('${dir.path}/${entry.key}_icon.png');
      await file.writeAsBytes(bytes);

      // 同时保存到 Android 项目目录
      final androidDir = Directory(
        'D:\\my_thoughts\\xiaojia_ledger\\frontend\\android\\app\\src\\main\\res\\${entry.key}',
      );
      if (await androidDir.exists()) {
        await file.copy('${androidDir.path}/ic_launcher.png');
      }
    }
  }

  static void _drawIcon(Canvas canvas, int size) {
    final double scale = size / 192.0;
    final double radius = 42 * scale;

    // 背景渐变
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size * 0.6, size * 0.6),
        [
          Color(0xFFE8C878), // premiumLight
          Color(0xFFB08830), // premiumDark
        ],
      );

    // 绘制圆角矩形背景
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        10 * scale,
        10 * scale,
        size - 20 * scale,
        size - 20 * scale,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // 绘制图标 - 组合钱包+储蓄
    final iconPaint = Paint()..color = Colors.white;
    final iconSize = 80 * scale;
    final iconOffset = Offset(
      (size - iconSize) / 2,
      (size - iconSize) / 2 - 10 * scale,
    );

    // 绘制钱包形状（简化版）
    final walletPath = Path()
      ..moveTo(iconOffset.dx, iconOffset.dy + 20 * scale)
      ..lineTo(iconOffset.dx + iconSize, iconOffset.dy + 20 * scale)
      ..lineTo(iconOffset.dx + iconSize, iconOffset.dy + iconSize * 0.7)
      ..quadraticBezierTo(
        iconOffset.dx + iconSize,
        iconOffset.dy + iconSize,
        iconOffset.dx + iconSize * 0.7,
        iconOffset.dy + iconSize,
      )
      ..lineTo(iconOffset.dx + iconSize * 0.3, iconOffset.dy + iconSize)
      ..quadraticBezierTo(
        iconOffset.dx,
        iconOffset.dy + iconSize,
        iconOffset.dx,
        iconOffset.dy + iconSize * 0.7,
      )
      ..lineTo(iconOffset.dx, iconOffset.dy + 20 * scale)
      ..close();

    canvas.drawPath(walletPath, iconPaint);

    // 绘制金币符号（+）
    final plusPaint = Paint()..color = Color(0xFFB08830);
    final plusSize = 24 * scale;
    final plusCenter = Offset(
      iconOffset.dx + iconSize * 0.5,
      iconOffset.dy + iconSize * 0.5 + 10 * scale,
    );

    canvas.drawLine(
      Offset(plusCenter.dx - plusSize / 2, plusCenter.dy),
      Offset(plusCenter.dx + plusSize / 2, plusCenter.dy),
      plusPaint..strokeWidth = 4 * scale,
    );
    canvas.drawLine(
      Offset(plusCenter.dx, plusCenter.dy - plusSize / 2),
      Offset(plusCenter.dx, plusCenter.dy + plusSize / 2),
      plusPaint,
    );

    // 绘制储蓄圆圈（底部）
    final circlePaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(size / 2, iconOffset.dy + iconSize + 15 * scale),
      12 * scale,
      circlePaint,
    );

    // 绘制美元符号（$）
    final dollarPaint = Paint()..color = Color(0xFFB08830);
    canvas.drawLine(
      Offset(size / 2, iconOffset.dy + iconSize + 8 * scale),
      Offset(size / 2, iconOffset.dy + iconSize + 22 * scale),
      dollarPaint..strokeWidth = 3 * scale,
    );
    canvas.drawCircle(
      Offset(size / 2, iconOffset.dy + iconSize + 12 * scale),
      4 * scale,
      dollarPaint..style = PaintingStyle.stroke,
    );
  }
}
