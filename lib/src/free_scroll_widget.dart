import 'package:free_scroll_listview/src/free_scroll_observe.dart';
import 'package:free_scroll_listview/src/free_scroll_preview.dart';
import 'package:synchronized/synchronized.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'free_scroll_wrapper.dart';
import 'free_scroll_base.dart';
import 'dart:async';
import 'dart:math';

///addition controller
typedef FreeScrollListASyncListener = Future Function(
  FreeScrollListViewActionType type, {
  dynamic data,
});

///addition controller
typedef FreeScrollListSyncListener = void Function(
  FreeScrollListViewActionType type, {
  dynamic data,
});

///use a negative value for min scroll
const double negativeInfinityValue = -100000000.0;

///free scroll listview controller
class FreeScrollListViewController<T> extends ScrollController {
  //lock
  final Lock _lock = Lock();

  //data list
  final List<T> _dataList;

  //data list offset
  int _dataListOffset;

  //anchor offset
  final double _anchorOffset;

  //listeners
  final List<FreeScrollListSyncListener> _syncListeners = [];

  //listeners
  final List<FreeScrollListASyncListener> _asyncListeners = [];

  //check rect listeners
  final List<VoidCallback> _checkRectListeners = [];

  //controller
  final AdditionPreviewController<T> _previewController =
      AdditionPreviewController<T>();

  //item maps
  final Map<int, RectHolder> _itemsRectHolder = {};

  //header view height
  double _headerViewHeight = 0;

  //negative height total
  double _negativeHeight = negativeInfinityValue;

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

  /// ListView height
  double get listViewHeight {
    final box = _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.height ?? 0.0;
  }

