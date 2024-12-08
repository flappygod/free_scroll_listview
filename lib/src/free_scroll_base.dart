import 'package:flutter/material.dart';

///free scroll listview action type
enum FreeScrollListViewActionType {
  notifyData,
  notifyAnimStart,
  notifyAnimStop,
  notifyAnimOffset,
  notifyJump,
}

///time stamp debouncer
class TimeStampDebouncer {
  bool _isAction = false;

  TimeStampDebouncer();

  void run(WillReachCallback? action) {
    if (_isAction) {
      return;
    } else {
      _isAction = true;
      if (action != null) {
        action().then((_) {
          _isAction = false;
        }).catchError((error) {
          _isAction = false;
        });
      } else {
        _isAction = false;
      }
    }
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

///offset rect list
void offsetRectList(Map<int, Rect> rectMap, double offset) {
  rectMap.updateAll((key, rect) {
    return rect.shift(Offset(0, offset));
  });
}

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
  late FreeScrollAlign align;

  AnimationData(
    this.duration,
    this.curve,
    this.startPosition,
    this.endPosition,
    this.align,
  );
}

///free scroll align
enum FreeScrollAlign {
  topToBottom,
  bottomToTop,
  directJumpTo,
}

///rect holder
class RectHolder {
  bool isOnScreen = false;
  Rect? rect;

  RectHolder(
    this.isOnScreen,
    this.rect,
  );

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
