import 'package:flutter/material.dart';

import '../../../../design_system/tokens/color_tokens.dart';

/// Emoji-like blob that represents the selected mood.
/// 调整了每个 mood 的渐变颜色，匹配你提供的示例（薄荷绿→浅绿→淡紫粉→桃橙→玫瑰红）
class EmojiBlob extends StatelessWidget {
  const EmojiBlob({
    super.key,
    required this.mood, // 1..5
    this.size = 72,
    this.tint, // 可选：如果你真的想外部统一上色，可传；默认忽略，使用内置渐变
  }) : assert(mood >= 1 && mood <= 5, 'mood must be between 1 and 5');

  final int mood;
  final double size;
  final Color? tint; // 保留以兼容，但默认不用

  @override
  Widget build(BuildContext context) {
    final diameter = size;
    final eyeWidth = diameter * 0.14;
    final eyeHeight = diameter * 0.18;
    final eyeTop = diameter * 0.38;
    final eyeOffset = diameter * 0.28;
    final isSmile = mood <= 2;
    final isFrown = mood >= 4;
    final mouthWidth = diameter * 0.3;
    final mouthHeight = (isSmile || isFrown)
        ? diameter * 0.12
        : diameter * 0.06;
    final mouthTop = isSmile
        ? diameter * 0.52
        : (isFrown ? diameter * 0.6 : diameter * 0.56);

    // 若提供 tint 且你想强制着色，可把下面的 BoxDecoration.gradient 换成
    //  gradient: _tintedGradient(tint!)
    final Gradient gradient = tint != null
        ? _tintedGradient(tint!)
        : _moodGradient(mood);

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: const [
          BoxShadow(
            color: Color(0x19111827),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: eyeTop,
            left: eyeOffset,
            child: _eye(eyeWidth, eyeHeight),
          ),
          Positioned(
            top: eyeTop,
            right: eyeOffset,
            child: _eye(eyeWidth, eyeHeight),
          ),
          Positioned(
            top: mouthTop,
            left: (diameter - mouthWidth) / 2,
            child: Container(
              width: mouthWidth,
              height: mouthHeight,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: isSmile
                    ? const BorderRadius.only(
                        bottomLeft: Radius.circular(999),
                        bottomRight: Radius.circular(999),
                      )
                    : isFrown
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(999),
                        topRight: Radius.circular(999),
                      )
                    : BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eye(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  /// ✅ 按截图定制的 5 组渐变
  RadialGradient _moodGradient(int value) {
    switch (value) {
      case 1: // Very happy — 薄荷绿
        return const RadialGradient(
          center: Alignment(-0.2, -0.2),
          radius: 1.05,
          colors: [
            Color(0xFFBFEFD8), // mint-200
            Color(0xFFA2E8C6), // mint-300
            Color(0xFF6DD3A3), // mint-500
            Color(0xFFAEEFD0), // edge soft
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        );
      case 2: // Happy — 浅青绿/浅绿
        return const RadialGradient(
          center: Alignment(0.15, -0.15),
          radius: 1.05,
          colors: [
            Color(0xFFE3F7DB), // light-lime-100
            Color(0xFFCFF0BD), // light-lime-200
            Color(0xFF8AD98F), // light-lime-400
            Color(0xFFE9F9E4), // edge soft
          ],
          stops: [0.0, 0.4, 0.72, 1.0],
        );
      case 3: // Neutral — 淡紫粉（带一点冷暖过渡）
        return const RadialGradient(
          center: Alignment(-0.05, -0.1),
          radius: 1.1,
          colors: [
            Color(0xFFEADCF8), // lilac-200
            Color(0xFFF6D6E4), // pink-200
            Color(0xFFE2C7F2), // lilac-300
            Color(0xFFF4D2DE), // edge soft
          ],
          stops: [0.0, 0.38, 0.68, 1.0],
        );
      case 4: // Unhappy — 桃杏橙
        return const RadialGradient(
          center: Alignment(0.15, -0.25),
          radius: 1.05,
          colors: [
            Color(0xFFFDE5CC), // peach-200
            Color(0xFFF9D2A8), // peach-300
            Color(0xFFF2B77A), // peach-400
            Color(0xFFFBE1C6), // edge soft
          ],
          stops: [0.0, 0.42, 0.72, 1.0],
        );
      default: // 5 Very unhappy — 玫瑰红
        return const RadialGradient(
          center: Alignment(-0.1, -0.2),
          radius: 1.05,
          colors: [
            Color(0xFFF8D1D1), // rose-200
            Color(0xFFF3B3B3), // rose-300
            Color(0xFFE57474), // rose-500
            Color(0xFFF2C0C8), // edge soft
          ],
          stops: [0.0, 0.4, 0.72, 1.0],
        );
    }
  }

  /// 备用：如果外部强制传入 tint，则用同色系明暗生成一套柔和渐变
  RadialGradient _tintedGradient(Color base) {
    // 通过不同透明度模拟高光与边缘加深
    return RadialGradient(
      center: const Alignment(0.0, -0.15),
      radius: 1.05,
      colors: [
        base.withOpacity(0.35),
        base.withOpacity(0.65),
        base, // 中心主色
        base.withOpacity(0.25),
      ],
      stops: const [0.0, 0.38, 0.72, 1.0],
    );
  }
}
