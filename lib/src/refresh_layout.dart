import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ui/src/tweens.dart';
import 'dart:math';

enum RefreshState {
  //正常状态
  NORMAL,
  //上下拉拖拽
  PULL,
  //拖拽中，已经满足上下拉刷新范围，释放刷新
  RELEASE_TO_REFRESH,
  //刷新中
  REFRESHING,
  //刷新完成
  REFRESH_COMPLETE,
}

enum PullDirection {
  DOWN,
  UP,
  IDLE,
}

enum RefreshMode { TOP, BOTTOM, BOTH }

class RefreshLayout extends StatefulWidget {
  final RefreshBodyBuilder headerBuilder;
  final RefreshBodyBuilder footerBuilder;
  final RefreshCallback onRefresh;
  final RefreshCallback onLoadMore;
  final Widget child;
  final RefreshMode refreshMode;

  RefreshLayout({
    @required this.child,
    this.onRefresh,
    this.onLoadMore,
    this.headerBuilder = const DefaultTopRefreshBodyBuilder(),
    this.footerBuilder = const DefaultBottomRefreshBodyBuilder(),
    this.refreshMode = RefreshMode.BOTH,
  });

  @override
  _RefreshLayoutState createState() => _RefreshLayoutState();
}

class _RefreshLayoutState extends State<RefreshLayout>
    with TickerProviderStateMixin {
  final double _scrollLimit = 300;
  final double _refreshExtent = 80;
  RefreshState _state = RefreshState.NORMAL;
  Offset _overScrollOffset = Offset.zero;
  AnimationController _controller;

  PullDirection get _pullDirection {
    if (_overScrollOffset.dy > 0) {
      return PullDirection.DOWN;
    } else if (_overScrollOffset.dy < 0) {
      return PullDirection.UP;
    } else {
      return PullDirection.IDLE;
    }
  }

  @override
  void initState() {
    super.initState();
    assert(() {
      if (widget.child is ScrollView &&
          (widget.child as ScrollView).physics is ClampingScrollPhysics) {
        return true;
      } else {
        throw FlutterError(
            'RefreshLayout: child must be subclass of ScrollView and physics must be ClampingScrollPhysics');
      }
    }());
    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    double topHeight =
        _pullDirection == PullDirection.DOWN ? _overScrollOffset.dy.abs() : 0;
    double bottomHeight =
        _pullDirection == PullDirection.UP ? _overScrollOffset.dy.abs() : 0;
    return Stack(
      children: <Widget>[
        widget.headerBuilder.build(_state, topHeight),
        Align(
          alignment: Alignment.bottomCenter,
          child: widget.footerBuilder.build(_state, bottomHeight),
        ),
        Transform.translate(
          offset: _overScrollOffset,
          child: NotificationListener<ScrollNotification>(
            onNotification: handleScrollNotification,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.grey[100]),
              child: widget.child,
            ),
          ),
        )
      ],
    );
  }

  bool handleScrollNotification(ScrollNotification notification) {
    //debugPrint(notification.toString());
    if (notification.depth != 0) {
      return false;
    }
    if (_controller.isAnimating) {
      return false;
    }
    if (notification is OverscrollNotification) {
      if (notification.velocity == 0 && notification.dragDetails != null) {
        if (canRefresh(notification)) {
          //上下拉状态
          setState(() {
            double factor = 1; //阻尼因子
            if (_overScrollOffset.dy.abs() > 0) {
              factor -= _overScrollOffset.dy.abs() / _scrollLimit;
            }
            _overScrollOffset = _overScrollOffset.translate(
                0, notification.dragDetails.delta.dy * factor);
            //debugPrint('factor--:$factor----_overScrollOffset:$_overScrollOffset');
            _updatePullRefreshState();
          });
        }
      }
    }
    if (notification is ScrollEndNotification) {
      if (_state == RefreshState.PULL ||
          _state == RefreshState.RELEASE_TO_REFRESH) {
        //手离开，fling滚动
        if (_overScrollOffset.dy.abs() < _refreshExtent) {
          _animateToNormal();
        } else {
          _handleRefresh();
        }
      }
    }
    if (notification is ScrollUpdateNotification) {
      //debugPrint(notification.toString());
      if (_state == RefreshState.PULL ||
          _state == RefreshState.RELEASE_TO_REFRESH) {
        //在上下拉的状态中，滚动了scroll里面的内容，需要将上下拉进行回滚
        setState(() {
          if (notification.dragDetails != null) {
            if (_pullDirection == PullDirection.DOWN) {
              //避免回滚过头
              _overScrollOffset += notification.dragDetails.delta;
              if (_overScrollOffset.dy < 0) {
                _overScrollOffset = Offset.zero;
                _state = RefreshState.NORMAL;
              }
              _updatePullRefreshState();
            } else if (_pullDirection == PullDirection.UP) {
              _overScrollOffset += notification.dragDetails.delta;
              if (_overScrollOffset.dy > 0) {
                _overScrollOffset = Offset.zero;
                _state = RefreshState.NORMAL;
              }
              _updatePullRefreshState();
            }
          } else {
            //手离开，fling滚动
            if (_overScrollOffset.dy.abs() < _refreshExtent) {
              _animateToNormal();
            } else {
              _handleRefresh();
            }
          }
        });
      }
    }
    return false;
  }

  void _updatePullRefreshState() {
    if (_overScrollOffset.dy.abs() < _refreshExtent) {
      _state = RefreshState.PULL;
    } else {
      _state = RefreshState.RELEASE_TO_REFRESH;
    }
  }

  void _handleRefresh() {
    setState(() {
      _state = RefreshState.REFRESHING;
    });
    _animateToRefresh();
    Future<void> result = _pullDirection == PullDirection.DOWN
        ? widget.onRefresh()
        : widget.onLoadMore();
    if (result != null) {
      result.whenComplete(() {
        setState(() {
          _state = RefreshState.REFRESH_COMPLETE;
        });
        _animateToNormal();
      });
    }
  }

  Animation<double> _animation;

  void _animateToNormal() {
    if (_controller.isAnimating) {
      _controller.stop();
    }
    assert(!_controller.isAnimating);
    _animation?.removeListener(_scrollByAnimation);
    _controller.reset();
    _animation =
        _controller.drive(DoubleTween(begin: _overScrollOffset.dy, end: 0));
    _animation.addListener(_scrollByAnimation);
    _controller.forward();
  }

  void _animateToRefresh() {
    _animation?.removeListener(_scrollByAnimation);
    _controller.reset();
    _animation = _controller.drive(DoubleTween(
        begin: _overScrollOffset.dy,
        end: _pullDirection == PullDirection.DOWN
            ? _refreshExtent
            : -_refreshExtent));
    _animation.addListener(_scrollByAnimation);
    _controller.forward();
  }

  void _scrollByAnimation() {
    setState(() {
      _overScrollOffset = Offset(0, _animation.value);
      if (_overScrollOffset == Offset.zero) {
        _state = RefreshState.NORMAL;
      }
    });
  }

  bool canRefresh(OverscrollNotification notification) {
    switch (widget.refreshMode) {
      case RefreshMode.TOP:
        return notification.dragDetails.delta.dy > 0;
      case RefreshMode.BOTTOM:
        return notification.dragDetails.delta.dy < 0;
      default:
        return true;
    }
  }
}

