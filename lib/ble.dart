import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:ble/BaseEvent.dart';
import 'package:ble/DeviceBle.dart';
import 'package:ble/EventChannelConstant.dart';

class Ble {
  factory Ble() => getInstance();

  /// 方法调用通道
  static const MethodChannel _channel = const MethodChannel('flutter_ble');

  ///监听器
  DeviceListener deviceListener;

  static Ble _Ble;

  ///初始化消息通道
  Ble._init() {
    initEvent();
  }

  static Ble getInstance() {
    if (null == _Ble) {
      _Ble = Ble._init();
    }
    return _Ble;
  }

  /// 设置时间监听，需要监听一些状态的页面继承 DeviceListener接口即可
  void setDeviceListener(DeviceListener listener) {
    this.deviceListener = listener;
    print("初始化deviceListener————————");
  }

  ///查看手机版本号
  Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  ///检查手机是否支持蓝牙
  Future<bool> get isSupport async {
    bool isSupport = await _channel.invokeMethod('isSupport');
    return isSupport;
  }

  ///检查手机蓝牙是否打开
  Future<bool> get isEnabled async {
    bool isEnabled = await _channel.invokeMethod('isEnabled');
    return isEnabled;
  }

  ///开始扫描蓝牙
  get startScanBluetooth {
    _channel.invokeMethod('startScanBluetooth');
  }

  ///停止扫描蓝牙
  get stopScanBluetooth {
    _channel.invokeMethod('stopScanBluetooth');
  }

  ///开始连接蓝牙
  /// address 蓝牙连接地址
  void connect(String address) {
    _channel.invokeMethod('connect', {"address": address});
  }

  /// 打开手机蓝牙
  void enabled() {
    _channel.invokeMethod('enabled');
  }

  ///断开蓝牙连接
  void disconnect() {
    _channel.invokeMethod('disconnect');
  }

  ///当前蓝牙连接状态
  /// connected 已连接
  /// connecting 正在连接
  /// disconnect 未连接
  Future<String> get status async {
    String status = await _channel.invokeMethod('status') as String;
    return status;
  }

  ///蓝牙是否连接
  Future<bool> get isConnect async {
    bool isConnect = await _channel.invokeMethod('isConnect') as bool;
    return isConnect;
  }

  ///蓝牙是否正在执行命令
  Future<bool> get isCommanding async {
    bool isConnect = await _channel.invokeMethod('isCommanding') as bool;
    return isConnect;
  }

  ///验证码授权
  void auth(String code) {
    _channel.invokeMethod('auth', {"authCode": code});
  }

  ///发送指令
  void sendCommend(String command) {
    _channel.invokeMethod('broadcastData', {"command": command});
  }

  ///发送原始指令
  void sendOCommand(String command) {
    _channel.invokeMethod('broadcastOData', {"command": command});
  }

  ///设置写数据特征值
  void setWriteCharator(String uuid) {
    _channel.invokeMethod('setWriteCharactor', {"uuid": uuid});
  }

  /// 设置通知特征值
  void setNotifyCharactor(String uuid, String isNotify) {
    _channel.invokeMethod(
        'setNotifyCharactor', {"uuid": uuid, "isNotify": isNotify});
  }

  StreamSubscription<dynamic> eventStreamSubscription;

  initEvent() {
    eventStreamSubscription = _eventChannerFor()
        .receiveBroadcastStream()
        .listen(eventListener, onError: errorListener);
  }

  //消息通知通道
  EventChannel _eventChannerFor() {
    return EventChannel("flutter_ble_event");
  }

