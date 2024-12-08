import 'package:free_scroll_listview/free_scroll_listview.dart';
import 'package:flutter/material.dart';

///包装器小部件，用于帮助获取项目的偏移量
///如果项目的大小是固定的，则无需将小部件包装到项目中
class AnchorItemWrapper extends StatefulWidget {
  const AnchorItemWrapper({
    required this.actualIndex,
    required this.controller,
    required this.rectHolder,
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

  //Rect
  final RectHolder rectHolder;

  //reverse
  final bool reverse;

  @override
  AnchorItemWrapperState createState() => AnchorItemWrapperState();
}

///anchor item wrapper state
class AnchorItemWrapperState extends State<AnchorItemWrapper> {
  ///check rect listener
  late VoidCallback _checkRectListener;

  ///refresh rect
  void _refreshRectItems(RectHolder holder, int index) {
    ///item
    if (!mounted ||
        !widget.controller.hasClients ||
        !widget.controller.position.hasPixels) {
      return;
    }

    double height = widget.controller.listViewHeight;
    double offset = widget.controller.listViewOffset;
    double pixels = widget.controller.position.pixels;

    ///not zero
    if (height == 0) {
      return;
    }

    RenderObject? renderObject = context.findRenderObject();
    RenderBox? itemBox = renderObject is RenderBox ? renderObject : null;
    Offset? offsetItem = itemBox?.localToGlobal(const Offset(0.0, 0.0));

    ///nothing
    if (offsetItem == null || itemBox == null) {
      return;
    }

    ///offset item
    if (widget.reverse) {
      double dy = offset + height - offsetItem.dy - itemBox.size.height;
      _addFrameRect(
        holder,
        index,
        Rect.fromLTWH(
          offsetItem.dx,
          dy + pixels,
          itemBox.size.width,
          itemBox.size.height,
        ),
      );
    } else {
      _addFrameRect(
        holder,
        index,
        Rect.fromLTWH(
          offsetItem.dx,
          offsetItem.dy - offset + pixels,
          itemBox.size.width,
          itemBox.size.height,
        ),
      );
    }
  }

  ///update scroll rect to controller
  void _updateScrollRectToController(RectHolder holder, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshRectItems(holder, index);
    });
  }

  ///add to rect
  void _addFrameRect(RectHolder holder, int index, Rect rect) {
    if (widget.rectHolder == holder && widget.actualIndex == index) {
      holder.rect = rect;
      holder.isOnScreen = true;
      widget.controller.notifyItemRectShowOnScreen(index);
    }
  }

  ///remove rect
  void _removeFrameRect(RectHolder holder, int index) {
    holder.isOnScreen = false;
    widget.controller.notifyItemRectRemoveOnScreen(index);
  }

  @override
  void initState() {
    _checkRectListener = () {
      if (widget.rectHolder.isOnScreen) {
        _refreshRectItems(widget.rectHolder, widget.actualIndex);
      }
    };
    _removeFrameRect(widget.rectHolder, widget.actualIndex);
    widget.controller.addCheckRectListener(_checkRectListener);
    super.initState();
  }

  @override
  void dispose() {
    _removeFrameRect(widget.rectHolder, widget.actualIndex);
    widget.controller.removeCheckRectListener(_checkRectListener);
    super.dispose();
  }

  @override
  void didUpdateWidget(AnchorItemWrapper oldWidget) {
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeCheckRectListener(_checkRectListener);
      widget.controller.addCheckRectListener(_checkRectListener);
    }
    if (widget.rectHolder != oldWidget.rectHolder ||
        widget.actualIndex != oldWidget.actualIndex) {
      _removeFrameRect(oldWidget.rectHolder, oldWidget.actualIndex);
      _removeFrameRect(widget.rectHolder, widget.actualIndex);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    _updateScrollRectToController(widget.rectHolder, widget.actualIndex);
    return widget.child ?? const SizedBox();
  }
}
