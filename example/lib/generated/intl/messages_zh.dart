// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'zh';

  final messages = _notInlinedMessages(_notInlinedMessages);
  static _notInlinedMessages(_) => <String, Function> {
    "all_service_and_characteristics" : MessageLookupByLibrary.simpleMessage("所有的服务及其子特征值"),
    "ble_connecting" : MessageLookupByLibrary.simpleMessage("正在连接蓝牙..."),
    "ble_disconnet_connecting" : MessageLookupByLibrary.simpleMessage("蓝牙连接断开，正在重新连接蓝牙..."),
    "connect_time_out_check_whether_ble_is_turned_on" : MessageLookupByLibrary.simpleMessage("蓝牙连接超时，请检查蓝牙是否打开"),
    "language" : MessageLookupByLibrary.simpleMessage("English is currently used"),
    "please_input_order" : MessageLookupByLibrary.simpleMessage("请输入命令"),
    "send" : MessageLookupByLibrary.simpleMessage("发送"),
    "set_notify_characteristics" : MessageLookupByLibrary.simpleMessage("设置通知特征值（多选）"),
    "set_write_characteristics" : MessageLookupByLibrary.simpleMessage("设置写特征值(单选)"),
    "start_searching_for_attached_bluetooth_devices" : MessageLookupByLibrary.simpleMessage("开始搜索附近的蓝牙设备"),
    "stop_searching_for_attached_bluetooth_devices" : MessageLookupByLibrary.simpleMessage("开始搜索附近的蓝牙设备")
  };
}
