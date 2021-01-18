import 'package:flutter/material.dart';
import 'package:ble/DeviceBle.dart';

import 'Base.dart';
/**
 * Create by laoge
 * on 2020/7/16 0016
 */

class BaseEvent  {
  int code;
  dynamic data;

  BaseEvent(this.code, this.data);

  BaseEvent.fromJson(Map<dynamic, dynamic> json) {
    code = json['code'];
    data = json['data'];
  }

  Map<dynamic, dynamic> toJson() {
    final Map<dynamic, dynamic> data = new Map<dynamic, dynamic>();
    data['code'] = this.code;
    data['data'] = this.data;
    return data;
  }

}
