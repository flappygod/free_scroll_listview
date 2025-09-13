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
const double negativeInfinityValue = double.negativeInfinity;

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

  //尾部一屏幕的预览
  final AdditionPreviewController<T> _previewLastController = AdditionPreviewController<T>();

  //头部一屏幕的预览
  final AdditionPreviewController<T> _previewFirstController = AdditionPreviewController<T>();

  //item maps
  final SplayTreeMap<int, RectHolder> itemsRectHolder = SplayTreeMap<int, RectHolder>();

  //negative height total
  double _negativeHeight = negativeInfinityValue;

  //current index
  int _currentStartIndex = -1;

  //current index
  int _currentEndIndex = -1;

  //is animating
  bool _isAnimating = false;

  //mx height
  double? _listviewMaxHeight;

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

  ///get item top scroll offset
  double? getItemTopScrollOffset(int index) {
    if (!hasClients || !position.hasPixels) {
      return null;
    }
    RectHolder? rect = itemsRectHolder[index];
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
    if (!hasClients || !position.hasPixels) {
      return null;
    }
    RectHolder? rect = itemsRectHolder[index];
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

  ///获取最大可能区域的高度
  double get listviewMaxHeight => _listviewMaxHeight ?? 0;

  ///获取列表的高度
  double get listViewHeight {
    final box = _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.height ?? 0.0;
  }

  ///获取当前列表相对于屏幕的偏移量
  double get listViewOffset {
    final box = _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero).dy ?? 0.0;
  }

  ///获取headerView的高度
  double get headerViewHeight {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.height ?? 0.0;
  }

  ///获取footerView的高度
  double get footerViewHeight {
    final box = _footerKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.height ?? 0.0;
  }

  ///纠正负向滚动的最大高度进行偏移
  void _correctNegativeHeight(double height) {
    if (_negativeHeight != negativeInfinityValue) {
      _setNegativeHeight(_negativeHeight + height);
    }
  }

  ///设置负向滚动的最大搞低
  void _setNegativeHeight(double height) {
    _negativeHeight = height.removeTinyFraction();
    if (hasClients && position is _NegativedScrollPosition) {
      final negativedPosition = position as _NegativedScrollPosition;
      if (_negativeHeight == negativeInfinityValue) {
        negativedPosition.minScrollExtend = _negativeHeight;
      } else {
        negativedPosition.minScrollExtend = (_negativeHeight - headerViewHeight).removeTinyFraction();
      }
    }
  }

  ///某个Item将要被移除掉了
  void notifyItemRectRemoveOnScreen(int index) {
    //如果是index == 0的item被移除掉了，设置负向滚动距离为无限
    if (index == 0) {
      _setNegativeHeight(negativeInfinityValue);
    }
  }

  ///某个Item展示在屏幕上了
  void notifyItemRectShowOnScreen(int index) {
    _checkResetLastScreenIndex();
    _checkResetMinScrollExtend();
    _checkResetDeleteFirstItem(index);
  }

  ///这里主要是为了解决在动画的过程中，如果发现最后一屏的数据不满了，防止滚动最后留白太多。
  void _checkResetLastScreenIndex() {
    //如果不是在动画中，就直接返回
    if (!_isAnimating) {
      return;
    }

    //最大的index
    int maxIndex = (dataList.length - 1);

    //当前列表高度
    double currentListViewHeight = listViewHeight;

    //我们来计算滚动到的最后一屏的高度
    double lastScreenHeight = 0;
    int? lastScreenIndex;

    //从最大的index开始方向计算
    for (int s = maxIndex; s >= 0; s--) {
      //没有找到高度就代表最后一屏还没有展示完全，不做处理
      final double? itemHeight = itemsRectHolder[s]?.rectHeight();
      if (itemHeight == null) {
        return;
      }
      lastScreenHeight += itemHeight;

      //当完成了最后一屏的高度计算大于了当前的列表高度(设置最大的能满足负一屏幕的高度，主要保证Viewport能够正常滚动)
      if (lastScreenHeight >= currentListViewHeight) {
        lastScreenIndex = s;
        break;
      }
    }
    if (lastScreenIndex == null) {
      return;
    }

    //如果当前的offset已经比最少需要的lastScreenIndex要小，那么无需做切换就能保证最后一屏的滚动不出现问题
    int tempCount = _dataListOffset;
    if (tempCount <= lastScreenIndex) {
      return;
    }

    //否则的话我们就需要计算一下需要切换锚定Index的高度的大小是多少
    double needChangeOffset = 0;
    for (int s = lastScreenIndex; s < tempCount; s++) {
      final itemHeight = itemsRectHolder[s]?.rectHeight();
      if (itemHeight == null) {
        return;
      }
      needChangeOffset += itemHeight;
    }
    if (position.pixels < position.minScrollExtent + needChangeOffset) {
      return;
    }

    //重置当前的锚定index,
    _dataListOffset = lastScreenIndex;

    //清空缓存item高度
    itemsRectHolder.clear();

    //最小高度如果存在那么就进行一个偏移
    _correctNegativeHeight(needChangeOffset);

    //告诉正在进行的动画列表的锚定已经修改，响应的动画响应位置也需要进行偏移
    notifyActionSyncListeners(
      FreeScrollActionSyncType.notifyAnimOffset,
      data: needChangeOffset,
    );

    //刷新界面
    notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);

    //提示index被展示
    notifyActionASyncListeners(FreeScrollActionAsyncType.notifyIndexShow);

    //当前的滚动距离修正
    position.correctBy(needChangeOffset);
  }

  ///这里主要是在滚动的过程中，及时去设置最小的滚动距离，这样对滚动列表进行限制
  void _checkResetMinScrollExtend() {
    //当前的rect holder如果是空的
    if (itemsRectHolder.isEmpty) {
      return;
    }

    //对当前的滚动的position进行一个转换
    _NegativedScrollPosition? currentPosition =
        (hasClients && position is _NegativedScrollPosition) ? (position as _NegativedScrollPosition) : null;

    //如果都是空的那么就不需要再继续了
    if (currentPosition == null) {
      return;
    }

    //获取顶部的第一个
    RectHolder? firstHolder = itemsRectHolder[0];
    double? firstHolderRectTop = firstHolder?.rectTop();

    //找到当前屏幕最小
    double? minRectTop = _findMinRectTop();

    //如果第一个rect top不为空、而且也确认了是第一个
    if (firstHolderRectTop != null && minRectTop == firstHolderRectTop) {
      //这种情况相当于无疑问，直接设置这个负向滚动距离的限制
      _setNegativeHeight(firstHolderRectTop);
      return;
    }

    //如果只是最小的rect不为空、取当前的已经设置的minScrollExtent和minRectTop进行对比来取得最小的
    if (minRectTop != null) {
      _setNegativeHeight(min(currentPosition.minScrollExtent, minRectTop));
      return;
    }

    //其余的情况我们直接设置为可以无限的负向滚动
    _setNegativeHeight(negativeInfinityValue);
  }

  ///在itemsRectHolder中找到那个最小的值进行处理(找到当前所有的rect中的那个最小的值)
  double? _findMinRectTop() {
    double? minRectTop;
    for (RectHolder holder in itemsRectHolder.values) {
      final rectTop = holder.rectTop();
      if (rectTop != null) {
        if (minRectTop == null || rectTop < minRectTop) {
          minRectTop = rectTop;
        }
      }
    }
    return minRectTop;
  }

  ///处理第一条数据被删除了的情况(反向的时候需要触发一下防止空白高度)
  void _checkResetDeleteFirstItem(int index) {
    RectHolder? firstHolder = itemsRectHolder[0];
    if (index != 0 ||
        //正在滚动
        position.isScrollingNotifier.value ||
        isAnimating ||
        //第一条值没有
        firstHolder == null ||
        firstHolder.rectTop() == null ||
        //已经滚动了
        position.pixels >= firstHolder.rectTop()!) {
      return;
    }
    position.jumpTo(position.pixels);
  }

  ///当界面的高度发生变化的时候，可能因为最后一屏高度不足导致空白，这种情况下，我们合理的重新锚定以防止空白的出现
  void _resetIndexByHeightAdd(double oldHeight, double newHeight) {
    //基本条件
    if (!hasClients || !position.hasPixels) {
      return;
    }

    //如果当前_dataListOffset已经为零
    if (_dataListOffset == 0) {
      return;
    }

    //计算当前展示的区域offset的contentHeight,如果没有展示代表其实距离是足够的，距离不足的时候，必然所有item都是有值的。
    double currentContentHeight = 0;
    int maxIndex = (dataList.length - 1);
    for (int s = maxIndex; s >= _dataListOffset; s--) {
      double? itemHeight = itemsRectHolder[s]?.rectHeight();
      if (itemHeight == null) {
        return;
      }
      currentContentHeight += itemHeight;
    }

    //多申请100的高度防止重新锚定次数过多
    double applyHeight = newHeight + 100;

    //高度已经不再满足需求
    if (currentContentHeight < applyHeight) {
      //需求高度
      double needHeight = (applyHeight - currentContentHeight);

      //我们以当前的_dataListOffset向前偏移
      //因为willChangeHeight这个值可能持续回调且不大
      //防止多次进行重新锚定而导致性能问题
      double heightChanged = 0;
      int newListOffset = _dataListOffset;
      for (int s = _dataListOffset - 1; s >= 0; s--) {
        //向前取可能这个item还未展示的情况直接break,能向前偏移多少个就向前偏移多少个
        double? itemHeight = itemsRectHolder[s]?.rectHeight();
        if (itemHeight == null) {
          break;
        }
        //向前偏移
        heightChanged += itemHeight;
        newListOffset = s;
        //已经满足我们的要求了
        if (heightChanged > needHeight) {
          break;
        }
      }
      //完全没有取得新的锚点，和之前一模一样，不做处理
      if (_dataListOffset == newListOffset) {
        return;
      }
      //重新锚定
      _dataListOffset = newListOffset;
      //清空老数据
      itemsRectHolder.clear();
      //执行偏移
      _correctNegativeHeight(heightChanged);
      //通知动画
      notifyActionSyncListeners(
        FreeScrollActionSyncType.notifyAnimOffset,
        data: heightChanged,
      );
      //执行偏移
      position.jumpTo(position.pixels + heightChanged);
    }
  }

  ///这里是当滚动结束的时候，进行一个锚定位置的校准，同样的道理，尽量保证最后一屏(positive)能够铺满
  ///(极少数特殊情况下可能滚出空白，这里是为了在滚动结束后不再展示这一块空白区域，按照道理这个方法不触发才是最好的)
  void _resetIndexIfNeeded() {
    //这里我们进行特殊处理
    if (!hasClients) {
      return;
    }

    //完全不需要重新锚定了
    if (_dataListOffset == 0) {
      return;
    }

    //最大滚动距离大于零，代表最后一屏不需要resetIndex
    if (position.maxScrollExtent > 0) {
      return;
    }

    //最大index
    int maxIndex = dataList.length - 1;
    //当前高度
    double currentListViewHeight = listViewHeight;
    //减去之后才是真正锚定后的距离
    double scrollOffset = position.pixels;

    //这里我们取得连续的、大于屏幕高度的一个锚定点来进行锚定
    double lastScreenHeight = 0;
    int? lastScreenIndex;
    bool isAllContinuous = true;
    double? firstRectBottom;
    for (int s = maxIndex; s >= 0; s--) {
      //没有取到证明没展示，直接return
      final double? itemHeight = itemsRectHolder[s]?.rectHeight();
      if (itemHeight == null) {
        //重新开始计算，必须要连续的一个空间位置
        lastScreenHeight = 0;
        isAllContinuous = false;
        firstRectBottom = null;
        continue;
      }
      firstRectBottom ??= itemsRectHolder[s]?.rectBottom();
      lastScreenHeight += itemHeight;
      if (lastScreenHeight >= currentListViewHeight) {
        lastScreenIndex = s;
        break;
      }
    }

    //穷尽解数也完全无法铺满屏幕(除非极其特殊的情况，否则不应该走到这里)
    if (isAllContinuous && lastScreenIndex == null) {
      _dataListOffset = 0;
      itemsRectHolder.clear();
      _setNegativeHeight(0);
      position.jumpTo(0);
      notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
      return;
    }

    //我们已经获得了重新锚定的index,需要根据这个index进行重新锚定
    if (lastScreenIndex != null) {
      //获取这个item的真实基准
      double? itemTop = itemsRectHolder[lastScreenIndex]?.rectTop();
      if (itemTop == null) {
        return;
      }
      //首项没有滑出屏幕不处理，让用户无感
      if ((firstRectBottom ?? 0) - scrollOffset < listViewHeight) {
        return;
      }
      //跳转
      double reIndexOffset = scrollOffset - itemTop;
      //执行重新锚定
      _dataListOffset = lastScreenIndex;
      //清空缓存
      itemsRectHolder.clear();
      //这种锚定就直接设置为负向无限滚动后等待自动刷新赋值最小negative高度
      _setNegativeHeight(_negativeHeight);
      //跳转到指定位置
      notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
      //跳转
      position.jumpTo(reIndexOffset);
      return;
    }
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
      itemsRectHolder.clear();
      _dataList.clear();
      _dataList.addAll(dataList);
      _dataListOffset = 0;
      notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
      notifyActionASyncListeners(FreeScrollActionAsyncType.notifyIndexShow);
    }

    ///set data if is init
    else {
      _setNegativeHeight(negativeInfinityValue);
      itemsRectHolder.clear();
      _dataList.clear();
      _dataList.addAll(dataList);
      _dataListOffset = min(_dataListOffset, dataList.length);
      notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
      notifyActionASyncListeners(FreeScrollActionAsyncType.notifyIndexShow);
    }
  }

  ///update data
  void updateData(T t, int index) {
    assert(index >= 0 && index < dataList.length);
    _dataList[index] = t;
    itemsRectHolder.clear();
    notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
    notifyActionASyncListeners(FreeScrollActionAsyncType.notifyIndexShow);
  }

  ///add data to tail
  Future<void> addDataToTail(List<T> dataList) {
    return _lock.synchronized(() async {
      _dataList.addAll(dataList);
      itemsRectHolder.clear();
      notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
      notifyActionASyncListeners(FreeScrollActionAsyncType.notifyIndexShow);
    });
  }

  ///add data to head
  ///previewHeight measure add item height or not
  Future<void> addDataToHead(List<T> dataList, {bool measureHeight = true}) {
    return _lock.synchronized(() async {
      ///do nothing
      if (dataList.isEmpty) {
        return;
      }

      ///data list
      if (_dataList.isNotEmpty && itemsRectHolder.isEmpty) {
        await waitForPostFrameCallback();
      }

      ///if can scroll
      if (hasClients && position.maxScrollExtent > 0) {
        ///insert all data
        _dataList.insertAll(0, dataList);
        _dataListOffset = _dataListOffset + dataList.length;
        itemsRectHolder.clear();

        ///preview the height and add it to negative height
        double formerTopData = _negativeHeight;
        if (_negativeHeight != negativeInfinityValue && measureHeight) {
          ///preview model
          PreviewModel? previewModel = await _previewLastController.previewItemsHeight(
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
        notifyActionASyncListeners(FreeScrollActionAsyncType.notifyIndexShow);
      } else {
        ///notify data
        setDataAndScrollTo(
          [...dataList, ..._dataList],
          index: max(0, dataList.length - 1),
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
    if (dataList.isNotEmpty && index >= dataList.length) {
      throw ArgumentError('Index $index is out of bounds for dataList of length ${dataList.length}.');
    }
    if (index < 0) {
      throw ArgumentError('Index $index is out of bounds for dataList of length ${dataList.length}.');
    }

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
    if (dataList.isNotEmpty && index >= dataList.length) {
      throw ArgumentError('Index $index is out of bounds for dataList of length ${dataList.length}.');
    }
    if (index < 0) {
      throw ArgumentError('Index $index is out of bounds for dataList of length ${dataList.length}.');
    }

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
    RectHolder? holder = itemsRectHolder[index];

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
      List<int> keys = itemsRectHolder.keys.toList();

      if (keys.isEmpty) {
        return Future.delayed(Duration.zero);
      }

      ///keys
      double pixels = position.pixels;
      int currentIndex = keys.first;
      for (int key in itemsRectHolder.keys) {
        RectHolder? holder = itemsRectHolder[key];
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

  ///检查尾屏
  FreeFixIndexOffset? _checkFixIndexLastScreen(
    PreviewModel? previewModel,
    int index,
    double anchor,
    FreeScrollType align,
  ) {
    ///空的
    if (previewModel == null) {
      return null;
    }

    ///列表高度
    double listviewHeight = previewModel.listviewHeight;

    ///预览高度都直接不满一屏，直接清零
    if (previewModel.totalHeight + footerViewHeight < listviewHeight) {
      return FreeFixIndexOffset(
        fixIndex: 0,
        fixAnchor: 0,
        fixAlign: (align == FreeScrollType.bottomToTop) ? FreeScrollType.directJumpTo : align,
      );
    }

    ///此时我们逐渐进行逼近直到找到尾屏数据允许的index和offset(正常情况下我们设置的cacheExtent足够支撑)
    else {

      ///极点补正
      double height = footerViewHeight;
      for (int s = dataList.length - 1; s >= index; s--) {
        height = (previewModel.itemHeights[s] ?? 0) + height;
      }
      if (height < (anchor + listviewHeight)) {
        double testHeight = footerViewHeight;
        for (int s = dataList.length - 1; s >= 0; s--) {
          testHeight = (previewModel.itemHeights[s] ?? 0) + testHeight;
          if (testHeight > listviewHeight) {
            return FreeFixIndexOffset(
              fixIndex: s,
              fixAnchor: testHeight - listviewHeight,
              fixAlign: (align == FreeScrollType.bottomToTop) ? FreeScrollType.directJumpTo : align,
            );
          }
        }
      }

      ///常规补正(保证anchor大于零)
      int fixIndex = index;
      double fixAnchor = anchor;
      for (int s = index - 1; s >= 0; s--) {
        if (previewModel.itemHeights[s] != null) {
          fixIndex = s;
          fixAnchor = fixAnchor + previewModel.itemHeights[s]!;
          if (fixAnchor >= 0) {
            break;
          }
        }
      }
      return FreeFixIndexOffset(
        fixIndex: fixIndex,
        fixAnchor: fixAnchor,
        fixAlign:  align,
      );
    }
  }

  ///检查尾屏
  FreeFixIndexOffset? _checkFixIndexFistScreen(
    PreviewModel? previewModel,
    int index,
    double anchor,
    FreeScrollType align,
  ) {
    ///空的
    if (previewModel == null) {
      return null;
    }

    ///预览高度都直接不满一屏，直接清零
    if (previewModel.totalHeight + footerViewHeight < previewModel.listviewHeight) {
      return FreeFixIndexOffset(
        fixIndex: 0,
        fixAnchor: 0,
        fixAlign: (align == FreeScrollType.topToBottom) ? FreeScrollType.directJumpTo : align,
      );
    }

    ///计算是否越界，最小值为fixedIndex =0，fixedAnchor=0；
    else {
      ///零点补正
      double height = headerViewHeight;
      for (int s = 0; s < index; s++) {
        height = (previewModel.itemHeights[s] ?? 0) + height;
      }
      if (height < anchor.abs()) {
        return FreeFixIndexOffset(
          fixIndex: 0,
          fixAnchor: 0,
          fixAlign: (align == FreeScrollType.topToBottom) ? FreeScrollType.directJumpTo : align,
        );
      }
    }
    return null;
  }

  ///scroll to index just by align
  Future scrollToIndexSkipAlign(
    int index, {
    required FreeScrollType align,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeIn,
    double anchorOffset = 0,
  }) async {
    ///你不能瞎搞影响性能
    if (listViewHeight > 0 && anchorOffset.abs() > listViewHeight) {
      throw ArgumentError('anchorOffset is too large.');
    }

    ///越界错误提示
    if (dataList.isNotEmpty && index >= dataList.length) {
      throw ArgumentError('Index $index is out of bounds for dataList of length ${dataList.length}.');
    }

    ///越界错误提示
    if (index < 0) {
      throw ArgumentError('Index $index is out of bounds for dataList of length ${dataList.length}.');
    }

    ///加上顶部view的高度(这里的意思是如果我们存在headerViewHeight，滚动到第0项时需要考虑header)
    double trueAnchorOffset = (index == 0) ? (anchorOffset + headerViewHeight) : anchorOffset;

    ///修正的index和修正的偏移量，保证不出界，后续直接用来作为跳转位置
    int fixedIndex = index;
    double fixedAnchor = trueAnchorOffset;
    FreeScrollType fixedAlign = align;

    ///如果偏移量大于0，我们只需要尾屏修正
    if (trueAnchorOffset >= 0) {
      ///尾屏幕
      PreviewModel? previewLastModel = await _previewLastController.previewItemsHeight(
        dataList.length,
        previewReverse: true,
        previewExtent: max(0, trueAnchorOffset),
      );

      ///对位置进行修正
      FreeFixIndexOffset? lastScreen = _checkFixIndexLastScreen(
        previewLastModel,
        index,
        trueAnchorOffset,
        align,
      );

      ///修正
      fixedIndex = lastScreen?.fixIndex ?? fixedIndex;
      fixedAnchor = lastScreen?.fixAnchor ?? fixedAnchor;
      fixedAlign = lastScreen?.fixAlign ?? fixedAlign;
    }

    ///如果偏移量小于0，我们需要首屏尾屏同时修正
    else {
      ///获取高度预览
      List<PreviewModel?> previewList = await Future.wait([
        _previewFirstController.previewItemsHeight(
          dataList.length,
          previewReverse: false,
          previewExtent: max(0, listViewHeight),
        ),
        _previewLastController.previewItemsHeight(
          dataList.length,
          previewReverse: true,
          previewExtent: max(0, trueAnchorOffset),
        ),
      ]);

      ///首屏预览
      PreviewModel? previewFirstModel = previewList[0];

      ///尾屏预览
      PreviewModel? previewLastModel = previewList[1];

      ///对位置进行修正
      FreeFixIndexOffset? firstScreen = _checkFixIndexFistScreen(
        previewFirstModel,
        index,
        trueAnchorOffset,
        align,
      );

      ///修正
      fixedIndex = firstScreen?.fixIndex ?? fixedIndex;
      fixedAnchor = firstScreen?.fixAnchor ?? fixedAnchor;
      fixedAlign = firstScreen?.fixAlign ?? fixedAlign;

      ///对位置进行修正
      FreeFixIndexOffset? lastScreen = _checkFixIndexLastScreen(
        previewLastModel,
        fixedIndex,
        fixedAnchor,
        fixedAlign,
      );

      ///修正
      fixedIndex = lastScreen?.fixIndex ?? fixedIndex;
      fixedAnchor = lastScreen?.fixAnchor ?? fixedAnchor;
      fixedAlign = lastScreen?.fixAlign ?? fixedAlign;
    }

    ///区分执行跳转及其他
    switch (fixedAlign) {
      case FreeScrollType.bottomToTop:

        ///Clear existing data and cached maps
        _setNegativeHeight(negativeInfinityValue);
        itemsRectHolder.clear();
        _dataListOffset = fixedIndex;
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyAnimStop);
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
        await waitForPostFrameCallback();

        AnimationData data = AnimationData(
          duration,
          curve,
          listViewHeight + fixedAnchor,
          0 + fixedAnchor,
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
        itemsRectHolder.clear();
        _dataListOffset = fixedIndex;
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyAnimStop);
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
        await waitForPostFrameCallback();

        AnimationData data = AnimationData(
          duration,
          curve,
          -listViewHeight + fixedAnchor,
          0 + fixedAnchor,
          FreeScrollType.topToBottom,
        );

        ///start animation
        return _handleAnimation(notifyActionASyncListeners(
          FreeScrollActionAsyncType.notifyAnimStart,
          data: data,
        ));
      case FreeScrollType.directJumpTo:

        ///other kind
        _setNegativeHeight(negativeInfinityValue);
        itemsRectHolder.clear();
        _dataListOffset = fixedIndex;
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyAnimStop);
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
        if (hasClients && position.hasPixels) {
          jumpTo(fixedAnchor);
        }
        await waitForPostFrameCallback();
        return notifyActionASyncListeners(
          FreeScrollActionAsyncType.notifyIndexShow,
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
        FreeScrollActionAsyncType.notifyIndexShow,
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
class FreeScrollListViewState<T> extends State<FreeScrollListView> with TickerProviderStateMixin {
  ///throttler
  late Throttler _throttler;

  ///function listener
  late FreeScrollListSyncListener _syncListener;

  ///function listener
  late FreeScrollListASyncListener _aSyncListener;

  ///time stamp debouncer
  final TimeStampDeBouncer _timeStampDebouncer = TimeStampDeBouncer();

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
          if (widget.controller.hasClients && widget.controller.position.hasPixels) {
            widget.controller.position.jumpTo(widget.controller.position.pixels);
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
        case FreeScrollActionAsyncType.notifyIndexShow:
          _notifyIndexAndOnShow();
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
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
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
      if (offsetTo <= maxScrollExtent && widget.controller.hasClients && widget.controller.position.hasPixels) {
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
          widget.controller.itemsRectHolder[maxIndex] != null &&
          widget.controller.itemsRectHolder[maxIndex]!.isOnScreen) {
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
  void _notifyIndexAndOnShow() {
    Future.delayed(const Duration(milliseconds: 50)).then((_) {
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
    ///获取方向
    AxisDirection axisDirection = _getDirection(context);

    ScrollPhysics physics = widget.physics ??
        FreeLimitShrinkOverScrollPhysics(
          controller: widget.controller,
        );

    ///最外层裁剪，内部不裁剪
    return ClipRect(
      clipBehavior: widget.clipBehavior,
      child: LayoutBuilder(
        builder: (context, constraints) {
          ///检查显示区域大小的变化
          _checkMaxHeight(constraints);

          return NotificationListener<ScrollNotification>(
            onNotification: _handleNotification,
            child: Scrollable(
              key: widget.controller._listViewKey,
              axisDirection: axisDirection,
              controller: widget.controller,
              physics: physics,
              clipBehavior: Clip.none,
              viewportBuilder: (BuildContext context, ViewportOffset offset) {
                return Builder(builder: (context) {
                  ///Build negative [ScrollPosition] for the negative scrolling [Viewport].
                  final ScrollableState state = Scrollable.of(context);
                  final _NegativedScrollPosition negativeOffset = _NegativedScrollPosition(
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
                  int positiveDataLength = widget.controller._dataList.length - widget.controller._dataListOffset;

                  ///negative
                  List<Widget> sliverNegative = <Widget>[
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          int actualIndex = negativeDataLength - index - 1;
                          return AnchorItemWrapper(
                            reverse: widget.reverse,
                            actualIndex: actualIndex,
                            controller: widget.controller,
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
                          return AnchorItemWrapper(
                            reverse: widget.reverse,
                            actualIndex: actualIndex,
                            controller: widget.controller,
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
                      ? _buildScrollShrinkWrap(
                          constraints,
                          axisDirection,
                          sliverNegative,
                          sliverPositive,
                          negativeOffset,
                          offset,
                        )
                      : _buildScrollNormal(
                          constraints,
                          axisDirection,
                          sliverNegative,
                          sliverPositive,
                          negativeOffset,
                          offset,
                        );
                });
              },
            ),
          );
        },
      ),
    );
  }

  ///检查控件最大适用的高度
  void _checkMaxHeight(BoxConstraints constraints) {
    //没有值的时候进行赋值
    widget.controller._listviewMaxHeight ??= constraints.maxHeight;
    //不相等
    if (widget.controller._listviewMaxHeight != constraints.maxHeight) {
      if (widget.controller._listviewMaxHeight! < constraints.maxHeight) {
        _listViewAreaBigger(widget.controller._listviewMaxHeight!, constraints.maxHeight);
      } else {
        _listViewAreaSmaller(widget.controller._listviewMaxHeight!, constraints.maxHeight);
      }
      widget.controller._listviewMaxHeight = constraints.maxHeight;
    }
  }

  ///列表区域变大
  void _listViewAreaBigger(double oldValue, double newValue) {
    if (widget.shrinkWrap) {
      widget.controller._resetIndexByHeightAdd(oldValue, newValue);
    }
    _notifyIndexAndOnShow();
  }

  ///列表区域变小
  void _listViewAreaSmaller(double oldValue, double newValue) {
    _notifyIndexAndOnShow();
  }

  ///自适应情况下的build
  Widget _buildScrollShrinkWrap(
    BoxConstraints constraints,
    AxisDirection axisDirection,
    List<Widget> sliverNegative,
    List<Widget> sliverPositive,
    ViewportOffset negativeOffset,
    ViewportOffset offset,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ///此控件预览首屏幕
        AdditionPreview(
          padding: EdgeInsets.zero,
          maxHeight: constraints.maxHeight,
          itemBuilder: widget.builder,
          controller: widget.controller._previewFirstController,
        ),

        ///此控件预览最后一屏
        AdditionPreview(
          padding: EdgeInsets.zero,
          maxHeight: constraints.maxHeight,
          itemBuilder: widget.builder,
          controller: widget.controller._previewLastController,
        ),

        ///负index(被锚定跳过的)
        if (widget.controller._dataListOffset > 0)
          Viewport(
            axisDirection: flipAxisDirection(axisDirection),
            anchor: 1.0,
            offset: negativeOffset,
            clipBehavior: Clip.none,
            cacheExtent: widget.cacheExtent,
            slivers: sliverNegative,
          ),

        ///positive
        ShrinkWrappingViewport(
          axisDirection: axisDirection,
          clipBehavior: Clip.none,
          offset: offset,
          slivers: sliverPositive,
        ),
      ],
    );
  }

  ///正常情况下的build listView
  Widget _buildScrollNormal(
    BoxConstraints constraints,
    AxisDirection axisDirection,
    List<Widget> sliverNegative,
    List<Widget> sliverPositive,
    ViewportOffset negativeOffset,
    ViewportOffset offset,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ///此控件预览首屏幕
        AdditionPreview(
          padding: EdgeInsets.zero,
          maxHeight: constraints.maxHeight,
          itemBuilder: widget.builder,
          controller: widget.controller._previewFirstController,
        ),

        ///此控件预览最后一屏
        AdditionPreview(
          padding: EdgeInsets.zero,
          maxHeight: constraints.maxHeight,
          itemBuilder: widget.builder,
          controller: widget.controller._previewLastController,
        ),

        ///负index(被锚定跳过的)
        Viewport(
          axisDirection: flipAxisDirection(axisDirection),
          anchor: 1.0,
          offset: negativeOffset,
          clipBehavior: Clip.none,
          cacheExtent: widget.cacheExtent,
          slivers: sliverNegative,
        ),

        ///正index
        Viewport(
          offset: offset,
          axisDirection: axisDirection,
          cacheExtent: widget.cacheExtent,
          clipBehavior: widget.clipBehavior,
          slivers: sliverPositive,
        ),
      ],
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
    if (notification is ScrollStartNotification && notification.dragDetails != null) {
      _cancelAnimation();
      widget.controller.notifyCheckRectListeners();
    }

    ///加载之前的消息，FormerMessages
    if (notification.metrics.pixels >= (notification.metrics.maxScrollExtent - widget.loadOffset)) {
      _timeStampDebouncer.run(widget.willReachTail);
    }

    ///加载新的消息
    if (notification.metrics.pixels <= (widget.controller._negativeHeight + widget.loadOffset)) {
      _timeStampDebouncer.run(widget.willReachHead);
    }

    ///when animating do noting
    if (widget.controller.isAnimating) {
      return false;
    }

    ///scroll end, check need reset index or not
    if (notification is ScrollEndNotification) {
      widget.controller._resetIndexIfNeeded();
      _notifyIndexAndOnShow();
    }

    ///notify the on show
    if (notification is ScrollUpdateNotification) {
      _notifyIndex();
      if ((widget.notifyItemShowWhenAllTypeScroll ||
          (widget.notifyItemShowWhenGestureScroll && notification.dragDetails != null))) {
        if (_throttler.duration.inMilliseconds == 0) {
          _notifyOnShow();
        } else {
          _throttler.throttle(() {
            _notifyOnShow();
          });
        }
      }
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
    for (int key in widget.controller.itemsRectHolder.keys) {
      RectHolder? holder = widget.controller.itemsRectHolder[key];

      if (holder == null || !holder.isOnScreen) {
        continue;
      }

      double? rectBottom = holder.rectBottom();
      double? rectTop = holder.rectTop();
      if (rectBottom == null || rectTop == null) {
        continue;
      }

      ///offset top
      double offsetTop = rectTop - widget.controller.position.pixels;
      double offsetBottom = rectBottom - widget.controller.position.pixels;

      ///Listview height
      if ((offsetTop >= 0 && offsetBottom <= listViewHeight) || offsetTop <= 0 && offsetBottom >= listViewHeight) {
        keys.add(key);
      }
    }

    ///keys data
    if (keys.isNotEmpty) {
      widget.onItemShow?.call(keys);
    }
  }

  ///notify index if changed
  void _notifyIndex() {
    if (!mounted) {
      return;
    }

    double pixels = widget.controller.position.pixels;

    ///listview height
    double listViewHeight = widget.controller.listViewHeight;

    ///get sorted key
    List<int> sortedKeys = widget.controller.itemsRectHolder.keys.toList();

    ///start index
    for (int key in sortedKeys) {
      RectHolder? holder = widget.controller.itemsRectHolder[key];
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
    if (sortedKeys.isEmpty) {
      return;
    }
    for (int s = sortedKeys.length - 1; s >= 0; s--) {
      int key = sortedKeys[s];
      RectHolder? holder = widget.controller.itemsRectHolder[key];
      if (holder == null || !holder.isOnScreen) {
        continue;
      }

      double? rectTop = holder.rectTop();
      if (rectTop == null) {
        continue;
      }

      double offsetTop = rectTop - pixels;
      if (offsetTop.round() < listViewHeight) {
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
Future waitForPostFrameCallback() {
  final Completer<void> completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    completer.complete();
  });
  return completer.future;
}
