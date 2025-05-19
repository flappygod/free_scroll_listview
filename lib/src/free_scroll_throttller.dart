import 'package:flutter/material.dart';
import 'dart:async';

class Throttler {
  //节流间隔时间
  final Duration duration;

  //标记当前是否处于节流状态
  bool _isThrottling = false;

  //构造函数，允许自定义节流间隔时间，默认为 100ms
  Throttler({
    this.duration = const Duration(milliseconds: 120),
  });

  //节流方法
  void throttle(VoidCallback action) {
    //如果当前处于节流状态，直接丢弃任务
    if (_isThrottling) {
      return;
    }

    //执行任务
    action.call();

    //进入节流状态
    _isThrottling = true;

    //在指定时间后退出节流状态
    Future.delayed(duration).then((_) {
      _isThrottling = false;
    });
  }
}
