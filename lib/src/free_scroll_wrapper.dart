import 'package:free_scroll_listview/free_scroll_listview.dart';
import 'package:flutter/material.dart';

///包装器小部件，用于帮助获取项目的偏移量
///如果项目的大小是固定的，则无需将小部件包装到项目中
class AnchorItemWrapper extends StatefulWidget {
  const AnchorItemWrapper({
    required this.actualIndex,
    required this.controller,
    this.reverse = false,
    this.listViewState,
    this.child,
    super.key,
  });

  //可选的 AnchorScrollController
  final FreeScrollListViewController controller;

  //list offset
  final FreeScrollListViewState? listViewState;

  //子小部件
  final Widget? child;

  //项目的索引
  final int actualIndex;

  //reverse
  final bool reverse;

  @override
  AnchorItemWrapperState createState() => AnchorItemWrapperState();
}

///anchor item wrapper state
class AnchorItemWrapperState extends State<AnchorItemWrapper> {
  @override
  void initState() {
    super.initState();
    _updateScrollRectToController();
  }

  @override
  void didUpdateWidget(AnchorItemWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateScrollRectToController();
  }

  @override
  void dispose() {
    widget.controller.removeItemRectOnScreen(widget.actualIndex);
    super.dispose();
  }

  ///update scroll rect to controller
  void _updateScrollRectToController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ///item
      if (!mounted) {
        return;
      }

      double height = widget.controller.listViewHeight;
      double offset = widget.controller.listViewOffset;

      ///not zero
      if (height == 0) {
        return;
      }

      RenderBox? itemBox = context.findRenderObject() as RenderBox?;
      Offset? offsetItem = itemBox?.localToGlobal(const Offset(0.0, 0.0));

      ///nothing
      if (offsetItem == null || itemBox == null) {
        return;
      }

      ///offset item
      if (widget.reverse) {
        double dy = offset + height - offsetItem.dy - itemBox.size.height;
        Rect rect = Rect.fromLTWH(
          offsetItem.dx,
          dy + widget.controller.position.pixels,
          itemBox.size.width,
          itemBox.size.height,
        );
        widget.controller.addItemRectOnScreen(widget.actualIndex, rect);
      } else {
        Rect rect = Rect.fromLTWH(
          offsetItem.dx,
          offsetItem.dy - offset + widget.controller.position.pixels,
          itemBox.size.width,
          itemBox.size.height,
        );
        widget.controller.addItemRectOnScreen(widget.actualIndex, rect);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const SizedBox();
  }
}
