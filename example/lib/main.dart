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

  @override
  void initState() {
    List<String> dataList = [];
    for (int s = 0; s < 100; s++) {
      dataList.add((s).toString());
    }
    _controller.setDataAndScrollTo(
      dataList,
      index: 80,
      duration: Duration.zero,
      align: FreeScrollAlign.directJumpTo,
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

  ///reset data and scroll align
  Future _resetDataAndScrollAlign() {
    List<String> dataList = [];
    for (int s = 0; s < 100; s++) {
      dataList.add(s.toString());
    }
    return _controller.setDataAndScrollTo(
      dataList.toList(),
      index: 99,
      /*duration: Duration.zero,
      align: FreeScrollAlign.directJumpTo,*/
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.grey,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _resetDataAndScrollAlign();
              },
              child: Container(
                width: double.infinity,
                height: 35,
                margin: EdgeInsets.fromLTRB(
                    20, 20 + MediaQuery.of(context).padding.top, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(17.5),
                ),
              ),
            ),
          ),
          Container(
            color: Colors.grey,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _controller.scrollToIndex(
                  99,
                );
              },
              child: Container(
                width: double.infinity,
                height: 35,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(17.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              alignment: Alignment.topCenter,
              child: FreeScrollListView(
                reverse: true,
                shrinkWrap: true,
                controller: _controller,
                headerView: Container(
                  height: 60,
                  color: Colors.redAccent,
                ),
                footerView: Container(
                  height: 60,
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
          ),
        ],
      ),
    );
  }
}
