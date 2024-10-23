import 'package:free_scroll_listview/src/free_scroll_observe.dart';
import 'package:free_scroll_listview/src/free_scroll_preview.dart';
import 'package:synchronized/synchronized.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'free_scroll_wrapper.dart';
import 'free_scroll_base.dart';
import 'dart:async';

///addition controller
typedef FreeScrollListControllerListener = Future Function(
  FreeScrollListViewActionType type, {
  dynamic data,
});

///free scroll listview controller
class FreeScrollListViewController<T> extends ScrollController {
  //lock
  final Lock _lock = Lock();

  //positive data list
  final List<T> _positiveDataList;

  //negative data list
  final List<T> _negativeDataList;

  //anchor offset
  final double _anchorOffset;

  //listeners
  final List<FreeScrollListControllerListener> _listeners = [];

  //controller
  final AdditionPreviewController<T> _previewController =
      AdditionPreviewController<T>();

  //item maps
  final Map<int, Rect> _relativeItemMap = {};

  //header view height
  double _headerViewHeight = 0;

  //negative height total
  double _negativeHeight = 0;

  //list view height
  double _listViewHeight = 0;

  //list view offset
  double _listViewOffset = 0;

  ///get height
  double get listViewHeight {
    return _listViewHeight;
  }

  ///get offset
  double get listViewOffset {
    return _listViewOffset;
  }

  //set list view height
  void _setListViewHeight(double height) {
    _listViewHeight = height;
  }

  //set list view offset
  void _setListViewOffset(double offset) {
    _listViewOffset = offset;
  }

  ///notify negative height
  void _setHeaderViewHeight(double height) {
    _headerViewHeight = height;
    //position negative scroll position
    if (position is _NegativedScrollPosition) {
      (position as _NegativedScrollPosition).minScrollExtend =
          _negativeHeight - _headerViewHeight;
    }
  }

  ///set negative height
  void _setNegativeHeight(double height) {
    _negativeHeight = height;
    //position negative scroll position
    if (position is _NegativedScrollPosition) {
      (position as _NegativedScrollPosition).minScrollExtend =
          _negativeHeight - _headerViewHeight;
    }
  }

  ///add anchor item state
  void addAnchorItemState(int index, Rect rect) {
    _relativeItemMap[index] = rect;

    ///set min scroll extend
    if (index == -_negativeDataList.length) {
      _setNegativeHeight(rect.top);
    }

    ///set max scroll extend
    if (index == _positiveDataList.length - 1) {
      ///calculate height test
      double lastScreenOffset = 0;
      int? lastScreenIndex;
      for (int s = index; s > -_negativeDataList.length; s--) {
        lastScreenOffset += (_relativeItemMap[s]?.height ?? 0);
        if (lastScreenOffset > _listViewHeight) {
          lastScreenIndex = s;
          break;
        }
      }

      ///all of item not longer than listview height
      if (lastScreenIndex == null) {
        return;
      }

      ///we need to do something
      if (lastScreenIndex < 0) {
        ///we get the offset
        double needChangeOffset = 0;
        for (int s = lastScreenIndex; s < 0; s++) {
          needChangeOffset += (_relativeItemMap[s]?.height ?? 0);
        }

        ///offset changed
        for (int s = 0; s < -lastScreenIndex; s++) {
          _positiveDataList.insert(0, _negativeDataList.last);
          _negativeDataList.removeLast();
        }
        offsetRectList(_relativeItemMap, needChangeOffset);

        ///jump to new offset
        jumpTo(position.pixels + needChangeOffset);

        ///set offset for animation
        notifyActionListeners(
          FreeScrollListViewActionType.notifyAnimOffset,
          data: needChangeOffset,
        );

        ///setState
        notifyActionListeners(
          FreeScrollListViewActionType.notifyData,
        );
      }
    }
  }

  ///remove anchor item state
  void removeAnchorItemState(int index) {
    _relativeItemMap.remove(index);
  }

