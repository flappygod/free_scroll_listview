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
  //列表总体高度
  final GlobalKey _listViewKey = GlobalKey();

  //顶部View
  final GlobalKey _headerKey = GlobalKey();

  //底部View
  final GlobalKey _footerKey = GlobalKey();

  //加锁
  final Lock _lock = Lock();

  //数据源
  final List<T> _dataList;

  //数据偏移
  int _dataListOffset;

  //同步监听
  final Set<FreeScrollListSyncListener> _syncListeners = {};

  //异步监听
  final Set<FreeScrollListASyncListener> _asyncListeners = {};

  //check rect listeners
  final Set<VoidCallback> _checkRectListeners = {};

  //尾部一屏幕的预览
  final AdditionPreviewController<T> _previewLastController =
      AdditionPreviewController<T>();

  //头部一屏幕的预览
  final AdditionPreviewController<T> _previewFirstController =
      AdditionPreviewController<T>();

  //item maps
  final SplayTreeMap<int, RectHolder> itemsRectHolder =
      SplayTreeMap<int, RectHolder>();

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

  //当前是否正在动画中
  bool get isAnimating {
    return _isAnimating;
  }

  //获取当前数据偏移
  int dataListOffset() {
    return _dataListOffset;
  }

  //当前在屏幕上起始的index
  int get currentStartIndex {
    return _currentStartIndex;
  }

  //当前在屏幕上结束的index
  int get currentEndIndex {
    return _currentEndIndex;
  }

  ///这里获取的值是当前item顶部相对于View的距离
  double? getItemTopScrollOffset(int index) {
    if (!hasClients || !position.hasPixels) {
      return null;
    }
    double? offsetOne = itemsRectHolder[index]?.rectTop();
    if (offsetOne == null) {
      return null;
    }
    double offsetTwo = position.pixels;
    return offsetTwo - offsetOne;
  }

  ///这里获取的值是当前item底部相对于View的距离
  double? getItemBottomScrollOffset(int index) {
    if (!hasClients || !position.hasPixels) {
      return null;
    }
    double? offsetOne = itemsRectHolder[index]?.rectTop();
    double? height = itemsRectHolder[index]?.rectHeight();
    if (offsetOne == null || height == null) {
      return null;
    }
    double offsetTwo = position.pixels;
    return offsetTwo - offsetOne - height;
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

  ///设置负向滚动的最大高度(当前控件只考虑index 0，而实际需要考虑headerViewHeight)
  void _setNegativeHeight(double height) {
    if (!hasClients || position is! _NegativedScrollPosition) {
      return;
    }
    //转换为我们需要的
    final negativedPosition = position as _NegativedScrollPosition;
    //设置负向滚动的值
    if (height.isNegative && height.isInfinite) {
      //负无穷
      negativedPosition.minScrollExtend = negativeInfinityValue;
      _negativeHeight = negativeInfinityValue;
    } else {
      //真实值(这里的高度不将headerView算进去)
      negativedPosition.minScrollExtend =
          (height - headerViewHeight).removeTinyFraction();
      _negativeHeight = height.removeTinyFraction();
    }
  }

  ///某个Item将要被移除掉了
  void notifyItemRectRemoveOnScreen(int index) {
    //如果是index == 0的item被移除掉了，设置负向滚动距离为无限
    /*if (index == 0) {
      _setNegativeHeight(negativeInfinityValue);
    }*/
  }

  ///某个Item展示在屏幕上了
  void notifyItemRectShowOnScreen(int index) {
    _checkResetLastScreenIndex();
    _checkResetMinScrollExtend();
    _checkResetDeleteFirstItem(index);
  }

  ///检查是否需要resetIndex
  void _checkResetLastScreenIndex() {
    //已经不需要重新锚定了
    if (_dataListOffset == 0) {
      return;
    }

    ///最大的index
    int maxIndex = (dataList.length - 1);
    //当前列表高度
    double currentListViewHeight = listViewHeight;
    //计算最后一屏高度
    double lastScreenHeight = footerViewHeight;
    //反向计算
    for (int s = maxIndex; s >= _dataListOffset; s--) {
      //没有这个值
      final double? itemHeight = itemsRectHolder[s]?.rectHeight();
      if (itemHeight == null) {
        return;
      }
      lastScreenHeight += itemHeight;
    }
    //已经足够
    if (lastScreenHeight >= currentListViewHeight) {
      return;
    }

    ///否则的话我们就需要计算一下需要切换锚定Index的高度的大小是多少
    double needChangeOffset = 0;
    int? needChangeIndex;
    for (int s = _dataListOffset - 1; s >= 0; s--) {
      final double? itemHeight = itemsRectHolder[s]?.rectHeight();
      if (itemHeight == null) {
        break;
      }
      needChangeIndex = s;
      needChangeOffset += itemHeight;
    }
    //没有找到
    if (needChangeIndex == null || _dataListOffset == needChangeOffset) {
      return;
    }

    ///重置当前的锚定index,
    _dataListOffset = needChangeIndex;
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
    //必须要有值且正常
    if (itemsRectHolder.isEmpty ||
        !hasClients ||
        position is! _NegativedScrollPosition) {
      return;
    }

    //对当前的滚动的position进行一个转换
    _NegativedScrollPosition currentPosition =
        (position as _NegativedScrollPosition);

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
  ///当数据变化的时候，min scroll 可能发生变化，因为主要是第一个item去设置min scroll，所以
  ///当第一个item、不是滚动状态(滚动状态自然触发)、不是动画状态(动画状态自然触发)、当第一个item必须有值、滚动距离已经越界了的情况下
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
    //触发一下保证能够回弹回去
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
      if ((firstRectBottom ?? 0) - scrollOffset < currentListViewHeight) {
        return;
      }
      //跳转
      double reIndexOffset = scrollOffset - itemTop;
      //执行重新锚定
      _dataListOffset = lastScreenIndex;
      //清空缓存
      itemsRectHolder.clear();
      //这种锚定就直接设置为负向无限滚动后等待自动刷新赋值最小negative高度
      _setNegativeHeight(negativeInfinityValue);
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

  ///在顶部添加数据
  Future<void> addDataToHead(
    List<T> dataList, {
    bool tryToMeasureAddedItem = true,
    bool skipFirstScreenPreview = false,
    bool skipLastScreenPreview = false,
  }) {
    return _lock.synchronized(() async {
      ///do nothing
      if (dataList.isEmpty) {
        return;
      }

      ///数据都是空的，请等待
      if (_dataList.isNotEmpty && itemsRectHolder.isEmpty) {
        await waitForPostFrameCallback();
      }

      ///有数据而且能滚动
      if (hasClients && position.maxScrollExtent > 0) {
        ///添加数据
        _dataList.insertAll(0, dataList);

        ///缓存之前的
        int formerDataListOffset = _dataListOffset;

        ///位置移动
        _dataListOffset = _dataListOffset + dataList.length;

        ///清空数据
        itemsRectHolder.clear();

        ///如果不是负无限就进行偏移
        if (_negativeHeight != negativeInfinityValue && tryToMeasureAddedItem) {
          ///之前的高度进行缓存
          double formerTopData = _negativeHeight;

          ///预览高度
          PreviewModel? previewModel =
              await _previewLastController.previewItemsHeight(
            dataList.length,
          );

          ///总高度
          double? previewHeight = previewModel?.totalHeight;

          ///所有的item都被预览了
          if ((previewModel?.allPreviewed ?? false) && previewHeight != null) {
            ///重新设置高度
            _setNegativeHeight(formerTopData - previewHeight);
          }
        }

        ///通知刷新数据
        notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
        notifyActionASyncListeners(FreeScrollActionAsyncType.notifyIndexShow);

        ///从0变为非0，这里需要特殊处理headerViewHeight高度
        double headerHeight = headerViewHeight;
        if (formerDataListOffset == 0 && headerHeight != 0) {
          position.jumpTo(position.pixels - headerHeight);
        }
      } else {
        ///直接设置位置进行跳转
        setDataAndScrollTo(
          [...dataList, ..._dataList],
          index: max(0, dataList.length - 1),
          align: FreeScrollType.directJumpTo,
          skipFirstScreenPreview: skipFirstScreenPreview,
          skipLastScreenPreview: skipLastScreenPreview,
        );
      }
    });
  }

  ///设置index并跳转到指定的位置去
  Future setDataAndScrollTo(
    List<T> dataList, {
    int index = 0,
    FreeScrollType align = FreeScrollType.topToBottom,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeIn,
    double anchorOffset = 0,
    bool skipFirstScreenPreview = false,
    bool skipLastScreenPreview = false,
  }) {
    if (dataList.isNotEmpty && index >= dataList.length) {
      throw ArgumentError(
          'Index $index is out of bounds for dataList of length ${dataList.length}.');
    }
    if (index < 0) {
      throw ArgumentError(
          'Index $index is out of bounds for dataList of length ${dataList.length}.');
    }

    ///清空数据
    _dataList.clear();
    _dataList.addAll(dataList);

    ///跳转到指定位置并设置动画
    return scrollToIndexSkipAlign(
      index,
      align: align,
      curve: curve,
      duration: duration,
      anchorOffset: anchorOffset,
      skipFirstScreenPreview: skipFirstScreenPreview,
      skipLastScreenPreview: skipLastScreenPreview,
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
        skipLastScreenPreview: true,
        skipFirstScreenPreview: true,
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
    bool skipFirstScreenPreview = false,
    bool skipLastScreenPreview = false,
  }) async {
    if (dataList.isNotEmpty && index >= dataList.length) {
      throw ArgumentError(
          'Index $index is out of bounds for dataList of length ${dataList.length}.');
    }
    if (index < 0) {
      throw ArgumentError(
          'Index $index is out of bounds for dataList of length ${dataList.length}.');
    }

    ///根本都没完成初始化
    if (!hasClients) {
      return;
    }

    ///时间太短，直接跳转
    if (duration.inMilliseconds < 50) {
      return scrollToIndexSkipAlign(
        index,
        align: FreeScrollType.directJumpTo,
        curve: curve,
        duration: duration,
        anchorOffset: anchorOffset,
        skipFirstScreenPreview: skipFirstScreenPreview,
        skipLastScreenPreview: skipLastScreenPreview,
      );
    }

    ///这里主要是停止当前的动画
    if (isAnimating) {
      notifyActionSyncListeners(FreeScrollActionSyncType.notifyAnimStop);
      notifyActionSyncListeners(FreeScrollActionSyncType.notifyData);
      await waitForPostFrameCallback();
    }

    ///所有的数据刷新一遍
    notifyCheckRectListeners();

    ///找到当前的index是否在屏幕上显示
    RectHolder? holder = itemsRectHolder[index];

    ///正在显示中而且没有在动画中
    if (holder != null && holder.isOnScreen && !_isAnimating) {
      double toOffset = holder.rectTop()! + anchorOffset;
      //底部限制
      if (hasClients && position.maxScrollExtent != double.maxFinite) {
        toOffset = min(position.maxScrollExtent, toOffset);
      }
      //顶部限制
      if (!position.minScrollExtent.isInfinite) {
        toOffset = max(position.minScrollExtent, toOffset);
      }
      return _handleAnimation(animateTo(
        toOffset,
        duration: duration,
        curve: curve,
      ));
    }

    ///计算Align
    else {
      ///根据位置来做处理
      FreeScrollType align = FreeScrollType.topToBottom;
      List<int> keys = itemsRectHolder.keys.toList();

      if (keys.isEmpty) {
        return Future.delayed(Duration.zero);
      }

      ///键值
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

      ///第一个默认
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
        skipFirstScreenPreview: skipFirstScreenPreview,
        skipLastScreenPreview: skipLastScreenPreview,
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
        fixAlign: (align == FreeScrollType.bottomToTop)
            ? FreeScrollType.directJumpTo
            : align,
      );
    }

    ///此时我们逐渐进行逼近直到找到尾屏数据允许的index和offset(正常情况下我们设置的cacheExtent足够支撑)
    else {
      ///尾部顶点补正
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
              fixAlign: (align == FreeScrollType.bottomToTop)
                  ? FreeScrollType.directJumpTo
                  : align,
            );
          }
        }
      }

      ///常规补正(保证尾屏足够支撑)
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
        fixAlign: align,
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
    if (previewModel.totalHeight + footerViewHeight <
        previewModel.listviewHeight) {
      return FreeFixIndexOffset(
        fixIndex: 0,
        fixAnchor: 0,
        fixAlign: (align == FreeScrollType.topToBottom)
            ? FreeScrollType.directJumpTo
            : align,
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
          fixAlign: (align == FreeScrollType.topToBottom)
              ? FreeScrollType.directJumpTo
              : align,
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
    bool skipFirstScreenPreview = false,
    bool skipLastScreenPreview = false,
  }) async {
    ///你不能瞎搞影响性能
    double currentListViewHeight = listViewHeight;
    if (currentListViewHeight > 0 &&
        anchorOffset.abs() > currentListViewHeight) {
      throw ArgumentError('anchorOffset is too large.');
    }

    ///越界错误提示
    if (dataList.isNotEmpty && index >= dataList.length) {
      throw ArgumentError(
          'Index $index is out of bounds for dataList of length ${dataList.length}.');
    }

    ///越界错误提示
    if (index < 0) {
      throw ArgumentError(
          'Index $index is out of bounds for dataList of length ${dataList.length}.');
    }

    ///加上顶部view的高度(这里的意思是如果我们存在headerViewHeight，滚动到第0项时需要考虑header)
    double trueAnchorOffset =
        (index == 0) ? (anchorOffset + headerViewHeight) : anchorOffset;

    ///修正的index和修正的偏移量，保证不出界，后续直接用来作为跳转位置
    int fixedIndex = index;
    double fixedAnchor = trueAnchorOffset;
    FreeScrollType fixedAlign = align;

    ///如果偏移量大于0，我们只需要尾屏修正
    if (trueAnchorOffset >= 0) {
      ///尾屏幕
      PreviewModel? previewLastModel =
          await _previewLastController.previewItemsHeight(
        dataList.length,
        previewReverse: true,
        previewExtent: trueAnchorOffset,
        skip: skipLastScreenPreview,
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
          previewExtent: max(trueAnchorOffset.abs() - currentListViewHeight, 0),
          skip: skipFirstScreenPreview,
        ),
        _previewLastController.previewItemsHeight(
          dataList.length,
          previewReverse: true,
          previewExtent: trueAnchorOffset.abs(),
          skip: skipLastScreenPreview,
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
          currentListViewHeight + fixedAnchor,
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
          -currentListViewHeight + fixedAnchor,
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
    this.loadOffset = 200,
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

  ///time stamp de bouncer
  final TimeStampDeBouncer _timeStampDeBouncer = TimeStampDeBouncer();

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
    ///默认_startAnimation前会手动_cancelAnimation，为防止(非常非常特殊的)边界情况下的异常故如此处理
    _cancelAnimation(resetAnimationOffset: false);

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
  void _cancelAnimation({
    bool resetAnimationOffset = true,
  }) {
    if (_animationController?.isAnimating ?? false) {
      _animationController?.stop();
      _animationController?.reset();
      _animationController?.dispose();
      _animationController = null;
    }
    if (resetAnimationOffset) {
      _animationOffset = 0;
    }
  }

  ///如果有正在等待的任务，取消它(创建一个新的定时器)
  Timer? _debounceTimer;
  void _notifyIndexAndOnShow() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 60), () {
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
    //确保在销毁时取消定时器，避免内存泄漏
    _debounceTimer?.cancel();
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

      ///LayoutBuilder处理整个显示区域出现变化的情况
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
      //变大
      if (widget.controller._listviewMaxHeight! < constraints.maxHeight) {
        _listViewAreaBigger(
          widget.controller._listviewMaxHeight!,
          constraints.maxHeight,
        );
      } else {
        _listViewAreaSmaller(
          widget.controller._listviewMaxHeight!,
          constraints.maxHeight,
        );
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
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _cancelAnimation();
      widget.controller.notifyCheckRectListeners();
    }

    ///加载之前的消息，FormerMessages
    if (notification.metrics.pixels >=
        (notification.metrics.maxScrollExtent - widget.loadOffset)) {
      _timeStampDeBouncer.run(widget.willReachTail);
    }

    ///加载新的消息
    if (notification.metrics.pixels <=
        (widget.controller._negativeHeight + widget.loadOffset)) {
      _timeStampDeBouncer.run(widget.willReachHead);
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
          (widget.notifyItemShowWhenGestureScroll &&
              notification.dragDetails != null))) {
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
      if ((offsetTop >= 0 && offsetBottom <= listViewHeight) ||
          offsetTop <= 0 && offsetBottom >= listViewHeight) {
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

  ///部分情况下设置了minScrollExtent仍然会滚出去，这里需要特殊处理下
  final double _minScrollLimit = 120;

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

  ///设置最小
  set minScrollExtend(double data) {
    ///已经赋值了
    if (_minScrollExtend == data) {
      return;
    }
    _minScrollExtend = data;

    ///添加监听
    _callback = () {
      if (!hasPixels) {
        return;
      }
      if (minScrollExtend >= maxScrollExtent) {
        return;
      }
      if (_minScrollExtend == negativeInfinityValue) {
        return;
      }
      double limitPos =
          (_minScrollExtend - _minScrollLimit).removeTinyFraction();
      if (pixels >= limitPos) {
        return;
      }

      ///这里限制一下不能负得太多，导致滑动到莫名其妙的位置上去，因为有的时候设置了maxScrollExtent后生效有莫名其妙的时间差
      jumpTo(min(limitPos, 0));
    };
    removeListener(_callback);
    addListener(_callback);
  }

  ///最小Scroll
  double get minScrollExtend {
    return _minScrollExtend;
  }

  ///强制负向
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
