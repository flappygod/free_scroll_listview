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
  final FreeScrollListViewController _controller = FreeScrollListViewController();

  double height = 0;

  @override
  void initState() {
    List<String> dataList = [];
    for (int s = 0; s < 6; s++) {
      dataList.add((s).toString());
    }
    _controller.setDataAndScrollTo(
      dataList,
      index: 5,
      duration: Duration.zero,
      align: FreeScrollType.directJumpTo,
    );

    super.initState();
  }

  ///add data to tail
  Future _checkAddTail() {
    int last = int.tryParse(_controller.dataList.last) ?? 0;
    List<String> dataList = [];
    for (int s = 0; s < 5; s++) {
      dataList.add((s + last + 1).toString());
    }
    return _controller.addDataToTail(dataList);
  }

  ///add data to top
  Future _checkAddHead() {
    int first = int.tryParse(_controller.dataList.first) ?? 0;
    List<String> dataList = [];
    for (int s = 0; s < 5; s++) {
      dataList.add((first - s - 1).toString());
    }
    return _controller.addDataToHead(dataList.reversed.toList());
  }

  ///重设数据并跳转到指定位置
  Future _resetDataAndScrollAlign() {
    List<String> dataList = [];
    for (int s = 0; s < 20; s++) {
      dataList.add(s.toString());
    }
    return _controller.setDataAndScrollTo(
      dataList.toList(),
      index: 14,
      /*duration: Duration.zero,
      align: FreeScrollType.directJumpTo,*/
      duration: const Duration(milliseconds: 320),
      align: FreeScrollType.topToBottom,
    );
  }

  ///重设数据并跳转到指定位置
  Future _resetDataAndScrollAlign2() {
    List<String> dataList = [];
    for (int s = 0; s < 12; s++) {
      dataList.add((s).toString());
    }
    return _controller.setDataAndScrollTo(
      dataList,
      index: 3,
      duration: const Duration(milliseconds: 320),
      align: FreeScrollType.directJumpTo,
    );
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
                      _resetDataAndScrollAlign();
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
                      _resetDataAndScrollAlign2();
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
                    onTap: () {
                      if (height == 0) {
                        height = 450;
                      } else {
                        height = 0;
                      }
                      setState(() {});
                    },
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
                physics: const AlwaysScrollableScrollPhysics(),
                /*headerView: Container(
                  height: 60,
                  color: Colors.redAccent,
                ),
                footerView: Container(
                  height: 60,
                  color: Colors.blue,
                ),*/
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
                  return Container(
                    height: 75,
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
              height: height,
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