  ///add listener
  void addActionListener(FreeScrollListControllerListener listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  ///remove listener
  bool removeActionListener(FreeScrollListControllerListener listener) {
    return _listeners.remove(listener);
  }

  ///notify listeners
  Future<void> notifyActionListeners(
    FreeScrollListViewActionType event, {
    dynamic data,
  }) async {
    for (FreeScrollListControllerListener listener in _listeners) {
      await listener(event, data: data);
    }
  }

  ///scroll
  FreeScrollListViewController({
    List<T>? dataList,
    double? anchorOffset,
  })  : _positiveDataList = dataList ?? [],
        _negativeDataList = [],
        _anchorOffset = anchorOffset ?? 0;

  ///data list
  List<T> get dataList {
    return [
      ..._negativeDataList,
      ..._positiveDataList,
    ];
  }

  ///set data list
  set dataList(List<T> dataList) {
    _lock.synchronized(() {
      _negativeHeight = 0;
      _positiveDataList.clear();
      _negativeDataList.clear();
      _positiveDataList.addAll(dataList);
      notifyActionListeners(FreeScrollListViewActionType.notifyData);
    });
  }

  ///add data to tail
  Future addDataToTail(List<T> dataList) {
    return _lock.synchronized(() async {
      _positiveDataList.addAll(dataList);
      await notifyActionListeners(FreeScrollListViewActionType.notifyData);
    });
  }

  ///add data to head
  Future addDataToHead(List<T> dataList) {
    return _lock.synchronized(() async {
      ///insert all data
      _negativeDataList.insertAll(0, dataList);

      ///preview the height and add it to negative height
      double previewHeight =
          await _previewController.previewItemsHeight(dataList);
      _negativeHeight -= previewHeight;
      _setNegativeHeight(_negativeHeight);

      ///notify data
      await notifyActionListeners(FreeScrollListViewActionType.notifyData);
    });
  }

  ///set data and scroll to
  Future setDataAndScrollTo(
    List<T> dataList, {
    int index = 0,
    FreeScrollAlign align = FreeScrollAlign.bottomToTop,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeIn,
  }) {
    return _lock.synchronized(() async {
      ///insert all data
      _negativeDataList.clear();
      _positiveDataList.clear();
      _positiveDataList.addAll(dataList);

      ///notify data
      await notifyActionListeners(FreeScrollListViewActionType.notifyData);
      await scrollToIndexSkipAlign(
        index,
        align: align,
        curve: curve,
        duration: duration,
      );
    });
  }

  ///scroll to top
  Future scrollToTop({
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeIn,
  }) {
    return animateTo(
      _negativeHeight,
      duration: duration,
      curve: curve,
    );
  }

  ///scroll to max
  Future scrollToBottom({
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeIn,
  }) {
    return animateTo(
      position.maxScrollExtent,
      duration: duration,
      curve: curve,
    );
  }

  ///scroll to index
  Future scrollToIndex(
    int index, {
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeIn,
  }) {
    int relativeIndex = index - _negativeDataList.length;
    Rect? rect = _relativeItemMap[relativeIndex];

    ///if index is exists
    if (rect != null) {
      return animateTo(
        rect.top + _anchorOffset,
        duration: duration,
        curve: curve,
      );
    }

    ///if index is not exists
    else {
      ///get align
      FreeScrollAlign align = FreeScrollAlign.topToBottom;
      List<int> keys = _relativeItemMap.keys.toList();
      keys.sort((one, two) {
        return one.compareTo(two);
      });
      if (relativeIndex < keys.first) {
        align = FreeScrollAlign.bottomToTop;
      } else {
        align = FreeScrollAlign.topToBottom;
      }

      return scrollToIndexSkipAlign(
        index,
        align: align,
        curve: curve,
        duration: duration,
      );
    }
  }

  ///scroll to index just by align
  Future scrollToIndexSkipAlign(
    int index, {
    required FreeScrollAlign align,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeIn,
  }) {
    ///total data list
    List<T> totalList = dataList;
    List<T> newNegativeList = [];
    List<T> newPositiveList = [];
    for (int s = 0; s < totalList.length; s++) {
      if (s < index) {
        newNegativeList.add(totalList[s]);
      } else {
        newPositiveList.add(totalList[s]);
      }
    }

    ///_negativeHeight
    _setNegativeHeight(double.negativeInfinity);

    ///negative
    _negativeDataList.clear();
    _negativeDataList.addAll(newNegativeList);

    ///positive
    _positiveDataList.clear();
    _positiveDataList.addAll(newPositiveList);

    ///clear data
    _relativeItemMap.clear();

    ///refresh
    notifyActionListeners(FreeScrollListViewActionType.notifyData);

    switch (align) {
      case FreeScrollAlign.bottomToTop:
        {
          AnimationData data = AnimationData(
            duration,
            _listViewHeight + _anchorOffset,
            0 + _anchorOffset,
          );
          return notifyActionListeners(
            FreeScrollListViewActionType.notifyAnim,
            data: data,
          );
        }
      case FreeScrollAlign.topToBottom:
        {
          AnimationData data = AnimationData(
            duration,
            -_listViewHeight + _anchorOffset,
            0 + _anchorOffset,
          );
          return notifyActionListeners(
            FreeScrollListViewActionType.notifyAnim,
            data: data,
          );
        }
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _NegativedScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

///free scroll listview
class FreeScrollListView<T> extends StatefulWidget {
  ///controller
  final FreeScrollListViewController<T> controller;

  ///builder
  final NullableIndexedWidgetBuilder builder;

  /// See: [ScrollView.physics]
  final ScrollPhysics physics;

  ///direction
  final Axis scrollDirection;

  /// See:[ScrollView.reverse]
  final bool reverse;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.hardEdge].
  ///
  /// This is passed to decorators in [ScrollableDetails], and does not directly affect
  /// clipping of the [Scrollable]. This reflects the same [Clip] that is provided
  /// to [ScrollView.clipBehavior] and is supplied to the [Viewport].
  final Clip clipBehavior;

  /// See: [ScrollView.cacheExtent]
  final double? cacheExtent;

  ///load next offset
  final double loadOffset;

  ///will reach top
  final WillReachCallback? willReachHead;

  ///will reach bottom
  final WillReachCallback? willReachTail;

  ///header view
  final Widget? headerView;

  ///footer view
  final Widget? footerView;

  const FreeScrollListView({
    super.key,
    required this.controller,
    required this.builder,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.clipBehavior = Clip.hardEdge,
    this.cacheExtent,
    this.loadOffset = 100,
    this.willReachHead,
    this.willReachTail,
    this.headerView,
    this.footerView,
  });

  @override
  State<StatefulWidget> createState() {
    return FreeScrollListViewState<T>();
  }
}

///free scroll listview state
class FreeScrollListViewState<T> extends State<FreeScrollListView>
    with TickerProviderStateMixin {
  ///function listener
  late FreeScrollListControllerListener _listener;

  ///time stamp debouncer
  final TimeStampDebouncer _timeStampDebouncer = TimeStampDebouncer();

  ///animation controller and offset
  AnimationController? _animationController;
  Animation<double>? _animation;
  double _animationOffset = 0;

  ///init listener
  void _initListener() {
    _listener = (
      FreeScrollListViewActionType event, {
      dynamic data,
    }) async {
      switch (event) {
        ///set state
        case FreeScrollListViewActionType.notifyData:
          if (mounted) {
            setState(() {});
          }
          break;

        ///start animation
        case FreeScrollListViewActionType.notifyAnim:
          _startAnimation(data);
          break;

        ///start animation
        case FreeScrollListViewActionType.notifyAnimOffset:
          _animationOffset = data;
          break;
      }
    };
    widget.controller.addActionListener(_listener);
  }

  ///start animation
  void _startAnimation(AnimationData data) {
    _cancelAnimation();

    ///Define a custom animation from start to end
    _animationController = AnimationController(
      duration: data.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: data.startPosition,
      end: data.endPosition,
    ).animate(_animationController!)
      ..addListener(() {
        if (_animation?.value != null) {
          widget.controller.position.jumpTo(
            _animation!.value + _animationOffset,
          );
        }
      });

    ///start animation
    _animationController?.forward(from: 0);
  }

  ///cancel animation
  void _cancelAnimation() {
    if (_animationController?.isAnimating ?? false) {
      _animationController?.stop();
    }
    _animationOffset = 0;
  }

  ///dispose animation
  void _disposeAnimation() {
    if (_animationController?.isAnimating ?? false) {
      _animationController?.stop();
      _animationController?.dispose();
    }
    _animationOffset = 0;
  }

  ///init height
  void _initHeight() {
    ///get height
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      RenderBox? listBox = context.findRenderObject() as RenderBox?;
      Offset? offsetList = listBox?.localToGlobal(const Offset(0.0, 0.0));
      if (listBox != null) {
        widget.controller._setListViewHeight(listBox.size.height);
      }
      if (offsetList != null) {
        widget.controller._setListViewOffset(offsetList.dy);
      }
    });
  }

  @override
  void initState() {
    _initListener();
    _initHeight();
    super.initState();
  }

  @override
  void didUpdateWidget(FreeScrollListView oldWidget) {
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeActionListener(_listener);
      widget.controller.addActionListener(_listener);
    }
    _initHeight();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
    _disposeAnimation();
    widget.controller.removeActionListener(_listener);
  }

