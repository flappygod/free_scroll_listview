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
  void _refreshRectItems() {
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
      double dy = (offset + height - offsetItem.dy - itemBox.size.height);
      _addFrameRect(
        Rect.fromLTWH(
          offsetItem.dx.removeTinyFraction(),
          (dy + pixels).removeTinyFraction(),
          itemBox.size.width.removeTinyFraction(),
          itemBox.size.height.removeTinyFraction(),
        ),
      );
    } else {
      _addFrameRect(
        Rect.fromLTWH(
          offsetItem.dx.removeTinyFraction(),
          (offsetItem.dy - offset + pixels).removeTinyFraction(),
          itemBox.size.width.removeTinyFraction(),
          itemBox.size.height.removeTinyFraction(),
        ),
      );
    }
  }

  ///update scroll rect to controller
  void _updateScrollRectToController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshRectItems();
    });
  }

  ///add to rect
  void _addFrameRect(Rect rect) {
    if (widget.rectHolder.wrapperHash == hashCode) {
      widget.rectHolder.rect = rect;
      widget.controller.notifyItemRectShowOnScreen(widget.actualIndex);
    }
  }

  ///remove rect
  void _removeFrameRect(RectHolder holder, int index) {
    holder.wrapperHash = null;
    widget.controller.notifyItemRectRemoveOnScreen(index);
  }

  @override
  void initState() {
    ///init listener
    _checkRectListener = () {
      _refreshRectItems();
    };
    widget.controller.addCheckRectListener(_checkRectListener);

    ///set wrapper hash
    widget.rectHolder.wrapperHash = hashCode;
    widget.rectHolder.rect = null;

    ///refresh
    _updateScrollRectToController();
    super.initState();
  }

  @override
  void didUpdateWidget(AnchorItemWrapper oldWidget) {
    ///check rect listener changed
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeCheckRectListener(_checkRectListener);
      widget.controller.addCheckRectListener(_checkRectListener);
    }

    ///remove former wrapper hash and rect
    if (oldWidget.rectHolder.wrapperHash == hashCode &&
        oldWidget.rectHolder != widget.rectHolder) {
      _removeFrameRect(
        oldWidget.rectHolder,
        oldWidget.actualIndex,
      );
    }

    ///set current wrapper hash and rect
    widget.rectHolder.wrapperHash = hashCode;

    ///refresh
    _updateScrollRectToController();

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    ///check rect listener
    widget.controller.removeCheckRectListener(_checkRectListener);

    ///remove wrapper hash if is equal
    if (widget.rectHolder.wrapperHash == hashCode) {
      _removeFrameRect(
        widget.rectHolder,
        widget.actualIndex,
      );
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const SizedBox();
  }
}