  void eventListener(event) {
    // print("蓝牙插件收到数据："+event.toString());
    final Map<dynamic, dynamic> map = event;
//    Map<dynamic,dynamic> map = Map();
//    if(Platform.isIOS){
//      map = json.decode(event);
//    }else{
//      map = event;
//    }
    BaseEvent baseEvent = BaseEvent.fromJson(map);
    // print("蓝牙插件收到数据2："+baseEvent.data.toString());
    // print("蓝牙插件收到数据22："+baseEvent.code.toString());
    switch (baseEvent.code) {
      case EventChannelConstant.FOUND_DEVICES: //发现蓝牙设备
        List responseJson = json.decode(baseEvent.data);
//        List responseJson = List();
//        if(Platform.isIOS){
//          responseJson = baseEvent.data;
//        }else{
//          responseJson = json.decode(baseEvent.data);
//        }
//         print("蓝牙插件收到数据3："+responseJson.toString());
        List<DeviceBle> devices =
            responseJson.map((e) => DeviceBle.fromJson(jsonDecode(e))).toList();
        if (this.deviceListener != null) {
          deviceListener.onFoundDevice(devices);
        } else {
          print("deviceListener:" + deviceListener.toString());
        }
        break;
      case EventChannelConstant.START_SACN: //开始蓝牙扫描
        if (this.deviceListener != null) {
          deviceListener.onScanStart();
        }
        break;
      case EventChannelConstant.STOP_SACN: //停止蓝牙扫描
        if (this.deviceListener != null) {
          deviceListener.onScanStop();
        }
        break;
      case EventChannelConstant.STATE_CONNECTED: //蓝牙状态改变，蓝牙连接上了
        if (this.deviceListener != null) {
          deviceListener
              .onConnectionStateChange(EventChannelConstant.STATE_CONNECTED);
        }
        break;
      case EventChannelConstant.STATE_RECONNECTED:
        if (this.deviceListener != null) {
          deviceListener.onReConnected();
        }
        break;
      case EventChannelConstant.STATE_DISCONNECTED: //蓝牙状态改变，蓝牙连接断开
        if (this.deviceListener != null) {
          deviceListener
              .onConnectionStateChange(EventChannelConstant.STATE_DISCONNECTED);
        }
        break;
      case EventChannelConstant.GATT_SERVICES_DISCOVERED: //发现可用的服务
        if (this.deviceListener != null) {
          deviceListener.onServicesDiscovered();
        }
        break;
      case EventChannelConstant.DOES_NOT_SUPPORT_UART: //服务不支持
        if (this.deviceListener != null) {
          deviceListener.onServicesNotSupport();
        }
        break;
      case EventChannelConstant.DATA_AVAILABLE: //收到蓝牙发送过来的数据
//        print(baseEvent.data.runtimeType);
        var data = baseEvent.data as List;
        print(data);
        List<int> list = data.map((e) => e as int).toList();
        // print(String.fromCharCodes(list));//ascall转换为String
        if (this.deviceListener != null) {
          deviceListener.onReceivedDataListener(data);
        }
        break;
      case EventChannelConstant.BLUETOOTHOFF: //蓝牙关闭通知
        if (this.deviceListener != null) {
          deviceListener.onBluetoothOff();
        }
        break;
      case EventChannelConstant.BLUETOOTHON: //蓝牙开启通知
        if (this.deviceListener != null) {
          deviceListener.onBluetoothOn();
        }
        break;
      case EventChannelConstant.SERVICE_CHARACTERISTICS: //蓝牙开启通知
        Map responseJson = json.decode(baseEvent.data);
        responseJson.forEach((key, value) {
          print("key:" + key + "-> value:" + value.toString());
        });
        if (this.deviceListener != null) {
          deviceListener.onServiceCharac(responseJson);
        }
        break;
    }
  }

  //消息通道错误回调方法
  errorListener(Object obj) {
    final PlatformException e = obj;
    throw e;
  }
}

abstract class DeviceListener {
  void onScanStart() {}

  void onFoundDevice(List<DeviceBle> devices) {}

  void onScanStop() {}

  void onConnectionStateChange(int status) {
    print("flutter插件监听到蓝牙状态发送改变：" + (status == 4 ? "蓝牙连接上了" : "蓝牙断开了"));
  }

  void onReceivedDataListener(List<dynamic> byteData) {
    print("插件接收到数据：" + byteData.toString());
  }

  void onServicesDiscovered() {}

  void onServicesNotSupport() {}

  void onBluetoothOff() {}

  void onBluetoothOn() {}

  void onReConnected() {}

  void onServiceCharac(Map data) {}
}
