import 'package:free_scroll_listview/src/free_scroll_throttller.dart';
import 'package:free_scroll_listview/src/free_scroll_preview.dart';
import 'package:synchronized/synchronized.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'free_scroll_physis.dart';
import 'free_scroll_wrapper.dart';
import 'free_scroll_base.dart';
import 'dart:collection';
import 'dart:async';
import 'dart:math';

///async listeners
typedef FreeScrollListASyncListener = Future Function(
  FreeScrollActionAsyncType type, {
  dynamic data,
});

///sync listeners
typedef FreeScrollListSyncListener = void Function(
  FreeScrollActionSyncType type, {
  dynamic data,
});

///use a negative value for min scroll
const double negativeInfinityValue = -100000000.0;

///free scroll listview controller
class FreeScrollListViewController<T> extends ScrollController {
  //global key
  final GlobalKey _listViewKey = GlobalKey();

  //header key
  final GlobalKey _headerKey = GlobalKey();

  //footer key
  final GlobalKey _footerKey = GlobalKey();

  //lock
  final Lock _lock = Lock();

  //data list
  final List<T> _dataList;

  //data list offset
  int _dataListOffset;

  //listeners
  final Set<FreeScrollListSyncListener> _syncListeners = {};

  //listeners
  final Set<FreeScrollListASyncListener> _asyncListeners = {};

  //check rect listeners
  final Set<VoidCallback> _checkRectListeners = {};

  //controller
  final AdditionPreviewController<T> _previewController =
      AdditionPreviewController<T>();

  //item maps
  final SplayTreeMap<int, RectHolder> _itemsRectHolder =
      SplayTreeMap<int, RectHolder>();

  //negative height total
  double _negativeHeight = negativeInfinityValue;

  //current index
  int _currentStartIndex = -1;

  //current index
  int _currentEndIndex = -1;

  //is animating
  bool _isAnimating = false;

  //check is animating
  bool get isAnimating {
    return _isAnimating;
  }

  //data list offset
  int dataListOffset() {
    return _dataListOffset;
  }

  //get current start index
  int get currentStartIndex {
    return _currentStartIndex;
  }

  //get current end index
  int get currentEndIndex {
    return _currentEndIndex;
  }

  ///get items rect on screen
  Map<int, RectHolder> getItemRectList() {
    return _itemsRectHolder;
  }

  ///get item top scroll offset
  double? getItemTopScrollOffset(int index) {
    if (!position.hasPixels) {
      return null;
    }
    RectHolder? rect = _itemsRectHolder[index];
    if (rect == null) {
      return null;
    }
    double? offsetOne = rect.rectTop();
    double offsetTwo = position.pixels;
    if (offsetOne == null) {
      return null;
    }
    return offsetTwo - offsetOne;
  }

