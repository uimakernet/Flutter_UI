import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedWaveProgress extends StatefulWidget {
  final int value;
  final Duration progressAnimatedDuration;
  final Color circleProgressColor;
  final Color circleProgressBGColor;
  final Color waveColor;
  final Color lightWaveColor;
  final Color progressTextColor;
  final double circleProgressWidth;
  final double waveHeight;
  final Text hintText;
  final double progressTextFontSize;
  final Duration waveAnimationDuration;
  final Duration lightWaveAnimationDuration;
  final int maxValue;
  final int minValue;

  AnimatedWaveProgress({
    @required this.value,
    @required this.progressAnimatedDuration,
    @required this.circleProgressColor,
    @required this.circleProgressBGColor,
    @required this.waveColor,
    @required this.lightWaveColor,
    this.minValue = 0,
    this.maxValue = 100,
    this.hintText,
    this.progressTextColor = Colors.blueGrey,
    this.progressTextFontSize = 20,
    this.circleProgressWidth = 5,
    this.waveHeight = 50,
    this.waveAnimationDuration = const Duration(seconds: 4),
    this.lightWaveAnimationDuration = const Duration(seconds: 6),
  });

  @override
  _AnimatedWaveProgressState createState() => _AnimatedWaveProgressState();
}

class _AnimatedWaveProgressState extends State<AnimatedWaveProgress>
    with TickerProviderStateMixin {
  AnimationController controller;
  Animation<int> progressAnimation;
  int currentValue = 0;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
        vsync: this, duration: widget.progressAnimatedDuration);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        progressAnimation.removeListener(handleProgressChange);
        controller.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentValue != widget.value && !controller.isAnimating) {
      progressAnimation =
          controller.drive(IntTween(begin: currentValue, end: widget.value));
      progressAnimation.addListener(handleProgressChange);
      controller.forward();
    }
    return WaveProgress(
      value: currentValue,
      circleProgressColor: widget.circleProgressColor,
      circleProgressBGColor: widget.circleProgressBGColor,
      waveColor: widget.waveColor,
      lightWaveColor: widget.lightWaveColor,
      hintText: widget.hintText,
      progressTextColor: widget.progressTextColor,
      circleProgressWidth: widget.circleProgressWidth,
      lightWaveAnimationDuration: widget.lightWaveAnimationDuration,
      maxValue: widget.maxValue,
      minValue: widget.minValue,
      progressTextFontSize: widget.progressTextFontSize,
      waveAnimationDuration: widget.waveAnimationDuration,
      waveHeight: widget.waveHeight,
    );
  }

  void handleProgressChange() {
    setState(() {
      currentValue = progressAnimation.value;
    });
  }
}

class WaveProgress extends StatefulWidget {
  final Color circleProgressColor;
  final Color circleProgressBGColor;
  final Color waveColor;
  final Color lightWaveColor;
  final Color progressTextColor;
  final double circleProgressWidth;
  final double waveHeight;
  final Text hintText;
  final double progressTextFontSize;
  final Duration waveAnimationDuration;
  final Duration lightWaveAnimationDuration;
  final int maxValue;
  final int minValue;
  final int value;

  @override
  _WaveProgressState createState() => _WaveProgressState();

  WaveProgress({
    @required value,
    @required this.circleProgressColor,
    @required this.circleProgressBGColor,
    @required this.waveColor,
    @required this.lightWaveColor,
    this.minValue = 0,
    this.maxValue = 100,
    this.hintText,
    this.progressTextColor = Colors.blueGrey,
    this.progressTextFontSize = 20,
    this.circleProgressWidth = 5,
    this.waveHeight = 50,
    this.waveAnimationDuration = const Duration(seconds: 4),
    this.lightWaveAnimationDuration = const Duration(seconds: 6),
  }) : this.value = value.clamp(minValue, maxValue);
}

class _WaveProgressState extends State<WaveProgress>
    with TickerProviderStateMixin<WaveProgress> {
  AnimationController waveAnimation;
  AnimationController lightWaveAnimation;

  @override
  void initState() {
    super.initState();
    waveAnimation = AnimationController(
      vsync: this,
      duration: widget.waveAnimationDuration,
    );
    waveAnimation.addListener(waveAnimationListener);
    lightWaveAnimation = AnimationController(
      vsync: this,
      duration: widget.lightWaveAnimationDuration,
    );
    lightWaveAnimation.addListener(lightWaveAnimationListener);
    waveAnimation.repeat();
    lightWaveAnimation.repeat();
  }

  @override
  void dispose() {
    super.dispose();
    waveAnimation?.removeListener(waveAnimationListener);
    waveAnimation?.removeListener(lightWaveAnimationListener);
    waveAnimation?.dispose();
    lightWaveAnimation?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double percent = widget.value.toDouble() / widget.maxValue;
    percent = percent.clamp(0, 1);
    List<Widget> children = <Widget>[
      CustomPaint(
        painter: WaveProgressPainter(
          circleProgressWidth: widget.circleProgressWidth,
          circleProgressBGColor: widget.circleProgressBGColor,
          waveColor: widget.waveColor,
          lightWaveOffsetPercent: lightWaveAnimation.value,
          percent: percent,
          lightWaveColor: widget.lightWaveColor,
          waveOffsetPercent: waveAnimation.value,
          circleProgressColor: widget.circleProgressColor,
          waveHeight: widget.waveHeight,
        ),
        willChange: true,
        isComplex: true,
        size: Size.infinite,
      ),
      Center(
        child: Text(
          '${(percent * 100).ceil()}%',
          style: TextStyle(
              color: widget.progressTextColor,
              fontSize: widget.progressTextFontSize),
        ),
      ),
    ];
    if (widget.hintText != null) {
      children.add(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          widget.hintText,
          SizedBox.fromSize(
            size: Size.fromHeight(100),
          ),
        ],
      ));
    }
    return Stack(
      alignment: Alignment.center,
      children: children,
    );
  }

  void waveAnimationListener() {
    setState(() {});
  }

  void lightWaveAnimationListener() {}
}

