import 'package:flutter/cupertino.dart';
import 'dart:async';

///preview model
class PreviewModel {
  bool allPreviewed = true;
  double totalHeight = 0;
  double listviewHeight = 0;
  Map<int, double> itemHeights = {};
}

///预览最多等待200毫秒
const Duration kPreviewItemsTimeout = Duration(milliseconds: 200);

///addition preview controller
class AdditionPreviewController<T> extends ChangeNotifier {
  //preview offset keys
  final Map<int, GlobalKey> _previewKeys = {};

  //preview data list
  final Map<int, Widget> _previewWidgetList = {};

  //preview list height
  final GlobalKey _previewListKey = GlobalKey();

  //offset preview completer
  Completer<PreviewModel?>? _offsetPreviewCompleter;

  //preview count
  int _previewCount = 0;

  //preview reverse or not
  bool _previewReverse = false;

  //preview extent
  double _previewExtent = 0;

  //preview items height
  Future<PreviewModel?> previewItemsHeight(
    int previewCount, {
    double previewExtent = 0,
    bool previewReverse = false,
    bool skip = false,
  }) {
    //return null if preview is already gone
    if (skip ||
        (_offsetPreviewCompleter != null &&
            !_offsetPreviewCompleter!.isCompleted)) {
      return Future.value(null);
    }

    //preview setting
    _previewCount = previewCount;
    _previewExtent = previewExtent;
    _previewReverse = previewReverse;

    _previewKeys.clear();
    _previewWidgetList.clear();
    _offsetPreviewCompleter = Completer<PreviewModel?>();
    notifyListeners();

    return _offsetPreviewCompleter!.future.timeout(
      kPreviewItemsTimeout,
      onTimeout: () {
        final completer = _offsetPreviewCompleter;

        //超时后清理状态，避免后续一直卡在“已有未完成预览”
        _offsetPreviewCompleter = null;
        _previewCount = 0;
        _previewReverse = false;
        _previewExtent = 0;
        _previewKeys.clear();
        _previewWidgetList.clear();
        notifyListeners();

        //如果原 completer 还没完成，这里补一个 null 结果，避免外部继续等待
        //后续即使 postFrame 回来，_checkPreviewHeight 里也会因为 completer 状态变化而退出
        if (completer != null && !completer.isCompleted) {
          completer.complete(null);
        }

        return null;
      },
    );
  }
}

///addition preview
class AdditionPreview<T> extends StatefulWidget {
  //controller
  final AdditionPreviewController<T> controller;

  //item builder
  final NullableIndexedWidgetBuilder itemBuilder;

  //padding
  final EdgeInsetsGeometry? padding;

  //margin
  final EdgeInsetsGeometry? margin;

  //max height
  final double maxHeight;

  const AdditionPreview({
    super.key,
    required this.controller,
    required this.itemBuilder,
    required this.maxHeight,
    this.padding,
    this.margin,
  });

  @override
  State<StatefulWidget> createState() {
    return _AdditionPreviewState<T>();
  }
}

///addition preview state
class _AdditionPreviewState<T> extends State<AdditionPreview<T>>
    with SingleTickerProviderStateMixin {
  //listener
  late VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      setState(() {});
    };
    widget.controller.addListener(_listener);
  }

  @override
  void didUpdateWidget(AdditionPreview<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_listener);
      widget.controller.addListener(_listener);
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.removeListener(_listener);
  }

  //check preview height
  void _checkPreviewHeight() {
    //do nothing if not set
    if (widget.controller._offsetPreviewCompleter == null ||
        widget.controller._offsetPreviewCompleter!.isCompleted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ///get preview completer at first
      Completer<PreviewModel?>? completer =
          widget.controller._offsetPreviewCompleter;

      ///is completed
      if (completer == null || completer.isCompleted) {
        return;
      }

      ///create preview model
      PreviewModel previewModel = PreviewModel();

      ///all
      for (int s = 0; s < widget.controller._previewCount; s++) {
        ///get context
        final BuildContext? context =
            widget.controller._previewKeys[s]?.currentContext;

        ///anyone is empty, preview failure
        final RenderBox? box = context?.findRenderObject() as RenderBox?;

        ///get size
        if (box != null) {
          double itemHeight = box.size.height;
          previewModel.totalHeight += itemHeight;
          previewModel.itemHeights[s] = itemHeight;
        } else {
          previewModel.allPreviewed = false;
        }
      }

      ///get listview height
      final BuildContext? listContext =
          widget.controller._previewListKey.currentContext;
      final RenderBox? listBox = listContext?.findRenderObject() as RenderBox?;
      previewModel.listviewHeight = listBox?.size.height ?? 0;

      ///clear preview completer
      widget.controller._offsetPreviewCompleter = null;
      widget.controller._previewCount = 0;
      widget.controller._previewReverse = false;
      widget.controller._previewExtent = 0;
      if (mounted) {
        setState(() {});
      }

      ///complete
      if (!completer.isCompleted) {
        completer.complete(previewModel);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _checkPreviewHeight();
    if (widget.controller._previewCount == 0) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 0.01,
      width: double.infinity,
      child: OverflowBox(
        minHeight: widget.maxHeight,
        maxHeight: widget.maxHeight,
        child: ListView.builder(
          key: widget.controller._previewListKey,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.controller._previewCount,
          cacheExtent: widget.controller._previewExtent,
          itemBuilder: (context, index) {
            int trueIndex = widget.controller._previewReverse
                ? (widget.controller._previewCount - 1 - index)
                : index;
            Widget item =
                widget.itemBuilder(context, trueIndex) ?? const SizedBox();
            widget.controller._previewWidgetList[trueIndex] = item;
            widget.controller._previewKeys[trueIndex] = GlobalKey();
            return Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: HeroMode(
                key: widget.controller._previewKeys[trueIndex],
                enabled: false,
                child: item,
              ),
            );
          },
          padding: widget.padding,
        ),
      ),
    );
  }
}
