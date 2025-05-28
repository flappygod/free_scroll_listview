import 'package:flutter/cupertino.dart';
import 'dart:async';

///preview model
class PreviewModel {
  bool allPreviewed = true;
  double totalHeight = 0;
  Map<int, double> itemHeights = {};
}

/// addition preview controller
class AdditionPreviewController<T> extends ChangeNotifier {
  //preview offset keys
  final Map<int, GlobalKey> _previewKeys = {};

  //preview data list
  final Map<int, Widget> _previewWidgetList = {};

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
  }) {
    //return null if preview is already gone
    if (_offsetPreviewCompleter != null &&
        !_offsetPreviewCompleter!.isCompleted) {
      return Future.delayed(
        const Duration(milliseconds: 0),
        () => null,
      );
    }

    //preview setting
    _previewCount = previewCount;
    _previewExtent = previewExtent;
    _previewReverse = previewReverse;

    _previewKeys.clear();
    _previewWidgetList.clear();
    _offsetPreviewCompleter = Completer();
    notifyListeners();
    return _offsetPreviewCompleter!.future;
  }
}

/// addition preview
class AdditionPreview<T> extends StatefulWidget {
  //controller
  final AdditionPreviewController<T> controller;

  //item builder
  final NullableIndexedWidgetBuilder itemBuilder;

  //padding
  final EdgeInsetsGeometry? padding;

  //margin
  final EdgeInsetsGeometry? margin;

  const AdditionPreview({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.padding,
    this.margin,
  });

  @override
  State<StatefulWidget> createState() {
    return _AdditionPreviewState<T>();
  }
}

/// addition preview state
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

      ///clear preview completer
      widget.controller._offsetPreviewCompleter = null;
      widget.controller._previewCount = 0;
      widget.controller._previewReverse = false;
      widget.controller._previewExtent = 0;
      if (mounted) {
        setState(() {});
      }

      ///complete
      completer.complete(previewModel);
    });
  }

  @override
  Widget build(BuildContext context) {
    _checkPreviewHeight();
    return SizedBox(
      height: 0.01,
      width: double.infinity,
      child: OverflowBox(
        minHeight: MediaQuery.of(context).size.height,
        maxHeight: MediaQuery.of(context).size.height,
        child: ListView.builder(
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
              maintainSemantics: true,
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
