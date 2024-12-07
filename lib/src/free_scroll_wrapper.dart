import 'package:free_scroll_listview/free_scroll_listview.dart';
import 'package:flutter/material.dart';

///包装器小部件，用于帮助获取项目的偏移量
///如果项目的大小是固定的，则无需将小部件包装到项目中
class AnchorItemWrapper extends StatefulWidget {
  const AnchorItemWrapper({
    required this.actualIndex,
    required this.controller,
    required this.visibleItemRectMap,
    required this.cachedItemRectMap,
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

  //visible
  final Map<int, Rect> visibleItemRectMap;

  //cached
  final Map<int, Rect> cachedItemRectMap;

  //reverse
  final bool reverse;

  @override
  AnchorItemWrapperState createState() => AnchorItemWrapperState();
}

///anchor item wrapper state
class AnchorItemWrapperState extends State<AnchorItemWrapper> {
  ///is disposed or not
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _removeFrameRectToController();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnchorItemWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  ///remove rect
  void _removeFrameRectToController() {
    widget.visibleItemRectMap.remove(widget.actualIndex);
    widget.controller.notifyItemRectRemoveOnScreen(widget.actualIndex);
  }

  ///add to rect
  void _addFrameRectToController(Rect rect) {
    widget.visibleItemRectMap[widget.actualIndex] = rect;
    widget.cachedItemRectMap[widget.actualIndex] = rect;
    widget.controller.notifyItemRectShowOnScreen(widget.actualIndex);
  }

  ///update scroll rect to controller
  void _updateScrollRectToController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ///item
      if (!mounted || _disposed) {
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
      if (offsetItem == null ||
          itemBox == null ||
          !widget.controller.hasClients ||
          !widget.controller.position.hasPixels) {
        return;
      }

      double pixels = widget.controller.position.pixels;

      ///offset item
      if (widget.reverse) {
        double dy = offset + height - offsetItem.dy - itemBox.size.height;
        _addFrameRectToController(Rect.fromLTWH(
          offsetItem.dx,
          dy + pixels,
          itemBox.size.width,
          itemBox.size.height,
        ));
      } else {
        _addFrameRectToController(Rect.fromLTWH(
          offsetItem.dx,
          offsetItem.dy - offset + pixels,
          itemBox.size.width,
          itemBox.size.height,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _updateScrollRectToController();
    return widget.child ?? const SizedBox();
  }
}