  @override
  Widget build(BuildContext context) {
    ///get direction
    AxisDirection axisDirection = _getDirection(context);
    return NotificationListener<ScrollNotification>(
      onNotification: _handleNotification,
      child: Scrollable(
        axisDirection: axisDirection,
        controller: widget.controller,
        physics: widget.physics,
        clipBehavior: widget.clipBehavior,
        viewportBuilder: (BuildContext context, ViewportOffset offset) {
          return Builder(
            builder: (context) {
              ///Build negative [ScrollPosition] for the negative scrolling [Viewport].
              final ScrollableState state = Scrollable.of(context);
              final _NegativedScrollPosition negativeOffset =
                  _NegativedScrollPosition(
                physics: widget.physics,
                context: state,
                initialPixels: -offset.pixels,
                keepScrollOffset: false,
              );

              ///Keep the negative scrolling [Viewport] positioned to the [ScrollPosition].
              offset.addListener(() {
                negativeOffset._forceNegativePixels(offset.pixels);
              });

              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  ///preview items widget
                  AdditionPreview(
                    itemBuilder: widget.builder,
                    controller: widget.controller._previewController,
                  ),

                  ///negative
                  Viewport(
                    axisDirection: flipAxisDirection(axisDirection),
                    anchor: 1.0,
                    offset: negativeOffset,
                    cacheExtent: widget.cacheExtent,
                    slivers: <Widget>[
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            int actualIndex =
                                widget.controller._negativeDataList.length -
                                    index -
                                    1;
                            return AnchorItemWrapper(
                              reverse: widget.reverse,
                              relativeIndex: -index - 1,
                              listViewState: this,
                              controller: widget.controller,
                              child: widget.builder(context, actualIndex),
                            );
                          },
                          childCount:
                              widget.controller._negativeDataList.length,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: ObserveHeightWidget(
                          child: widget.headerView ?? const SizedBox(),
                          listener: (size) {
                            widget.controller._setHeaderViewHeight(size.height);
                          },
                        ),
                      ),
                    ],
                  ),

                  ///positive data list
                  Viewport(
                    offset: offset,
                    axisDirection: axisDirection,
                    cacheExtent: widget.cacheExtent,
                    clipBehavior: widget.clipBehavior,
                    slivers: <Widget>[
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            int actualIndex =
                                widget.controller._negativeDataList.length +
                                    index;
                            return AnchorItemWrapper(
                              reverse: widget.reverse,
                              relativeIndex: index,
                              listViewState: this,
                              controller: widget.controller,
                              child: widget.builder(context, actualIndex),
                            );
                          },
                          childCount:
                              widget.controller._positiveDataList.length,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: widget.footerView,
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  ///handle notification
  bool _handleNotification(ScrollNotification notification) {
    ///cancel animation if need
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _cancelAnimation();
    }

    ///加载之前的消息，FormerMessages
    if (notification.metrics.pixels >=
        (notification.metrics.maxScrollExtent - widget.loadOffset)) {
      _timeStampDebouncer.run(widget.willReachTail);
    }

    ///加载新的消息
    if (notification.metrics.pixels <=
        (widget.controller._negativeHeight + widget.loadOffset)) {
      _timeStampDebouncer.run(widget.willReachHead);
    }

    return false;
  }

  ///get direction for this view
  AxisDirection _getDirection(BuildContext context) {
    return getAxisDirectionFromAxisReverseAndDirectionality(
      context,
      widget.scrollDirection,
      widget.reverse,
    );
  }
}

///negatived scroll position
class _NegativedScrollPosition extends ScrollPositionWithSingleContext {
  ///min scroll extend
  double _minScrollExtend = 0;

  _NegativedScrollPosition({
    required super.physics,
    required super.context,
    double super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  ///set min scroll extend
  set minScrollExtend(double data) {
    _minScrollExtend = data;
  }

  ///force negative pixels
  void _forceNegativePixels(double offset) {
    super.forcePixels(-offset);
  }

  @override
  double get minScrollExtent => _minScrollExtend;
}