  /// ListView offset
  double get listViewOffset {
    final box = _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero).dy ?? 0.0;
  }

  /// Notify negative height
  void _setHeaderViewHeight(double height) {
    _headerViewHeight = height.removeTinyFraction();
    if (hasClients && position is _NegativedScrollPosition) {
      final negativedPosition = position as _NegativedScrollPosition;
      if (_negativeHeight == negativeInfinityValue) {
        negativedPosition.minScrollExtend = _negativeHeight;
      } else {
        negativedPosition.minScrollExtend =
            (_negativeHeight - _headerViewHeight).removeTinyFraction();
      }
    }
  }

  ///correct negative height
  void _correctNegativeHeight(double height) {
    if (_negativeHeight != negativeInfinityValue) {
      _setNegativeHeight(_negativeHeight + height);
    }
  }

  /// Set negative height
  void _setNegativeHeight(double height) {
    _negativeHeight = height.removeTinyFraction();
    if (hasClients && position is _NegativedScrollPosition) {
      final negativedPosition = position as _NegativedScrollPosition;
      if (_negativeHeight == negativeInfinityValue) {
        negativedPosition.minScrollExtend = _negativeHeight;
      } else {
        negativedPosition.minScrollExtend =
            (_negativeHeight - _headerViewHeight).removeTinyFraction();
      }
    }
  }

  ///add anchor item state
  void notifyItemRectShowOnScreen(int index) {
    ///check when animating
    if (isAnimating) {
      _resetIndexInAnimate();
    }

    ///if is first, set negative height
    if (index == 0) {
      RectHolder? holder = _itemsRectHolder[0];
      if (holder != null && holder.isOnScreen) {
        _setNegativeHeight(holder.rectTop()!);

        ///when delete some item
        if (!position.isScrollingNotifier.value &&
            !isAnimating &&
            position.pixels < holder.rectTop()!) {
          position.jumpTo(position.pixels);
        }
      }
    }

    ///else check the 0 holder top is min
    else {
      RectHolder? holderCurrent = _itemsRectHolder[index];
      RectHolder? holderFirst = _itemsRectHolder[0];
      _NegativedScrollPosition? currentPosition =
          position as _NegativedScrollPosition?;
      if (holderCurrent != null &&
          holderCurrent.rectTop() != null &&
          holderCurrent.isOnScreen &&
          currentPosition != null &&
          currentPosition.minScrollExtent > holderCurrent.rectTop()!) {
        if (holderFirst != null) {
          _setNegativeHeight(
              min(holderCurrent.rectTop()!, holderFirst.rectTop()!));
        } else {
          _setNegativeHeight(negativeInfinityValue);
        }
      }
    }
  }

  ///remove rect on screen
  void notifyItemRectRemoveOnScreen(int index) {
    if (index == 0) {
      _setNegativeHeight(negativeInfinityValue);
    }
  }

  ///reset index when animating
  void _resetIndexInAnimate() {
    int maxIndex = dataList.length - 1;
    double currentListViewHeight = listViewHeight;
    double lastScreenHeight = 0;
    int? lastScreenIndex;

    ///calculate the last screen index
    for (int s = maxIndex; s >= 0; s--) {
      final double? itemHeight = _itemsRectHolder[s]?.rectHeight();
      if (itemHeight == null) {
        return;
      }
      lastScreenHeight += itemHeight;
      if (lastScreenHeight >= currentListViewHeight) {
        lastScreenIndex = s;
        break;
      }
    }
    if (lastScreenIndex == null) {
      return;
    }

    ///do not need to reset index
    int tempCount = _dataListOffset;
    if (tempCount <= lastScreenIndex) {
      return;
    }

    ///calculate the offset needed to reset the index
    double needChangeOffset = 0;
    for (int s = lastScreenIndex; s < tempCount; s++) {
      final itemHeight = _itemsRectHolder[s]?.rectHeight();
      if (itemHeight == null) {
        return;
      }
      needChangeOffset += itemHeight;
    }
    if (position.pixels < position.minScrollExtent + needChangeOffset) {
      return;
    }

    ///reset index and update state
    _dataListOffset = lastScreenIndex;
    _itemsRectHolder.clear();
    _correctNegativeHeight(needChangeOffset);
    notifyActionSyncListeners(
      FreeScrollListViewActionType.notifyAnimOffset,
      data: needChangeOffset,
    );
    notifyActionSyncListeners(FreeScrollListViewActionType.notifyData);
    position.correctBy(needChangeOffset);
  }

  ///can scroll
  void _resetIndexIfNeeded() {
    int maxIndex = dataList.length - 1;
    double currentListViewHeight = listViewHeight;
    double lastScreenHeight = 0;
    int? lastScreenIndex;

    ///calculate the last screen index
    for (int s = maxIndex; s >= 0; s--) {
      final double? itemHeight = _itemsRectHolder[s]?.rectHeight();
      if (itemHeight == null) {
        return;
      }
      lastScreenHeight += itemHeight;
      if (lastScreenHeight >= currentListViewHeight) {
        lastScreenIndex = s;
        break;
      }
    }
    lastScreenIndex ??= 0;

    ///do not need to reset index
    int tempCount = _dataListOffset;
    if (tempCount <= lastScreenIndex) {
      return;
    }

    ///calculate the offset needed to reset the index
    double needChangeOffset = 0;
    for (int s = lastScreenIndex; s < tempCount; s++) {
      final itemHeight = _itemsRectHolder[s]?.rectHeight();
      if (itemHeight == null) {
        return;
      }
      needChangeOffset += itemHeight;
    }

    ///reset index and update state
    _dataListOffset = lastScreenIndex;
    _itemsRectHolder.clear();
    _correctNegativeHeight(needChangeOffset);
    notifyActionSyncListeners(
      FreeScrollListViewActionType.notifyAnimOffset,
      data: needChangeOffset,
    );
    notifyActionSyncListeners(FreeScrollListViewActionType.notifyData);
    position.jumpTo(position.pixels + needChangeOffset);
  }

  ///add check rect listener
  void addCheckRectListener(VoidCallback listener) {
    if (!_checkRectListeners.contains(listener)) {
      _checkRectListeners.add(listener);
    }
  }

  ///remove check rect listener
  bool removeCheckRectListener(VoidCallback listener) {
    return _checkRectListeners.remove(listener);
  }

  ///add listener
  void addSyncActionListener(FreeScrollListSyncListener listener) {
    if (!_syncListeners.contains(listener)) {
      _syncListeners.add(listener);
    }
  }

  ///remove listener
  bool removeSyncActionListener(FreeScrollListSyncListener listener) {
    return _syncListeners.remove(listener);
  }

  ///add listener
  void addASyncActionListener(FreeScrollListASyncListener listener) {
    if (!_asyncListeners.contains(listener)) {
      _asyncListeners.add(listener);
    }
  }

  ///remove listener
  bool removeASyncActionListener(FreeScrollListASyncListener listener) {
    return _asyncListeners.remove(listener);
  }

  ///notify check rect listeners
  void notifyCheckRectListeners() {
    List<VoidCallback> listeners = List.from(_checkRectListeners);
    for (VoidCallback listener in listeners) {
      listener();
    }
  }

  ///notify listeners
  void notifyActionSyncListeners(
    FreeScrollListViewActionType event, {
    dynamic data,
  }) async {
    List<FreeScrollListSyncListener> listeners = List.from(_syncListeners);
    for (FreeScrollListSyncListener listener in listeners) {
      listener(event, data: data);
    }
  }

  ///notify listeners
  Future<void> notifyActionASyncListeners(
    FreeScrollListViewActionType event, {
    dynamic data,
  }) async {
    List<FreeScrollListASyncListener> listeners = List.from(_asyncListeners);
    for (FreeScrollListASyncListener listener in listeners) {
      await listener(event, data: data);
    }
  }

  ///scroll
  FreeScrollListViewController({
    List<T>? dataList,
    double? anchorOffset,
    int index = 0,
  })  : _dataList = List.from(dataList ?? []),
        _dataListOffset = index,
        _anchorOffset = anchorOffset ?? 0;

  ///data list
  List<T> get dataList {
    return List.from(_dataList);
  }

  ///set data list
  set dataList(List<T> dataList) {
    ///set data if not init
    if (_dataList.isEmpty) {
      _setNegativeHeight(0);
      _itemsRectHolder.clear();
      _dataList.clear();
      _dataList.addAll(dataList);
      _dataListOffset = 0;
      notifyActionSyncListeners(FreeScrollListViewActionType.notifyData);
    }

    ///set data if is init
    else {
      _setNegativeHeight(negativeInfinityValue);
      _itemsRectHolder.clear();
      _dataList.clear();
      _dataList.addAll(dataList);
      _dataListOffset = min(_dataListOffset, dataList.length);
      notifyActionSyncListeners(FreeScrollListViewActionType.notifyData);
    }
  }

  ///update data
  void updateData(T t, int index) {
    assert(index >= 0 && index < dataList.length);
    _dataList[index] = t;
    notifyActionSyncListeners(FreeScrollListViewActionType.notifyData);
  }

  ///add data to tail
  Future<void> addDataToTail(List<T> dataList) {
    return _lock.synchronized(() async {
      _dataList.addAll(dataList);
      notifyActionSyncListeners(FreeScrollListViewActionType.notifyData);
    });
  }

  ///add data to head
  Future<void> addDataToHead(List<T> dataList) {
    return _lock.synchronized(() async {
      ///formers
      double formerTopData = _negativeHeight;

      ///insert all data
      _dataList.insertAll(0, dataList);
      _dataListOffset = _dataListOffset + dataList.length;

      ///preview the height and add it to negative height
      if (_negativeHeight != negativeInfinityValue) {
        double previewHeight =
            await _previewController.previewItemsHeight(dataList);

        ///avoid addItemRectOnScreen changed _negativeHeight
        if (formerTopData.round() == _negativeHeight.round()) {
          _correctNegativeHeight(-previewHeight);
        }
      }

      ///notify data
      notifyActionSyncListeners(FreeScrollListViewActionType.notifyData);
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
    assert(index >= 0 && index < dataList.length);

    ///clear data
    _dataList.clear();
    _dataList.addAll(dataList);

    ///notify data
    return scrollToIndexSkipAlign(
      index,
      align: align,
      curve: curve,
      duration: duration,
    );
  }

  ///scroll to top
  Future scrollToTop({
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeIn,
  }) {
    if (_negativeHeight == negativeInfinityValue) {
      return scrollToIndexSkipAlign(
        0,
        align: FreeScrollAlign.bottomToTop,
        curve: curve,
        duration: duration,
      );
    } else {
      return _handleAnimation(animateTo(
        _negativeHeight - _headerViewHeight,
        duration: duration,
        curve: curve,
      ));
    }
  }

  ///jump to top
  void jumpToTop() {
    if (_negativeHeight == negativeInfinityValue) {
      scrollToIndexSkipAlign(
        0,
        align: FreeScrollAlign.directJumpTo,
      );
    } else {
      jumpTo(_negativeHeight - _headerViewHeight);
    }
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
    assert(index >= 0 && index < dataList.length);

    ///notify data
    position.jumpTo(position.pixels);
    notifyActionSyncListeners(FreeScrollListViewActionType.notifyAnimStop);
    notifyActionSyncListeners(FreeScrollListViewActionType.notifyData);
    await waitForPostFrameCallback();

    ///all visible items refresh
    for (RectHolder holder in _itemsRectHolder.values) {
      holder.isOnScreen = false;
    }
    notifyCheckRectListeners();

    ///get the rect for the index
    RectHolder? holder = _itemsRectHolder[index];

    ///if index is exists and is not animating
    ///when animating the rect may not actual
    if (holder != null && holder.isOnScreen && !_isAnimating) {
      double toOffset = holder.rectTop()! + _anchorOffset;
      if (hasClients && position.maxScrollExtent != double.maxFinite) {
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
      List<int> keys = _itemsRectHolder.keys.toList();
      keys.sort((one, two) {
        return one.compareTo(two);
      });

      if (keys.isEmpty) {
        return Future.delayed(Duration.zero);
      }

      ///keys
      double pixels = position.pixels;
      int currentIndex = keys.first;
      for (int key in _itemsRectHolder.keys) {
        RectHolder? holder = _itemsRectHolder[key];
        if (holder != null && holder.isOnScreen) {
          double offsetTop = holder.rectTop()! - pixels;
          double offsetBottom = holder.rectBottom()! - pixels;
          if (offsetTop.round() <= 0 && offsetBottom.round() > 0) {
            currentIndex = key;
          }
        }
      }

      ///first
      if (index < currentIndex || index == 0) {
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
  }) async {
    assert(index >= 0 && index < dataList.length);

    ///Clear existing data and cached maps
    _setNegativeHeight(negativeInfinityValue);
    _itemsRectHolder.clear();
    _dataListOffset = index;

    ///notify data
    position.jumpTo(position.pixels);
    notifyActionSyncListeners(FreeScrollListViewActionType.notifyAnimStop);
    notifyActionSyncListeners(FreeScrollListViewActionType.notifyData);
    await waitForPostFrameCallback();

    switch (align) {
      case FreeScrollAlign.bottomToTop:
        AnimationData data = AnimationData(
          duration,
          curve,
          listViewHeight + _anchorOffset,
          0 + _anchorOffset,
          FreeScrollAlign.bottomToTop,
        );

        ///start animation
        return _handleAnimation(notifyActionASyncListeners(
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

        ///start animation
        return _handleAnimation(notifyActionASyncListeners(
          FreeScrollListViewActionType.notifyAnimStart,
          data: data,
        ));
      case FreeScrollAlign.directJumpTo:
        if (hasClients && position.hasPixels) {
          jumpTo(0);
        }
        return notifyActionASyncListeners(
          FreeScrollListViewActionType.notifyJump,
        );
    }
  }

  ///handler animation
  Future _handleAnimation(Future futureFunction) async {
    _isAnimating = true;
    return futureFunction.whenComplete(() {
      _isAnimating = false;
      _resetIndexIfNeeded();
      notifyActionASyncListeners(
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
  late FreeScrollListSyncListener _syncListener;

  ///function listener
  late FreeScrollListASyncListener _aSyncListener;

  ///time stamp debouncer
  final TimeStampDebouncer _timeStampDebouncer = TimeStampDebouncer();

  ///animation controller and offset
  AnimationController? _animationController;
  double _animationOffset = 0;

  ///init listener
  void _initListener() {
    _syncListener = (
      FreeScrollListViewActionType event, {
      dynamic data,
    }) {
      switch (event) {
        ///set state
        case FreeScrollListViewActionType.notifyData:
          if (mounted) {
            setState(() {});
          }
          break;

        ///stop animation
        case FreeScrollListViewActionType.notifyAnimStop:
          _cancelAnimation();
          break;

        ///start animation
        case FreeScrollListViewActionType.notifyAnimOffset:
          _animationOffset = data;
          break;

        default:
          break;
      }
    };
    _aSyncListener = (
      FreeScrollListViewActionType event, {
      dynamic data,
    }) async {
      switch (event) {
        ///start animation
        case FreeScrollListViewActionType.notifyAnimStart:
          await _startAnimation(data);
          break;

        ///start animation
        case FreeScrollListViewActionType.notifyJump:
          await Future.delayed(const Duration(milliseconds: 35)).then((_) {
            _notifyIndex();
            _notifyOnShow();
          });
          break;
        default:
          break;
      }
    };
    widget.controller.addSyncActionListener(_syncListener);
    widget.controller.addASyncActionListener(_aSyncListener);
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
      int maxIndex = widget.controller._dataList.length - 1;
      if (data.align == FreeScrollAlign.topToBottom &&
          offsetTo > maxScrollExtent &&
          maxScrollExtent != double.maxFinite &&
          widget.controller.hasClients &&
          widget.controller.position.hasPixels &&
          widget.controller._itemsRectHolder[maxIndex] != null &&
          widget.controller._itemsRectHolder[maxIndex]!.isOnScreen) {
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
      Future.delayed(const Duration(milliseconds: 35)).then((_) {
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
      oldWidget.controller.removeSyncActionListener(_syncListener);
      oldWidget.controller.removeASyncActionListener(_aSyncListener);
      widget.controller.addSyncActionListener(_syncListener);
      widget.controller.addASyncActionListener(_aSyncListener);
    }
    _initHeight();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
    _cancelAnimation();
    widget.controller.removeSyncActionListener(_syncListener);
    widget.controller.removeASyncActionListener(_aSyncListener);
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

              int negativeDataLength = widget.controller._dataListOffset;
              int positiveDataLength = widget.controller._dataList.length -
                  widget.controller._dataListOffset;

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
                            int actualIndex = negativeDataLength - index - 1;
                            RectHolder rectHolder = RectHolder();
                            widget.controller._itemsRectHolder[actualIndex] =
                                rectHolder;
                            return AnchorItemWrapper(
                              reverse: widget.reverse,
                              actualIndex: actualIndex,
                              listViewState: this,
                              controller: widget.controller,
                              rectHolder: rectHolder,
                              child: widget.builder(context, actualIndex),
                            );
                          },
                          childCount: negativeDataLength,
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
                            int actualIndex = negativeDataLength + index;
                            RectHolder rectHolder = RectHolder();
                            widget.controller._itemsRectHolder[actualIndex] =
                                rectHolder;
                            return AnchorItemWrapper(
                              key: GlobalKey(),
                              reverse: widget.reverse,
                              actualIndex: actualIndex,
                              listViewState: this,
                              controller: widget.controller,
                              rectHolder: rectHolder,
                              child: widget.builder(context, actualIndex),
                            );
                          },
                          childCount: positiveDataLength,
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
      widget.controller.notifyCheckRectListeners();
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
    if (widget.controller.isAnimating) {
      return false;
    }

    ///滚动结束的时候检查是否到达最大
    if (notification is ScrollEndNotification) {
      widget.controller._resetIndexIfNeeded();
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
    if (!mounted || widget.onItemShow == null) {
      return;
    }

    ///item show
    List<int> keys = [];

    ///listview height
    double listViewHeight = widget.controller.listViewHeight;

    ///keys
    for (int key in widget.controller._itemsRectHolder.keys) {
      RectHolder? holder = widget.controller._itemsRectHolder[key];
      if (holder != null && holder.isOnScreen) {
        ///offset top
        double offsetTop =
            holder.rectTop()! - widget.controller.position.pixels;
        holder.rectTop()! - widget.controller.position.pixels;
        double offsetBottom =
            holder.rectBottom()! - widget.controller.position.pixels;

        ///Listview height
        if ((offsetTop >= 0 && offsetBottom <= listViewHeight) ||
            offsetTop <= 0 && offsetBottom >= listViewHeight) {
          keys.add(key);
        }
      }
    }

    ///keys data
    if (keys.isNotEmpty) {
      widget.onItemShow!(keys);
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
    List<int> sortedKeys = widget.controller._itemsRectHolder.keys.toList()
      ..sort();
    for (int key in sortedKeys) {
      RectHolder? holder = widget.controller._itemsRectHolder[key];
      if (holder != null && holder.isOnScreen) {
        double offsetBottom = holder.rectBottom()! - pixels;
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
  double _minScrollExtend = negativeInfinityValue;

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

    ///add listener
    _callback = () {
      if (hasPixels &&
          _minScrollExtend != negativeInfinityValue &&
          pixels < _minScrollExtend - 100) {
        jumpTo(_minScrollExtend - 100);
      }
    };
    removeListener(_callback);
    addListener(_callback);
  }

  ///min scroll extend
  double get minScrollExtend {
    return _minScrollExtend;
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

///wait
Future<void> waitForPostFrameCallback() async {
  final Completer<void> completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    completer.complete();
  });
  return completer.future;
}