  ///get item top scroll offset
  double? getItemBottomScrollOffset(int index) {
    if (!position.hasPixels) {
      return null;
    }
    RectHolder? rect = _itemsRectHolder[index];
    if (rect == null) {
      return null;
    }
    double? offsetOne = rect.rectTop();
    double offsetTwo = position.pixels;
    if (offsetOne == null) {
      return null;
    }
    return offsetTwo - offsetOne - (rect.rectHeight() ?? 0);
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

  ///get header view height
  double get headerViewHeight {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.height ?? 0.0;
  }

  ///get footer view height
  double get footerViewHeight {
    final box = _footerKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.height ?? 0.0;
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
            (_negativeHeight - headerViewHeight).removeTinyFraction();
      }
    }
  }

  ///remove rect on screen
  void notifyItemRectRemoveOnScreen(int index) {
    if (index == 0) {
      _setNegativeHeight(negativeInfinityValue);
    }
  }

  ///add anchor item state
  void notifyItemRectShowOnScreen(int index) {
    ///check when animating
    _checkResetCurrentIndex();
    _checkResetMinScrollExtend();
    _checkDeleteLastItem(index);
  }

  ///reset index when animating,this is triggered by when jump index has no enough positive space to lay on one screen.
  void _checkResetCurrentIndex() {
    ///when not animating,return
    if (!_isAnimating) {
      return;
    }

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
      FreeScrollActionSyncType.notifyAnimOffset,
      data: needChangeOffset,
    );
    notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
    position.correctBy(needChangeOffset);
  }

  ///check reset scroll extend
  void _checkResetMinScrollExtend() {
    //Do nothing if _itemsRectHolder is empty
    if (_itemsRectHolder.isEmpty) {
      return;
    }

    //Get the first RectHolder and its rectTop
    RectHolder? firstHolder = _itemsRectHolder[0];
    double? firstHolderRectTop = firstHolder?.rectTop();

    //Safely cast the position to _NegativedScrollPosition
    _NegativedScrollPosition? currentPosition =
        position is _NegativedScrollPosition
            ? position as _NegativedScrollPosition
            : null;

    //Find the minimum rectTop from _itemsRectHolder
    double? minRectTop = _findMinRectTop();

    //Determine and set the negative height based on conditions
    if (firstHolderRectTop != null && minRectTop == firstHolderRectTop) {
      //If the minimum rectTop is the firstHolder's rectTop
      _setNegativeHeight(firstHolderRectTop);
    } else if (currentPosition != null && minRectTop != null) {
      //If firstHolder does not exist, compare currentPosition.minScrollExtent with minRectTop
      _setNegativeHeight(min(currentPosition.minScrollExtent, minRectTop));
    } else {
      //If no valid minimum rectTop is found, set to negative infinity
      _setNegativeHeight(negativeInfinityValue);
    }
  }

  ///Helper method to find the minimum rectTop from _itemsRectHolder
  double? _findMinRectTop() {
    double? minRectTop;
    //Iterate through all RectHolders in _itemsRectHolder
    for (RectHolder holder in _itemsRectHolder.values) {
      final rectTop = holder.rectTop();
      if (rectTop != null) {
        //Update minRectTop if a smaller value is found
        if (minRectTop == null || rectTop < minRectTop) {
          minRectTop = rectTop;
        }
      }
    }
    return minRectTop;
  }

  ///when delete some item
  void _checkDeleteLastItem(int index) {
    RectHolder? firstHolder = _itemsRectHolder[0];
    if (position.isScrollingNotifier.value ||
        isAnimating ||
        index != 0 ||
        firstHolder == null ||
        firstHolder.rectTop() == null ||
        position.pixels >= firstHolder.rectTop()!) {
      return;
    }
    position.jumpTo(position.pixels);
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
      FreeScrollActionSyncType.notifyAnimOffset,
      data: needChangeOffset,
    );
    notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
    position.jumpTo(position.pixels + needChangeOffset);
  }

  ///add check rect listener
  void addCheckRectListener(VoidCallback listener) {
    _checkRectListeners.add(listener);
  }

  ///remove check rect listener
  bool removeCheckRectListener(VoidCallback listener) {
    return _checkRectListeners.remove(listener);
  }

  ///add listener
  void addSyncActionListener(FreeScrollListSyncListener listener) {
    _syncListeners.add(listener);
  }

  ///remove listener
  bool removeSyncActionListener(FreeScrollListSyncListener listener) {
    return _syncListeners.remove(listener);
  }

  ///add listener
  void addASyncActionListener(FreeScrollListASyncListener listener) {
    _asyncListeners.add(listener);
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
    FreeScrollActionSyncType event, {
    dynamic data,
  }) async {
    List<FreeScrollListSyncListener> listeners = List.from(_syncListeners);
    for (FreeScrollListSyncListener listener in listeners) {
      try {
        listener(event, data: data);
      } catch (e) {
        if (kDebugMode) {
          print(e.toString());
        }
      }
    }
  }

  ///notify listeners
  Future<void> notifyActionASyncListeners(
    FreeScrollActionAsyncType event, {
    dynamic data,
  }) async {
    List<FreeScrollListASyncListener> listeners = List.from(_asyncListeners);
    for (FreeScrollListASyncListener listener in listeners) {
      try {
        await listener(event, data: data);
      } catch (e) {
        if (kDebugMode) {
          print(e.toString());
        }
      }
    }
  }

  ///scroll
  FreeScrollListViewController({
    List<T>? dataList,
    double? anchorOffset,
    int index = 0,
  })  : _dataList = List.from(dataList ?? []),
        _dataListOffset = index;

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
      notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
    }

    ///set data if is init
    else {
      _setNegativeHeight(negativeInfinityValue);
      _itemsRectHolder.clear();
      _dataList.clear();
      _dataList.addAll(dataList);
      _dataListOffset = min(_dataListOffset, dataList.length);
      notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
    }
  }

  ///update data
  void updateData(T t, int index) {
    assert(index >= 0 && index < dataList.length);
    _dataList[index] = t;
    _itemsRectHolder.clear();
    notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
  }

  ///add data to tail
  Future<void> addDataToTail(List<T> dataList) {
    return _lock.synchronized(() async {
      _dataList.addAll(dataList);
      _itemsRectHolder.clear();
      notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
    });
  }

  ///add data to head
  ///previewHeight measure add item height or not
  Future<void> addDataToHead(List<T> dataList, {bool measureHeight = true}) {
    return _lock.synchronized(() async {
      ///data list
      if (_dataList.isNotEmpty && _itemsRectHolder.isEmpty) {
        await waitForPostFrameCallback();
      }

      ///if can scroll
      if (hasClients && position.maxScrollExtent > 0) {
        ///insert all data
        _dataList.insertAll(0, dataList);
        _dataListOffset = _dataListOffset + dataList.length;
        _itemsRectHolder.clear();

        ///preview the height and add it to negative height
        double formerTopData = _negativeHeight;
        if (_negativeHeight != negativeInfinityValue && measureHeight) {
          ///preview model
          PreviewModel? previewModel =
              await _previewController.previewItemsHeight(
            dataList.length,
          );

          ///total height
          double? previewHeight = previewModel?.totalHeight;

          ///all previewed
          if ((previewModel?.allPreviewed ?? false) && previewHeight != null) {
            _setNegativeHeight(formerTopData - previewHeight);
          }
        }

        ///notify data
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
      } else {
        ///notify data
        setDataAndScrollTo(
          [...dataList, ..._dataList],
          index: dataList.length,
          align: FreeScrollType.directJumpTo,
        );
      }
    });
  }

  ///set data and scroll to
  Future setDataAndScrollTo(
    List<T> dataList, {
    int index = 0,
    FreeScrollType align = FreeScrollType.topToBottom,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeIn,
    double anchorOffset = 0,
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
      anchorOffset: anchorOffset,
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
        align: FreeScrollType.bottomToTop,
        anchorOffset: -headerViewHeight,
        curve: curve,
        duration: duration,
      );
    } else {
      return _handleAnimation(animateTo(
        _negativeHeight - headerViewHeight,
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
        align: FreeScrollType.directJumpTo,
        anchorOffset: -headerViewHeight,
      );
    } else {
      jumpTo(
        _negativeHeight - headerViewHeight,
      );
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
    double anchorOffset = 0,
  }) async {
    assert(index >= 0 && index < dataList.length);

    ///no clients
    if (!hasClients) {
      return;
    }

    ///time is not enough
    if (duration.inMilliseconds < 50) {
      return scrollToIndexSkipAlign(
        index,
        align: FreeScrollType.directJumpTo,
        curve: curve,
        duration: duration,
        anchorOffset: anchorOffset,
      );
    }

    ///notify data
    notifyActionSyncListeners(FreeScrollActionSyncType.notifyAnimStop);
    notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
    await waitForPostFrameCallback();

    ///all visible items refresh
    notifyCheckRectListeners();

    ///get the rect for the index
    RectHolder? holder = _itemsRectHolder[index];

    ///if index is exists and is not animating
    ///when animating the rect may not actual
    if (holder != null && holder.isOnScreen && !_isAnimating) {
      double toOffset = holder.rectTop()! + anchorOffset;
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
      FreeScrollType align = FreeScrollType.topToBottom;
      List<int> keys = _itemsRectHolder.keys.toList();

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
        align = FreeScrollType.bottomToTop;
      } else {
        align = FreeScrollType.topToBottom;
      }

      return scrollToIndexSkipAlign(
        index,
        align: align,
        curve: curve,
        duration: duration,
        anchorOffset: anchorOffset,
      );
    }
  }

  ///scroll to index just by align
  Future scrollToIndexSkipAlign(
    int index, {
    required FreeScrollType align,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeIn,
    double anchorOffset = 0,
  }) async {
    assert(index >= 0 && index < dataList.length);

    ///header view height
    double trueAnchorOffset =
        (index == 0) ? (anchorOffset + headerViewHeight) : anchorOffset;

    switch (align) {
      case FreeScrollType.bottomToTop:

        ///Clear existing data and cached maps
        _setNegativeHeight(negativeInfinityValue);
        _itemsRectHolder.clear();
        _dataListOffset = index;
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyAnimStop);
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
        await waitForPostFrameCallback();

        AnimationData data = AnimationData(
          duration,
          curve,
          listViewHeight + trueAnchorOffset,
          0 + trueAnchorOffset,
          FreeScrollType.bottomToTop,
        );

        ///start animation
        return _handleAnimation(notifyActionASyncListeners(
          FreeScrollActionAsyncType.notifyAnimStart,
          data: data,
        ));
      case FreeScrollType.topToBottom:

        ///Clear existing data and cached maps
        _setNegativeHeight(negativeInfinityValue);
        _itemsRectHolder.clear();
        _dataListOffset = index;
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyAnimStop);
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
        await waitForPostFrameCallback();

        AnimationData data = AnimationData(
          duration,
          curve,
          -listViewHeight + trueAnchorOffset,
          0 + trueAnchorOffset,
          FreeScrollType.topToBottom,
        );

        ///start animation
        return _handleAnimation(notifyActionASyncListeners(
          FreeScrollActionAsyncType.notifyAnimStart,
          data: data,
        ));
      case FreeScrollType.directJumpTo:

        ///preview data model
        PreviewModel? previewModel =
            await _previewController.previewItemsHeight(
          dataList.length,
          previewReverse: true,
          previewExtent: max(0, trueAnchorOffset),
        );
        double listviewHeight = previewModel?.listviewHeight ?? listViewHeight;

        ///previewed
        if (previewModel != null && previewModel.itemHeights[index] != null) {
          ///get height remain
          double height = footerViewHeight;
          for (int s = dataList.length - 1; s >= index; s--) {
            height = (previewModel.itemHeights[s] ?? 0) + height;
          }

          ///no enough space
          if (height - trueAnchorOffset - listviewHeight < 0) {
            double testHeight = footerViewHeight;
            int testIndex = 0;
            double testOffset = 0;

            ///check max jump
            for (int s = dataList.length - 1; s >= 0; s--) {
              testHeight = (previewModel.itemHeights[s] ?? 0) + testHeight;
              if (testHeight > listviewHeight) {
                testIndex = s;
                testOffset = testHeight - listviewHeight;
                break;
              }
            }

            ///set jump index
            _setNegativeHeight(negativeInfinityValue);
            _itemsRectHolder.clear();
            _dataListOffset = testIndex;
            notifyActionSyncListeners(FreeScrollActionSyncType.notifyAnimStop);
            notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
            if (hasClients && position.hasPixels) {
              jumpTo(testOffset);
            }
            await waitForPostFrameCallback();
            return notifyActionASyncListeners(
              FreeScrollActionAsyncType.notifyJump,
            );
          }
        }

        ///other kind
        _setNegativeHeight(negativeInfinityValue);
        _itemsRectHolder.clear();
        _dataListOffset = index;
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyAnimStop);
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
        if (hasClients && position.hasPixels) {
          jumpTo(trueAnchorOffset);
        }
        await waitForPostFrameCallback();
        return notifyActionASyncListeners(
          FreeScrollActionAsyncType.notifyJump,
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
        FreeScrollActionAsyncType.notifyJump,
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
  final ScrollPhysics? physics;

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

  ///shrinkWrap
  final bool shrinkWrap;

  ///notify item show when gesture scroll
  final bool notifyItemShowWhenGestureScroll;

  ///notify item show when gesture scroll
  final bool notifyItemShowWhenAllTypeScroll;

  ///duration for throttler
  final Duration notifyItemShowThrottlerDuration;

  ///item show
  final FreeScrollOnItemShow? onItemShow;

  ///start index changed
  final FreeScrollOnIndexChange? onStartIndexChange;

  ///end index changed
  final FreeScrollOnIndexChange? onEndIndexChange;

  ///add repaint boundary or not
  final bool addRepaintBoundary;

  const FreeScrollListView({
    super.key,
    required this.controller,
    required this.builder,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.clipBehavior = Clip.hardEdge,
    this.cacheExtent,
    this.loadOffset = 100,
    this.willReachHead,
    this.willReachTail,
    this.headerView,
    this.footerView,
    this.onItemShow,
    this.onStartIndexChange,
    this.onEndIndexChange,
    this.shrinkWrap = false,
    this.notifyItemShowWhenGestureScroll = false,
    this.notifyItemShowWhenAllTypeScroll = false,
    this.notifyItemShowThrottlerDuration = const Duration(milliseconds: 120),
    this.addRepaintBoundary = false,
  });

  @override
  State<StatefulWidget> createState() {
    return FreeScrollListViewState<T>();
  }
}

