import 'package:free_scroll_listview/src/free_scroll_observe.dart';
import 'package:free_scroll_listview/src/free_scroll_preview.dart';
import 'package:synchronized/synchronized.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'free_scroll_wrapper.dart';
import 'free_scroll_base.dart';
import 'dart:async';
import 'dart:math';

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
  final Map<int, Rect> _cachedItemRectMap = {};
  final Map<int, Rect> _visibleItemRectMap = {};
  int _visibleItemStamp = 0;

  //header view height
  double _headerViewHeight = 0;

  //negative height total
  double _negativeHeight = 0;

  //global key
  final GlobalKey _listViewKey = GlobalKey();

  //current index
  int _currentIndex = 0;

  //is animating
  bool _isAnimating = false;

  //check is animating
  bool get isAnimating {
    return _isAnimating;
  }

  //get current index
  int get currentIndex {
    return _currentIndex;
  }

  int get visibleItemStamp {
    return _visibleItemStamp;
  }

  ///listview height
  double get listViewHeight {
    RenderBox? box =
        _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.height ?? 0;
  }

  ///listview offset
  double get listViewOffset {
    RenderBox? box =
        _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    Offset? position = box?.localToGlobal(Offset.zero);
    return position?.dy ?? 0;
  }

  ///notify negative height
  void _setHeaderViewHeight(double height) {
    _headerViewHeight = height;
    if (hasClients && position is _NegativedScrollPosition) {
      (position as _NegativedScrollPosition).minScrollExtend =
          _negativeHeight - _headerViewHeight;
    }
  }

  ///set negative height
  void _setNegativeHeight(double height) {
    _negativeHeight = height;
    if (hasClients && position is _NegativedScrollPosition) {
      (position as _NegativedScrollPosition).minScrollExtend =
          _negativeHeight - _headerViewHeight;
    }
  }

  ///remove item on screen
  void removeItemRectOnScreen(int index) {
    _visibleItemRectMap.remove(index);
  }

  ///add anchor item state
  void addItemRectOnScreen(int index, Rect rect) {
    _cachedItemRectMap[index] = rect;
    _visibleItemRectMap[index] = rect;

    ///check when animating
    if (isAnimating) {
      _checkAndResetIndex(animatingMode: true);
    }

    ///set min scroll extend
    if (index == 0) {
      _setNegativeHeight(rect.top);
    }
  }

  ///check and reset index
  bool _checkAndResetIndex({bool animatingMode = true}) {
    ///get max index
    int maxIndex = _positiveDataList.length + _negativeDataList.length - 1;

    ///set max scroll extend
    if (_cachedItemRectMap[maxIndex] != null) {
      ///calculate height test
      double lastScreenOffset = 0;
      int? lastScreenIndex;
      for (int s = maxIndex; s >= 0; s--) {
        final itemHeight = _cachedItemRectMap[s]?.height;
        if (itemHeight == null) {
          return false;
        }
        lastScreenOffset += itemHeight;
        if (lastScreenOffset.round() >= listViewHeight.round()) {
          lastScreenIndex = s;
          break;
        }
      }
      if (lastScreenIndex == null) {
        return false;
      }

      ///current count
      int tempCount = (maxIndex - _positiveDataList.length);

      ///we need to do something
      if (tempCount >= lastScreenIndex) {
        ///we get the offset
        double needChangeOffset = 0;
        for (int s = lastScreenIndex; s <= tempCount; s++) {
          needChangeOffset += (_cachedItemRectMap[s]?.height ?? 0);
        }

        ///change
        if (position.pixels + needChangeOffset > position.maxScrollExtent) {
          return false;
        }

        ///offset changed
        for (int s = 0; s <= (tempCount - lastScreenIndex); s++) {
          _positiveDataList.insert(0, _negativeDataList.last);
          _negativeDataList.removeLast();
        }

        ///we remove all
        _setNegativeHeight(double.negativeInfinity);
        _visibleItemStamp = DateTime.now().millisecondsSinceEpoch;
        _cachedItemRectMap.clear();
        _visibleItemRectMap.clear();

        ///when animating  just correct by and notifyAnimOffset
        if (animatingMode) {
          position.correctBy(needChangeOffset);
          notifyActionListeners(
            FreeScrollListViewActionType.notifyAnimOffset,
            data: needChangeOffset,
          );
        }

        ///when not animating ,use jump to
        else {
          position.jumpTo(position.pixels + needChangeOffset);
        }

        ///setState
        notifyActionListeners(
          FreeScrollListViewActionType.notifyData,
        );

        return true;
      }
    }
    return false;
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
    List<FreeScrollListControllerListener> listeners = List.from(_listeners);
    for (FreeScrollListControllerListener listener in listeners) {
      await listener(event, data: data);
    }
  }

  ///scroll
  FreeScrollListViewController({
    List<T>? dataList,
    double? anchorOffset,
  })  : _positiveDataList = List.from(dataList ?? []),
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
      ///set data if is init
      if (_negativeDataList.isEmpty && _positiveDataList.isEmpty) {
        _setNegativeHeight(0);
        _visibleItemStamp = DateTime.now().millisecondsSinceEpoch;
        _positiveDataList.clear();
        _negativeDataList.clear();
        _cachedItemRectMap.clear();
        _visibleItemRectMap.clear();
        _positiveDataList.addAll(dataList);
        notifyActionListeners(FreeScrollListViewActionType.notifyData);
      }

      ///set data if not init
      else {
        int index = min(_negativeDataList.length, dataList.length);
        List<T> firstList = dataList.sublist(0, index);
        List<T> secondList = firstList.length != dataList.length
            ? dataList.sublist(firstList.length, dataList.length)
            : [];
        _setNegativeHeight(double.negativeInfinity);
        _visibleItemStamp = DateTime.now().millisecondsSinceEpoch;
        _positiveDataList.clear();
        _negativeDataList.clear();
        _cachedItemRectMap.clear();
        _visibleItemRectMap.clear();
        _negativeDataList.addAll(firstList);
        _positiveDataList.addAll(secondList);
        notifyActionListeners(FreeScrollListViewActionType.notifyData);
      }
    });
  }

  ///update data
  void updateData(T t, int index) {
    _lock.synchronized(() {
      ///negative data replace
      if (index < _negativeDataList.length) {
        _negativeDataList[index] = t;
        notifyActionListeners(FreeScrollListViewActionType.notifyData);
        return;
      }

      ///positive data replace
      if (index - _negativeDataList.length < _positiveDataList.length) {
        _positiveDataList[index - _negativeDataList.length] = t;
        notifyActionListeners(FreeScrollListViewActionType.notifyData);
        return;
      }
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
      ///formers
      double formerTopData = _negativeHeight;

      ///insert all data
      _negativeDataList.insertAll(0, dataList);

      ///preview the height and add it to negative height
      if (_negativeHeight != double.negativeInfinity) {
        double previewHeight =
            await _previewController.previewItemsHeight(dataList);

        ///avoid addItemRectOnScreen changed _negativeHeight
        if (formerTopData.round() == _negativeHeight.round()) {
          _negativeHeight -= previewHeight;
          _setNegativeHeight(_negativeHeight);
        }
      }

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
      _setNegativeHeight(double.negativeInfinity);
      _visibleItemStamp = DateTime.now().millisecondsSinceEpoch;
      _negativeDataList.clear();
      _positiveDataList.clear();
      _cachedItemRectMap.clear();
      _visibleItemRectMap.clear();
      _positiveDataList.addAll(dataList);

      ///notify data
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
    return _handleAnimation(animateTo(
      _negativeHeight - _headerViewHeight,
      duration: duration,
      curve: curve,
    ));
  }

  ///jump to top
  void jumpToTop() {
    jumpTo(_negativeHeight - _headerViewHeight);
  }

  ///scroll to max
  Future scrollToBottom({
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeIn,
  }) {
    return _handleAnimation(animateTo(
      position.maxScrollExtent,
      duration: duration,
      curve: curve,
    ));
  }

  ///jump to bottom
  void jumpToBottom() {
    jumpTo(position.maxScrollExtent);
  }

  ///scroll to index
  Future scrollToIndex(
    int index, {
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeIn,
  }) async {
    ///stop the former animations
    await notifyActionListeners(FreeScrollListViewActionType.notifyAnimStop);

    ///get the rect for the index
    Rect? rect = _visibleItemRectMap[index];

    ///if index is exists
    if (rect != null) {
      double toOffset = rect.top + _anchorOffset;
      if (hasClients &&
          position.maxScrollExtent != double.infinity &&
          position.maxScrollExtent != double.maxFinite) {
        toOffset = min(position.maxScrollExtent, toOffset);
      }
      return _handleAnimation(animateTo(
        toOffset,
        duration: duration,
        curve: curve,
      ));
    }

    ///if index is not exists
    else {
      ///get align
      FreeScrollAlign align = FreeScrollAlign.topToBottom;
      List<int> keys = _visibleItemRectMap.keys.toList();
      keys.sort((one, two) {
        return one.compareTo(two);
      });

      if (keys.isEmpty) {
        return Future.delayed(Duration.zero);
      }

      ///keys
      double pixels = position.pixels;
      int currentIndex = keys.first;
      for (int key in _visibleItemRectMap.keys) {
        Rect? rect = _visibleItemRectMap[key];
        if (rect == null) {
          continue;
        }
        double offsetTop = rect.top - pixels;
        double offsetBottom = rect.bottom - pixels;
        if (offsetTop.round() <= 0 && offsetBottom.round() > 0) {
          currentIndex = key;
        }
      }

      if (index < currentIndex) {
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
    //Initialize lists for negative and positive data
    List<T> newNegativeList = dataList.sublist(0, index);
    List<T> newPositiveList = dataList.sublist(index);

    //Clear existing data and cached maps
    _setNegativeHeight(double.negativeInfinity);
    _visibleItemStamp = DateTime.now().millisecondsSinceEpoch;
    _negativeDataList.clear();
    _positiveDataList.clear();
    _cachedItemRectMap.clear();
    _visibleItemRectMap.clear();

    //Add new data to respective lists
    _negativeDataList.addAll(newNegativeList);
    _positiveDataList.addAll(newPositiveList);

    ///refresh
    notifyActionListeners(FreeScrollListViewActionType.notifyData);

    switch (align) {
      case FreeScrollAlign.bottomToTop:
        AnimationData data = AnimationData(
          duration,
          curve,
          listViewHeight + _anchorOffset,
          0 + _anchorOffset,
          FreeScrollAlign.bottomToTop,
        );
        return _handleAnimation(notifyActionListeners(
          FreeScrollListViewActionType.notifyAnimStart,
          data: data,
        ));
      case FreeScrollAlign.topToBottom:
        AnimationData data = AnimationData(
          duration,
          curve,
          -listViewHeight + _anchorOffset,
          0 + _anchorOffset,
          FreeScrollAlign.topToBottom,
        );
        return _handleAnimation(notifyActionListeners(
          FreeScrollListViewActionType.notifyAnimStart,
          data: data,
        ));
      case FreeScrollAlign.directJumpTo:
        jumpTo(0);
        return notifyActionListeners(
          FreeScrollListViewActionType.notifyJump,
        );
    }
  }

  ///handler animation
  Future _handleAnimation(Future futureFunction) async {
    _isAnimating = true;
    return futureFunction.whenComplete(() {
      _isAnimating = false;
      notifyActionListeners(
        FreeScrollListViewActionType.notifyJump,
      );
    });
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

  ///item show
  final FreeScrollOnItemShow? onItemShow;

  ///index changed
  final FreeScrollOnIndexChange? onIndexChange;

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
    this.onItemShow,
    this.onIndexChange,
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
        case FreeScrollListViewActionType.notifyAnimStart:
          await _startAnimation(data);
          break;

        ///stop animation
        case FreeScrollListViewActionType.notifyAnimStop:
          _cancelAnimation();
          break;

        ///start animation
        case FreeScrollListViewActionType.notifyAnimOffset:
          _animationOffset = data;
          break;

        ///start animation
        case FreeScrollListViewActionType.notifyJump:
          Future.delayed(const Duration(milliseconds: 80)).then((_) {
            _notifyIndex();
            _notifyOnShow();
          });
          break;
      }
    };
    widget.controller.addActionListener(_listener);
  }

  ///start animation
  Future _startAnimation(AnimationData data) {
    _cancelAnimation();

    ///completer
    Completer completer = Completer();

    ///Define a custom animation from start to end
    AnimationController animationController = AnimationController(
      duration: data.duration,
      vsync: this,
    );

    ///add status listener
    animationController.addStatusListener((status) {
      if (!animationController.isAnimating) {
        completer.complete();
      }
    });

    /// Define a CurvedAnimation with the desired curve
    CurvedAnimation curvedAnimation = CurvedAnimation(
      parent: animationController,
      curve: data.curve,
    );

    ///new animation
    Animation<double> animation = Tween<double>(
      begin: data.startPosition,
      end: data.endPosition,
    ).animate(curvedAnimation);
    animation.addListener(() {
      ///controller
      if (animationController != _animationController ||
          !widget.controller.hasClients ||
          !widget.controller.position.hasPixels) {
        return;
      }

      ///set offset
      double offsetTo = animation.value + _animationOffset;

      ///max scroll extend
      double maxScrollExtent = widget.controller.position.maxScrollExtent;

      ///check max scroll extend
      if (offsetTo <= maxScrollExtent &&
          widget.controller.hasClients &&
          widget.controller.position.hasPixels) {
        widget.controller.position.jumpTo(offsetTo);
        return;
      }

      ///only top to bottom need this
      int maxIndex = widget.controller._positiveDataList.length +
          widget.controller._negativeDataList.length -
          1;
      if (data.align == FreeScrollAlign.topToBottom &&
          offsetTo > maxScrollExtent &&
          maxScrollExtent != double.infinity &&
          maxScrollExtent != double.maxFinite &&
          widget.controller.hasClients &&
          widget.controller.position.hasPixels &&
          widget.controller._visibleItemRectMap[maxIndex] != null &&
          widget.controller._visibleItemRectMap[maxIndex]!.bottom >=
              maxScrollExtent) {
        widget.controller.position.jumpTo(maxScrollExtent);
      }
    });

    ///start animation
    animationController.forward(from: 0);

    ///set animation and controller
    _animationController = animationController;

    return completer.future;
  }

  ///cancel animation
  void _cancelAnimation() {
    if (_animationController?.isAnimating ?? false) {
      _animationController?.stop();
      _animationController?.reset();
      _animationController?.dispose();
      _animationController = null;
    }
    _animationOffset = 0;
  }

  ///init height
  void _initHeight() {
    ///get height
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 80)).then((_) {
        _notifyIndex();
        _notifyOnShow();
      });
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
    _cancelAnimation();
    widget.controller.removeActionListener(_listener);
  }

  @override
  Widget build(BuildContext context) {
    ///get direction
    AxisDirection axisDirection = _getDirection(context);
    return NotificationListener<ScrollNotification>(
      onNotification: _handleNotification,
      child: Scrollable(
        key: widget.controller._listViewKey,
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
                              actualIndex: actualIndex,
                              listViewState: this,
                              controller: widget.controller,
                              visibleRectStamp:
                                  widget.controller._visibleItemStamp,
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
                              actualIndex: actualIndex,
                              listViewState: this,
                              controller: widget.controller,
                              visibleRectStamp:
                                  widget.controller._visibleItemStamp,
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

    ///动画过程中不需要处理
    ///bool isAnimating = _animationController?.isAnimating ?? false;
    if (widget.controller.isAnimating) {
      return false;
    }

    ///滚动结束的时候检查是否到达最大
    if (notification is ScrollEndNotification) {
      widget.controller._checkAndResetIndex(
        animatingMode: false,
      );
    }

    ///通知消息被展示
    if (notification is ScrollEndNotification) {
      _notifyOnShow();
    }

    ///通知Index
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _notifyIndex();
    }

    return false;
  }

  ///notify current on show
  void _notifyOnShow() {
    if (!mounted) {
      return;
    }

    if (widget.onItemShow != null) {
      ///item show
      List<int> keys = [];

      ///listview height
      double listViewHeight = widget.controller.listViewHeight;

      ///keys
      for (int key in widget.controller._visibleItemRectMap.keys) {
        Rect? rect = widget.controller._visibleItemRectMap[key];
        if (rect == null) {
          continue;
        }

        ///offset top
        double offsetTop = rect.top - widget.controller.position.pixels;
        double offsetBottom = rect.bottom - widget.controller.position.pixels;

        ///Listview height
        if ((offsetTop >= 0 && offsetBottom <= listViewHeight) ||
            offsetTop <= 0 && offsetBottom >= listViewHeight) {
          keys.add(key);
        }
      }

      ///keys data
      if (keys.isNotEmpty) {
        widget.onItemShow!(keys);
      }
    }
  }

  ///notify index if changed
  void _notifyIndex() {
    if (!mounted) {
      return;
    }

    ///offset count
    double pixels = widget.controller.position.pixels;

    ///keys
    List<dynamic> sortedKeys =
        widget.controller._visibleItemRectMap.keys.toList()..sort();
    for (int key in sortedKeys) {
      Rect? rect = widget.controller._visibleItemRectMap[key];
      if (rect == null) {
        continue;
      }

      ///offset top
      double offsetBottom = rect.bottom - pixels;

      ///Listview height
      if (offsetBottom.round() > 0) {
        int index = key;
        if (widget.controller._currentIndex != index) {
          widget.controller._currentIndex = index;
          if (widget.onIndexChange != null) {
            widget.onIndexChange!(index);
          }
        }
        break;
      }
    }
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
  double _minScrollExtend = double.negativeInfinity;

  ///callback
  late VoidCallback _callback;

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
    _callback = () {
      if (hasPixels &&
          _minScrollExtend != double.negativeInfinity &&
          pixels < _minScrollExtend - 100) {
        jumpTo(_minScrollExtend - 100);
      }
    };
    removeListener(_callback);
    addListener(_callback);
  }

  ///force negative pixels
  void _forceNegativePixels(double offset) {
    if (hasPixels && hasContentDimensions) {
      super.forcePixels(-offset);
    }
  }

  @override
  double get minScrollExtent => _minScrollExtend;
}
