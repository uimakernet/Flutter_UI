import 'package:flutter/material.dart';
import 'package:flutter_ui/src/tweens.dart';

class SlideLayout extends StatefulWidget {
  final AxisDirection slideDirection;
  final double limit;
  final Widget foreground;
  final Widget background;

  SlideLayout(
      {@required this.foreground,
      @required this.background,
      this.slideDirection = AxisDirection.right,
      this.limit = 150});

  @override
  _SlideLayoutState createState() => _SlideLayoutState();
}

class _SlideLayoutState extends State<SlideLayout>
    with TickerProviderStateMixin {
  Offset _slideOffset = Offset.zero;
  AnimationController _animationController;
  CurvedAnimation _curvedAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _curvedAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.decelerate,
    );
  }

  @override
  Widget build(BuildContext context) {
    //debugPrint('_slideOffset:${_slideOffset.toString()}');
    return GestureDetector(
      onPanUpdate: handlePanUpdate,
      onPanEnd: handlePanEnd,
      child: Stack(
        children: <Widget>[
          Align(
            alignment: getBackgroundAlignment(widget.slideDirection),
            child: buildBackgroundContainer(
                widget.slideDirection, widget.background),
          ),
          Transform.translate(
            child: widget.foreground,
            offset: _slideOffset,
          ),
        ],
      ),
    );
  }

  void handlePanUpdate(DragUpdateDetails details) {
    //debugPrint('delta:${details.delta.toString()}-----sourceTimeStamp:${details.sourceTimeStamp.toString()}----globalPosition:${details.globalPosition.toString()}---primaryDelta:${details.primaryDelta.toString()}');
    setState(() {
      switch (widget.slideDirection) {
        case AxisDirection.down:
          _slideOffset = _slideOffset.translate(0, details.delta.dy);
          if (_slideOffset.dy.abs() > widget.limit.abs()) {
            _slideOffset = Offset(0, -widget.limit);
          }
          if (_slideOffset.dy > 0) {
            _slideOffset = Offset.zero;
          }
          break;
        case AxisDirection.up:
          _slideOffset = _slideOffset.translate(0, details.delta.dy);
          if (_slideOffset.dy.abs() > widget.limit.abs()) {
            _slideOffset = Offset(0, widget.limit);
          }
          if (_slideOffset.dy < 0) {
            _slideOffset = Offset.zero;
          }
          break;
        case AxisDirection.left:
          _slideOffset = _slideOffset.translate(details.delta.dx, 0);
          if (_slideOffset.dx.abs() > widget.limit.abs()) {
            _slideOffset = Offset(widget.limit, 0);
          }
          if (_slideOffset.dx < 0) {
            _slideOffset = Offset.zero;
          }
          break;
        case AxisDirection.right:
          _slideOffset = _slideOffset.translate(details.delta.dx, 0);
          if (_slideOffset.dx.abs() > widget.limit.abs()) {
            _slideOffset = Offset(-widget.limit, 0);
          }
          if (_slideOffset.dx > 0) {
            _slideOffset = Offset.zero;
          }
          break;
      }
    });
  }

  void handlePanEnd(DragEndDetails details) {
    var pixelsPerSecond = details.velocity.pixelsPerSecond;
    //debugPrint('velocity:${pixelsPerSecond.toString()}');
    switch (widget.slideDirection) {
      case AxisDirection.down:
      case AxisDirection.up:
        if (pixelsPerSecond.dy.abs() > 500) {
          //速度足够
          if (pixelsPerSecond.dy > 0) {
            //下滑
            resetWithAnimation(widget.slideDirection == AxisDirection.up);
          } else {
            //上滑
            resetWithAnimation(widget.slideDirection == AxisDirection.down);
          }
        } else {
          //速度不够，判断结束的位置
          if (_slideOffset.dy.abs() < widget.limit.abs() / 2) {
            //位置不够一半，恢复原始位置
            resetWithAnimation(false);
          } else {
            resetWithAnimation(true);
          }
        }
        break;
      case AxisDirection.left:
      case AxisDirection.right:
        if (pixelsPerSecond.dx.abs() > 500) {
          //速度足够
          if (pixelsPerSecond.dx > 0) {
            //右滑
            resetWithAnimation(widget.slideDirection == AxisDirection.left);
          } else {
            //左滑
            resetWithAnimation(widget.slideDirection == AxisDirection.right);
          }
        } else {
          //速度不够，判断结束的位置
          if (_slideOffset.dx.abs() < widget.limit.abs() / 2) {
            //位置不够一半，恢复原始位置
            resetWithAnimation(false);
          } else {
            resetWithAnimation(true);
          }
        }
        break;
    }
  }

  Animation<double> _animation;

  bool get isHorizontal =>
      widget.slideDirection == AxisDirection.left ||
      widget.slideDirection == AxisDirection.right;

  ///处理松手的操作
  void resetWithAnimation(bool isOpen) {
    double begin = isHorizontal ? _slideOffset.dx : _slideOffset.dy;
    double end = 0;
    _animation?.removeListener(handleOpen);
    _animationController.reset();
    switch (widget.slideDirection) {
      case AxisDirection.up:
      case AxisDirection.left:
        end = isOpen ? widget.limit : 0;
        break;
      case AxisDirection.down:
      case AxisDirection.right:
        end = isOpen ? -widget.limit : 0;
        break;
    }
    _animation = _curvedAnimation.drive(DoubleTween(begin: begin, end: end));
    _animation.addListener(handleOpen);
    _animationController.forward();
  }

  void handleOpen() {
    setState(() {
      var value = _animation.value;
//      debugPrint('offsetX:$value');
      _slideOffset = isHorizontal ? Offset(value, 0) : Offset(0, value);
    });
  }

  Alignment getBackgroundAlignment(AxisDirection direction) {
    switch (direction) {
      case AxisDirection.left:
        return Alignment.centerLeft;
      case AxisDirection.right:
        return Alignment.centerRight;
      case AxisDirection.up:
        return Alignment.topCenter;
      case AxisDirection.down:
        return Alignment.bottomCenter;
      default:
        return Alignment.centerRight;
    }
  }

  buildBackgroundContainer(AxisDirection direction, Widget background) {
    Size size;
    if (direction == AxisDirection.left || direction == AxisDirection.right) {
      size = Size.fromWidth(widget.limit);
    } else {
      size = Size.fromHeight(widget.limit);
    }
    return SizedBox.fromSize(
      size: size,
      child: background,
    );
  }
}