class WaveProgressPainter extends CustomPainter {
  double circleProgressWidth;
  double percent = 0.5;
  Color circleProgressColor;
  Color circleProgressBGColor;
  Color waveColor;
  Color lightWaveColor;
  Paint circleProgressBGPaint;
  Paint circleProgressPaint;
  Paint wavePaint;
  Paint lightWavePaint;

  //波浪的高度（波峰与波谷的差值）
  double waveHeight;

  //波浪横向的偏移百分比
  double waveOffsetPercent;

  //浅色波浪横向的偏移百分比
  double lightWaveOffsetPercent;

  double get halfWaveHeight => waveHeight / 2;

  WaveProgressPainter({
    @required this.percent,
    @required this.circleProgressColor,
    @required this.circleProgressBGColor,
    @required this.waveColor,
    @required this.lightWaveColor,
    @required this.waveOffsetPercent,
    @required this.lightWaveOffsetPercent,
    this.circleProgressWidth = 5,
    this.waveHeight = 60,
  }) {
    percent = percent.clamp(0, 1);
    circleProgressBGPaint = Paint()
      ..color = circleProgressBGColor
      ..strokeWidth = circleProgressWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    circleProgressPaint = Paint()
      ..color = circleProgressColor
      ..strokeWidth = circleProgressWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    wavePaint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    lightWavePaint = Paint()
      ..color = lightWaveColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    Offset center = size.center(Offset(0, 0));
    double radius = size.shortestSide / 2;
    //绘制浅色波浪
    drawWave(canvas, center, radius, lightWaveOffsetPercent, lightWavePaint);
    //绘制深色波浪
    drawWave(canvas, center, radius, waveOffsetPercent, wavePaint);
    drawCircleProgress(canvas, center, radius, size);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate != this;
  }

  void drawCircleProgress(
      //逆时针旋转画布90度
      Canvas canvas,
      Offset center,
      double radius,
      Size size) {
    //画进度条圆框背景
    canvas.drawCircle(center, radius, circleProgressBGPaint);
    //保存画布状态
    canvas.save();
    canvas.rotate(degreeToRadian(-90));
    canvas.translate(
        -(size.height + size.width) / 2, -(size.height - size.width) / 2);
    //画进度条圆框进度
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        degreeToRadian(0),
        degreeToRadian(percent * 360),
        false,
        circleProgressPaint);
    //恢复画布状态
    canvas.restore();
  }

  ///角度转弧度
  num degreeToRadian(num deg) => deg * (pi / 180.0);

  ///弧度转角度
  num radianToDegree(num rad) => rad * (180.0 / pi);

  void drawWave(Canvas canvas, Offset center, double radius,
      double waveOffsetPercent, Paint paint) {
    double waveOffset = -(waveOffsetPercent * radius * 2);
    canvas.save();
    Path clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(clipPath);

    double waveProgressHeightY = (1 - percent) * radius * 2;
    Offset point1 = Offset(waveOffset, waveProgressHeightY);
    Offset point2 = Offset(waveOffset + radius, waveProgressHeightY);
    Offset point3 = Offset(waveOffset + radius * 2, waveProgressHeightY);
    Offset point4 = Offset(waveOffset + radius * 3, waveProgressHeightY);
    Offset point5 = Offset(waveOffset + radius * 4, waveProgressHeightY);
    Offset point6 = Offset(point5.dx, radius * 2 + halfWaveHeight);
    Offset point7 = Offset(point1.dx, radius * 2 + halfWaveHeight);
    Offset controlPoint1 =
        Offset(waveOffset + radius * 0.5, waveProgressHeightY - halfWaveHeight);
    Offset controlPoint2 =
        Offset(waveOffset + radius * 1.5, waveProgressHeightY + halfWaveHeight);
    Offset controlPoint3 =
        Offset(waveOffset + radius * 2.5, waveProgressHeightY - halfWaveHeight);
    Offset controlPoint4 =
        Offset(waveOffset + radius * 3.5, waveProgressHeightY + halfWaveHeight);
    Path wavePath = Path()
      ..moveTo(point1.dx, point1.dy)
      ..quadraticBezierTo(
          controlPoint1.dx, controlPoint1.dy, point2.dx, point2.dy)
      ..quadraticBezierTo(
          controlPoint2.dx, controlPoint2.dy, point3.dx, point3.dy)
      ..quadraticBezierTo(
          controlPoint3.dx, controlPoint3.dy, point4.dx, point4.dy)
      ..quadraticBezierTo(
          controlPoint4.dx, controlPoint4.dy, point5.dx, point5.dy)
      ..lineTo(point6.dx, point6.dy)
      ..lineTo(point7.dx, point7.dy)
      ..close();
    canvas.drawPath(wavePath, paint);
    canvas.restore();
  }
}