abstract class RefreshBodyBuilder {
  Widget build(RefreshState state, double height);

  bool isHeader();
}

abstract class DefaultRefreshBodyBuilder implements RefreshBodyBuilder {
  const DefaultRefreshBodyBuilder();

  String getTintText(RefreshState state) {
    switch (state) {
      case RefreshState.NORMAL:
      case RefreshState.PULL:
        return isHeader() ? '下拉刷新' : '上拉加载';
      case RefreshState.RELEASE_TO_REFRESH:
        return isHeader() ? '释放刷新' : '释放加载';
      case RefreshState.REFRESHING:
        return isHeader() ? '刷新中' : '加载中';
      case RefreshState.REFRESH_COMPLETE:
        return isHeader() ? '刷新完成' : '加载完成';
      default:
        return isHeader() ? '下拉刷新' : '上拉加载';
        break;
    }
  }

  @override
  Widget build(RefreshState state, double height) {
    return DefaultRefreshBody(state, height, getTintText(state));
  }
}

class DefaultTopRefreshBodyBuilder extends DefaultRefreshBodyBuilder {
  const DefaultTopRefreshBodyBuilder();

  @override
  bool isHeader() => true;
}

class DefaultBottomRefreshBodyBuilder extends DefaultRefreshBodyBuilder {
  const DefaultBottomRefreshBodyBuilder();

  @override
  bool isHeader() => false;
}

class DefaultRefreshBody extends StatefulWidget {
  final RefreshState state;
  final double height;
  final String tintText;

  DefaultRefreshBody(this.state, this.height, this.tintText);

  @override
  _DefaultRefreshBodyState createState() => _DefaultRefreshBodyState();
}

class _DefaultRefreshBodyState extends State<DefaultRefreshBody>
    with TickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: pi * 2,
      duration: Duration(seconds: 1),
    );
    _controller.addListener(() {
      setState(() {});
    });
    if (widget.state == RefreshState.RELEASE_TO_REFRESH) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(DefaultRefreshBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == RefreshState.RELEASE_TO_REFRESH) {
      _controller.repeat();
    } else if (widget.state == RefreshState.REFRESH_COMPLETE) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      color: Colors.white70,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Transform.rotate(
              angle:
                  widget.state == RefreshState.REFRESHING && _controller != null
                      ? _controller.value
                      : -widget.height,
              child: Image.asset(
                'images/refresh_loading.png',
                package: 'flutter_ui',
                width: 28,
                height: 28,
              ),
            ),
          ),
          Text(widget.tintText),
        ],
      ),
    );
  }
}
