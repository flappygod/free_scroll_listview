import 'package:free_scroll_listview/free_scroll_listview.dart';
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
    if (controller is FreeScrollListViewController) {
      FreeScrollListViewController ctl =
          controller as FreeScrollListViewController;
      if (ctl.hasClients &&
          ctl.position.hasContentDimensions &&
          ctl.dataListOffset() == 0) {
        return controller.position.maxScrollExtent > 0;
      } else {
        return true;
      }
    }
    return true;
  }
}
