import 'package:free_scroll_listview/free_scroll_listview.dart';
import 'package:flutter/material.dart';

///包装器小部件，用于帮助获取项目的偏移量
///如果项目的大小是固定的，则无需将小部件包装到项目中
class AnchorItemWrapper extends StatefulWidget {
  const AnchorItemWrapper({
    required this.actualIndex,
    required this.controller,
    this.reverse = false,
    this.addRepaintBoundary = false,
    this.child,
    super.key,
  });

  //可选的 AnchorScrollController
  final FreeScrollListViewController controller;

  //子小部件
  final Widget? child;

  //项目的索引
  final int actualIndex;

  //reverse
  final bool reverse;

  //add repaint boundary
  final bool addRepaintBoundary;

  @override
  AnchorItemWrapperState createState() => AnchorItemWrapperState();
}

///anchor item wrapper state
class AnchorItemWrapperState extends State<AnchorItemWrapper> {
  ///当前的rect holder
  final RectHolder _rectHolder = RectHolder();

  ///check rect listener
  late VoidCallback _checkRectListener;

  ///refresh rect
  void _refreshRectItems() {
    ///item
    if (!mounted || !widget.controller.hasClients || !widget.controller.position.hasPixels) {
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
      double dy = (pixels + offset + height - offsetItem.dy - itemBox.size.height).removeTinyFraction();
      _addFrameRect(
        Rect.fromLTWH(
          offsetItem.dx.removeTinyFraction(),
          dy,
          (offsetItem.dx + itemBox.size.width).removeTinyFraction(),
          (dy + itemBox.size.height).removeTinyFraction(),
        ),
        widget.actualIndex,
      );
    } else {
      double dy = (pixels + offsetItem.dy - offset).removeTinyFraction();
      _addFrameRect(
        Rect.fromLTRB(
          offsetItem.dx.removeTinyFraction(),
          dy,
          (offsetItem.dx + itemBox.size.width).removeTinyFraction(),
          (dy + itemBox.size.height).removeTinyFraction(),
        ),
        widget.actualIndex,
      );
    }
  }

  ///更新Rect controller
  void _updateScrollRectToController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshRectItems();
      }
    });
  }

  ///这里必然是正在展示的
  void _addFrameRect(Rect rect, int index) {
    ///必然是当前正在展示的
    _rectHolder.rect = rect;
    widget.controller.itemsRectHolder[index] = _rectHolder;
    widget.controller.notifyItemRectShowOnScreen(index);
  }

  ///这里需要判断移除
  void _removeFrameRect(int index) {
    ///如果移除的时候仍然相等
    _rectHolder.rect = null;
    if (widget.controller.itemsRectHolder[index] == _rectHolder) {
      widget.controller.itemsRectHolder.remove(index);
    }
    widget.controller.notifyItemRectRemoveOnScreen(index);
  }

  @override
  void initState() {
    ///init listener
    _checkRectListener = () {
      _refreshRectItems();
    };
    widget.controller.addCheckRectListener(_checkRectListener);

    ///refresh
    _updateScrollRectToController();
    super.initState();
  }

  @override
  void didUpdateWidget(AnchorItemWrapper oldWidget) {
    ///监听更换
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeCheckRectListener(_checkRectListener);
      widget.controller.addCheckRectListener(_checkRectListener);
    }

    ///index发送了改变，View被服用了
    if (oldWidget.actualIndex != widget.actualIndex) {
      _removeFrameRect(oldWidget.actualIndex);
    }

    ///refresh
    _updateScrollRectToController();

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.controller.removeCheckRectListener(_checkRectListener);

    ///移除rect
    _removeFrameRect(widget.actualIndex);

    ///完成释放
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.addRepaintBoundary) {
      return RepaintBoundary(
        child: widget.child ?? const SizedBox(),
      );
    } else {
      return widget.child ?? const SizedBox();
    }
  }
}