///free scroll listview state
class FreeScrollListViewState<T> extends State<FreeScrollListView>
    with TickerProviderStateMixin {
  ///throttler
  late Throttler _throttler;

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
      FreeScrollActionSyncType event, {
      dynamic data,
    }) {
      switch (event) {
        ///set state
        case FreeScrollActionSyncType.notifyData:
          if (mounted) {
            setState(() {});
          }
          break;

        ///stop animation
        case FreeScrollActionSyncType.notifyAnimStop:
          _cancelAnimation();
          if (widget.controller.hasClients &&
              widget.controller.position.hasPixels) {
            widget.controller.position
                .jumpTo(widget.controller.position.pixels);
          }
          break;

        ///start animation
        case FreeScrollActionSyncType.notifyAnimOffset:
          _animationOffset = data;
          break;
      }
    };
    _aSyncListener = (
      FreeScrollActionAsyncType event, {
      dynamic data,
    }) async {
      switch (event) {
        ///start animation
        case FreeScrollActionAsyncType.notifyAnimStart:
          await _startAnimation(data);
          break;

        ///start animation
        case FreeScrollActionAsyncType.notifyJump:
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _notifyIndex();
              _notifyOnShow();
            }
          });
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
      //监听动画状态
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        //动画自然完成时，调用 completer.complete()
        if (!completer.isCompleted) {
          completer.complete();
        }
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
      if (data.type == FreeScrollType.topToBottom &&
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyIndex();
        _notifyOnShow();
      }
    });
  }

  @override
  void initState() {
    _throttler = Throttler(duration: widget.notifyItemShowThrottlerDuration);
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
    if (widget.controller.hasClients &&
        widget.controller.position.hasPixels &&
        widget.controller.position.maxScrollExtent == 0) {
      widget.controller._resetIndexIfNeeded();
    }
    _initHeight();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
    _animationController?.dispose();
    _animationController = null;
    widget.controller.removeSyncActionListener(_syncListener);
    widget.controller.removeASyncActionListener(_aSyncListener);
  }

  @override
  Widget build(BuildContext context) {
    ///get direction
    AxisDirection axisDirection = _getDirection(context);

    ScrollPhysics physics = widget.physics ??
        FreeLimitShrinkOverScrollPhysics(
          controller: widget.controller,
        );

    return NotificationListener<ScrollNotification>(
      onNotification: _handleNotification,
      child: Scrollable(
        key: widget.controller._listViewKey,
        axisDirection: axisDirection,
        controller: widget.controller,
        physics: physics,
        clipBehavior: widget.clipBehavior,
        viewportBuilder: (BuildContext context, ViewportOffset offset) {
          //get max height father
          final constraints = context.findRenderObject() as RenderBox;
          final maxHeight = constraints.constraints.maxHeight;

          return Builder(
            builder: (context) {
              ///Build negative [ScrollPosition] for the negative scrolling [Viewport].
              final ScrollableState state = Scrollable.of(context);
              final _NegativedScrollPosition negativeOffset =
                  _NegativedScrollPosition(
                physics: physics,
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

              ///negative
              List<Widget> sliverNegative = <Widget>[
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
                        addRepaintBoundary: widget.addRepaintBoundary,
                        child: widget.builder(context, actualIndex),
                      );
                    },
                    childCount: negativeDataLength,
                  ),
                ),
                if (widget.controller._dataListOffset != 0) _buildHeader(),
              ];

              ///positive
              List<Widget> sliverPositive = <Widget>[
                if (widget.controller._dataListOffset == 0) _buildHeader(),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      int actualIndex = negativeDataLength + index;
                      RectHolder rectHolder = RectHolder();
                      widget.controller._itemsRectHolder[actualIndex] =
                          rectHolder;
                      return AnchorItemWrapper(
                        reverse: widget.reverse,
                        actualIndex: actualIndex,
                        listViewState: this,
                        controller: widget.controller,
                        rectHolder: rectHolder,
                        addRepaintBoundary: widget.addRepaintBoundary,
                        child: widget.builder(context, actualIndex),
                      );
                    },
                    childCount: positiveDataLength,
                  ),
                ),
                _buildFooter(),
              ];

              return widget.shrinkWrap
                  ? Stack(
                      clipBehavior: Clip.none,
                      alignment: widget.reverse
                          ? Alignment.topCenter
                          : Alignment.bottomCenter,
                      children: <Widget>[
                        ///preview items widget
                        AdditionPreview(
                          padding: EdgeInsets.zero,
                          maxHeight: maxHeight,
                          itemBuilder: widget.builder,
                          controller: widget.controller._previewController,
                        ),

                        ///negative
                        if (widget.controller._dataListOffset > 0)
                          Viewport(
                            axisDirection: flipAxisDirection(axisDirection),
                            anchor: 1.0,
                            offset: negativeOffset,
                            cacheExtent: widget.cacheExtent,
                            slivers: sliverNegative,
                          ),

                        ///positive
                        ShrinkWrappingViewport(
                          axisDirection: axisDirection,
                          clipBehavior: widget.clipBehavior,
                          offset: offset,
                          slivers: sliverPositive,
                        ),
                      ],
                    )
                  : Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        ///preview items widget
                        AdditionPreview(
                          maxHeight: maxHeight,
                          padding: EdgeInsets.zero,
                          itemBuilder: widget.builder,
                          controller: widget.controller._previewController,
                        ),

                        ///negative
                        Viewport(
                          axisDirection: flipAxisDirection(axisDirection),
                          anchor: 1.0,
                          offset: negativeOffset,
                          cacheExtent: widget.cacheExtent,
                          slivers: sliverNegative,
                        ),

                        ///positive
                        Viewport(
                          offset: offset,
                          axisDirection: axisDirection,
                          cacheExtent: widget.cacheExtent,
                          clipBehavior: widget.clipBehavior,
                          slivers: sliverPositive,
                        ),
                      ],
                    );
            },
          );
        },
      ),
    );
  }

  ///header
  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: SizedBox(
        key: widget.controller._headerKey,
        child: widget.headerView ?? const SizedBox(),
      ),
    );
  }

  ///footer
  Widget _buildFooter() {
    return SliverToBoxAdapter(
      child: SizedBox(
        key: widget.controller._footerKey,
        child: widget.footerView ?? const SizedBox(),
      ),
    );
  }

  ///handle notification
  bool _handleNotification(ScrollNotification notification) {
    ///滚动开始而且有触摸事件
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

    ///when animating do noting
    if (widget.controller.isAnimating) {
      return false;
    }

    ///scroll end, check need reset index or not
    if (notification is ScrollEndNotification) {
      widget.controller._resetIndexIfNeeded();
      _notifyOnShow();
    }

    ///notify the on show
    if ((notification is ScrollUpdateNotification) &&
        (widget.notifyItemShowWhenAllTypeScroll ||
            (widget.notifyItemShowWhenGestureScroll &&
                notification.dragDetails != null))) {
      if (_throttler.duration == Duration.zero) {
        _notifyOnShow();
      } else {
        _throttler.throttle(() {
          _notifyOnShow();
        });
      }
    }

    ///notify index
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

    double pixels = widget.controller.position.pixels;

    ///get sorted key
    List<int> sortedKeys = widget.controller._itemsRectHolder.keys.toList();

    ///start index
    for (int key in sortedKeys) {
      RectHolder? holder = widget.controller._itemsRectHolder[key];
      if (holder == null || !holder.isOnScreen) {
        continue;
      }

      double? rectBottom = holder.rectBottom();
      if (rectBottom == null) {
        continue;
      }

      double offsetBottom = rectBottom - pixels;
      if (offsetBottom.round() > 0) {
        int index = key;
        if (widget.controller._currentStartIndex != index) {
          widget.controller._currentStartIndex = index;
          widget.onStartIndexChange?.call(index);
        }
        break;
      }
    }

    ///end index
    for (int s = sortedKeys.length - 1; s >= 0; s--) {
      int key = sortedKeys[s];
      RectHolder? holder = widget.controller._itemsRectHolder[key];
      if (holder == null || !holder.isOnScreen) {
        continue;
      }

      double? rectTop = holder.rectTop();
      if (rectTop == null) {
        continue;
      }

      double offsetTop = rectTop - pixels;
      if (offsetTop.round() < widget.controller.listViewHeight) {
        int index = key;
        if (widget.controller._currentEndIndex != index) {
          widget.controller._currentEndIndex = index;
          widget.onEndIndexChange?.call(index);
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
    ///已经赋值了
    if (_minScrollExtend == data) {
      return;
    }
    _minScrollExtend = data;

    ///add listener
    _callback = () {
      if (!hasPixels ||
          _minScrollExtend == negativeInfinityValue ||
          pixels > _minScrollExtend - 100 ||
          minScrollExtend > maxScrollExtent) {
        return;
      }
      jumpTo(min(_minScrollExtend - 100, 0));
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
  double get minScrollExtent => min(_minScrollExtend, maxScrollExtent);
}

///wait
Future<void> waitForPostFrameCallback() async {
  final Completer<void> completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    completer.complete();
  });
  return completer.future;
}
