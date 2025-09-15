import 'package:flutter/foundation.dart';
import 'package:free_scroll_listview/free_scroll_listview.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ///controller
  final FreeScrollListViewController _controller =
      FreeScrollListViewController();

  double bottomHeight = 0;
  double itemHeight = 75;
  double itemFirstHeight = 75;

  @override
  void initState() {
    _resetStart();
    super.initState();
  }

  ///初始设置位置进行定位
  void _resetStart() {
    List<String> dataList = [];
    for (int s = 0; s < 100; s++) {
      dataList.add((s).toString());
    }
    _controller.setDataAndScrollTo(
      dataList,
      index: 35,
      duration: Duration.zero,
      align: FreeScrollType.directJumpTo,
      anchorOffset: 30,
    );
  }

  ///跳转到某个位置，尾部空间不足的情况
  Future _resetOne() {
    List<String> dataList = [];
    for (int s = 0; s < 100; s++) {
      dataList.add(s.toString());
    }
    return _controller.setDataAndScrollTo(
      dataList.toList(),
      index: 0,
      anchorOffset: 0,
      duration: const Duration(milliseconds: 320),
      align: FreeScrollType.bottomToTop,
    );
  }

  ///重设数据并跳转到指定位置
  Future _resetTwo() {
    List<String> dataList = [];
    for (int s = 0; s < 20; s++) {
      dataList.add((s).toString());
    }
    return _controller.setDataAndScrollTo(
      dataList,
      index: 9,
      duration: const Duration(milliseconds: 320),
      align: FreeScrollType.topToBottom,
    );
  }

  ///重设数据并跳转到指定位置
  void _resetThree() {
    if (bottomHeight == 0) {
      bottomHeight = 450;
    } else {
      bottomHeight = 0;
    }
    setState(() {});
  }

  ///重设数据并跳转到指定位置
  Future _resetFive() {
    return _controller.scrollToTop();
  }

  ///重设数据第四项
  void _resetFour() {
    if (itemHeight == 75) {
      itemHeight = 55;
    } else {
      itemHeight = 75;
    }
    setState(() {});
  }

  ///设置第一个项目的高度
  void _resetSix() {
    if (itemFirstHeight == 75) {
      itemFirstHeight = 0;
    } else {
      itemFirstHeight = 75;
    }
    setState(() {});
  }

  ///设置第一个项目的高度
  void _resetSeven() {
    int first = int.tryParse(_controller.dataList.first) ?? 0;
    List<String> dataList = [];
    for (int s = 0; s < 3; s++) {
      dataList.add((first - s - 1).toString());
    }
    _controller.addDataToHead(dataList.reversed.toList(), tryToMeasure: false);
  }

  ///add data to tail
  Future _checkAddTail() {
    int last = int.tryParse(_controller.dataList.last) ?? 0;
    List<String> dataList = [];
    for (int s = 0; s < 20; s++) {
      dataList.add((s + last + 1).toString());
    }
    return _controller.addDataToTail(dataList);
  }

  ///add data to top
  Future _checkAddHead() {
    int first = int.tryParse(_controller.dataList.first) ?? 0;
    List<String> dataList = [];
    for (int s = 0; s < 10; s++) {
      dataList.add((first - s - 1).toString());
    }
    return _controller.addDataToHead(dataList.reversed.toList(),
        tryToMeasure: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ///执行
            Row(
              children: [
                //按钮1
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      _resetOne();
                    },
                    child: Container(
                      height: 35,
                      alignment: Alignment.center,
                      child: const Text(
                        "1",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                //按钮2
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      //_resetTwo();
                      //_resetFour();
                      _resetSeven();
                      //_resetSix();
                    },
                    child: Container(
                      height: 35,
                      alignment: Alignment.center,
                      child: const Text(
                        "2",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                //按钮2
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _resetThree,
                    child: Container(
                      height: 35,
                      alignment: Alignment.center,
                      child: const Text(
                        "3",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              height: 10,
              color: Colors.red,
            ),
            Expanded(
              child: FreeScrollListView(
                reverse: true,
                shrinkWrap: true,
                controller: _controller,
                //physics: const AlwaysScrollableScrollPhysics(),
                headerView: Container(
                  height: 75,
                  color: Colors.redAccent,
                ),
                footerView: Container(
                  height: 75,
                  color: Colors.blue,
                ),
                onStartIndexChange: (int index) {
                  if (kDebugMode) {
                    print("A$index");
                  }
                },
                onEndIndexChange: (int index) {
                  if (kDebugMode) {
                    print("B$index");
                  }
                },
                onItemShow: (List<int> dataList) {
                  if (kDebugMode) {
                    print(dataList);
                  }
                },
                /*willReachTail: () {
                  return _checkAddTail();
                },
                willReachHead: () {
                  return _checkAddHead();
                },*/
                builder: (context, index) {
                  if (index == 1) {
                    return Container(
                      height: itemFirstHeight,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.black.withAlpha(20),
                            width: 0.5,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _controller.dataList[index],
                      ),
                    );
                  }
                  return Container(
                    height: itemHeight,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.black.withAlpha(20),
                          width: 0.5,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _controller.dataList[index],
                    ),
                  );
                },
              ),
            ),
            AnimatedContainer(
              height: bottomHeight,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeIn,
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}
