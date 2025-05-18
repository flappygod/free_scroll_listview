import 'package:flutter/material.dart';

///获取使用了shrinkWrap,当没有滚动距离时不响应用户输入事件
class FreeLimitShrinkOverScrollPhysics extends ScrollPhysics {
  final ScrollController controller;

  const FreeLimitShrinkOverScrollPhysics({
    required this.controller,
    super.parent,
  });

  @override
  FreeLimitShrinkOverScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FreeLimitShrinkOverScrollPhysics(
      controller: controller,
      parent: buildParent(ancestor),
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // 判断是否允许用户滚动
    return controller.position.maxScrollExtent > 0;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (controller.position.maxScrollExtent <= 0) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}
