import 'package:flutter/cupertino.dart';

typedef ObserveHeightListener = Function(Size height);

///Observe widget height
class ObserveHeightWidget extends StatefulWidget {
  //child
  final Widget child;

  //listener
  final ObserveHeightListener listener;

  const ObserveHeightWidget({
    super.key,
    required this.listener,
    required this.child,
  });

  @override
  State<StatefulWidget> createState() {
    return _ObserveHeightWidgetState();
  }
}

class _ObserveHeightWidgetState extends State<ObserveHeightWidget> {
  //globalKey
  final GlobalKey _observeKey = GlobalKey();

  //addPostFrameCallback
  void _setListener() {
    WidgetsBinding.instance.addPostFrameCallback((mag) {
      widget.listener(_observeKey.currentContext?.size ?? const Size(0, 0));
    });
  }

  @override
  Widget build(BuildContext context) {
    _setListener();
    return SizedBox(
      key: _observeKey,
      child: widget.child,
    );
  }
}
