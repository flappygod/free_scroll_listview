import 'package:free_scroll_listview/src/free_scroll_base.dart';
import 'package:flutter/cupertino.dart';
import 'free_scroll_observe.dart';
import 'dart:async';

/// addition preview controller
class AdditionPreviewController<T> extends ChangeNotifier {
  //offset preview global key
  final GlobalKey _offsetPreviewKey = GlobalKey();

  //_data list
  final List<T> _dataList = [];

  //offset preview completer
  Completer<double> _offsetPreviewCompleter = Completer();

  //preview items height
  Future<double> previewItemsHeight(List<T> dataList) {
    _offsetPreviewCompleter = Completer();
    _dataList.clear();
    _dataList.addAll(dataList);
    notifyListeners();
    return _offsetPreviewCompleter.future;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      key: widget.controller._offsetPreviewKey,
      width: double.infinity,
      margin: widget.margin,
      padding: widget.padding,
      height: 0.001,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 0,
        maxHeight: 65535,
        child: ObserveHeightWidget(
          listener: (Size size) {
            if (!widget.controller._offsetPreviewCompleter.isCompleted) {
              widget.controller._offsetPreviewCompleter.complete(size.height);
            }
          },
          child: Visibility(
            visible: false,
            maintainState: true,
            maintainInteractivity: true,
            maintainAnimation: true,
            maintainSemantics: true,
            maintainSize: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.controller._dataList.mapIndexed((index, e) {
                return widget.itemBuilder(context, index) ?? const SizedBox();
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
