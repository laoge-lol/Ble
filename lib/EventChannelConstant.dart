import 'package:flutter/material.dart';
/**
 * Create by laoge
 * on 2020/7/16 0016
 */

class EventChannelConstant {
  static const FOUND_DEVICES = 1;//搜索到蓝牙设备
  static const START_SACN = 2;//开始扫描
  static const STOP_SACN = 3;//开始扫描
  static const STATE_CONNECTED=4;//蓝牙状态改变，连接上了蓝牙
  static const STATE_DISCONNECTED=5;//蓝牙状态改变，蓝牙连接断开
  static const GATT_SERVICES_DISCOVERED=6;//发现可用的蓝牙服务
  static const DOES_NOT_SUPPORT_UART=7;//服务或特征值不可用
  static const DATA_AVAILABLE=8;//收到蓝牙设备发送的数据
  static const BLUETOOTHOFF=9;//蓝牙关闭通知
  static const BLUETOOTHON=10;//蓝牙开启通知
  static const STATE_RECONNECTED=11;//蓝牙状态改变，重连上了之前的蓝牙，不需要发现服务
  static const SERVICE_CHARACTERISTICS=12;//发现服务和特征值
}
