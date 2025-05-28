import 'package:flutter/material.dart';

///free scroll listview action type
enum FreeScrollActionAsyncType {
  notifyAnimStart,
  notifyJump,
}

///free scroll listview action type
enum FreeScrollActionSyncType {
  notifyData,
  notifyAnimStop,
  notifyAnimOffset,
}

///time stamp debouncer
class TimeStampDebouncer {
  //is action
  bool _isAction = false;

  TimeStampDebouncer();

  void run(WillReachCallback? action) {
    if (action == null || _isAction) {
      return;
    }
    _isAction = true;
    action().then((_) {
      _isAction = false;
    }).catchError((error) {
      _isAction = false;
    });
  }
}

///定义一个扩展方法 mapIndexed
extension IterableExtensions<E> on Iterable<E> {
  Iterable<T> mapIndexed<T>(T Function(int index, E element) f) {
    int index = 0;
    return map((e) => f(index++, e));
  }
}

///will reach callback
typedef WillReachCallback = Future Function();

///on item show
typedef FreeScrollOnItemShow = void Function(List<int> data);

///on item show
typedef FreeScrollOnIndexChange = void Function(int data);

///animation data
class AnimationData {
  late Duration duration;
  late Curve curve;
  late double startPosition;
  late double endPosition;
  late FreeScrollType type;

  AnimationData(
    this.duration,
    this.curve,
    this.startPosition,
    this.endPosition,
    this.type,
  );
}

///free scroll align
enum FreeScrollType {
  topToBottom,
  bottomToTop,
  directJumpTo,
}

///rect holder
class RectHolder {
  ///check is on screen or not
  bool get isOnScreen {
    return wrapperHash != null && rect != null;
  }

  ///wrapper hash
  int? wrapperHash;

  ///rect
  Rect? rect;

  double? rectHeight() {
    return rect?.height;
  }

  double? rectTop() {
    return rect?.top;
  }

  double? rectBottom() {
    return rect?.bottom;
  }
}

extension DoubleExtensions on double {
  /// 判断两个浮点数是否近似相等
  bool isAlmostEqual(double other, {double epsilon = 1e-12}) {
    return (this - other).abs() < epsilon;
  }

  /// 去掉小于指定误差范围的小数位（默认为 1e-12）
  double removeTinyFraction({double epsilon = 1e-12}) {
    return (abs() < epsilon) ? 0.0 : this;
  }
}
