import 'dart:math';

import 'package:flutter/material.dart';

///free scroll listview action type
enum FreeScrollActionAsyncType {
  notifyAnimStart,
  notifyIndexShow,
}

///free scroll listview action type
enum FreeScrollActionSyncType {
  notifyData,
  notifyAnimStop,
  notifyAnimOffset,
}

///free scroll index offset
class FreeFixIndexOffset {
  int fixIndex;
  double fixAnchor;
  FreeScrollType fixAlign;

  FreeFixIndexOffset({
    required this.fixIndex,
    required this.fixAnchor,
    required this.fixAlign,
  });
}

///time stamp de bouncer
class TimeStampDeBouncer {
  //is action
  bool _isAction = false;

  TimeStampDeBouncer();

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
    return rect != null;
  }

  ///rect
  Rect? rect;

  ///高度
  double? rectHeight() {
    return rect?.height;
  }

  ///顶部
  double? rectTop() {
    return rect?.top;
  }

  ///底部
  double? rectBottom() {
    return rect?.bottom;
  }
}
extension DoubleExtensions on double {
  /// 判断两个浮点数是否近似相等
  bool isAlmostEqual(double other, {double epsilon = 1e-4}) {
    return (this - other).abs() < epsilon;
  }

  /// 去掉过小的小数部分（可自定义精度）
  double removeTinyFraction({int precision = 4}) {
    final factor = pow(10, precision);
    return (this * factor).roundToDouble() / factor;
  }
}

