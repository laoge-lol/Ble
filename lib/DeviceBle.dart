import 'package:flutter/material.dart';
import 'package:ble/Base.dart';
import 'package:ble/JsonInterface.dart';
/**
 * Create by laoge
 * on 2020/7/16 0016
 */

class DeviceBle extends Base<DeviceBle>{
  String name;
  int rssi;
  String address;

  DeviceBle({this.name, this.rssi, this.address});
  DeviceBle.fromJson(Map<dynamic, dynamic> json) {
    name = json['name'];
    rssi = json['rssi'];
    address = json['address'];
  }
  Map<String, dynamic> toJson() {
    final Map<dynamic, dynamic> data = new Map<dynamic, dynamic>();
    data['name'] = this.name;
    data['rssi'] = this.rssi;
    data['address'] = this.address;
    return data;
  }

  @override
  DeviceBle fromJson(String str) {
    print(str);
  }

  @override
  String toString() {
    return '{"name": "$name", "rssi": $rssi, "address": "$address"}';
  }


}

