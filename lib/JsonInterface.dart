import 'package:flutter/material.dart';
/**
 * Create by laoge
 * on 2020/7/16 0016
 */

abstract class JsonInterface<T,E> {
  T fromjson(Map<E,dynamic> map);
  Map<E,dynamic> tojson();
}
