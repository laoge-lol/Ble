import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ble/DeviceBle.dart';
import 'package:ble/EventChannelConstant.dart';
import 'package:ble/ble.dart';
import 'package:ble_example/SpUtil.dart';
import 'package:ble_example/generated/l10n.dart';
import 'package:toast/toast.dart';

class BlePage extends StatefulWidget {
  DeviceBle deviceBle;

  BlePage(this.deviceBle);

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return BlePageState();
  }
}

class BlePageState extends State<BlePage> implements DeviceListener {
  // 所有的服务和特征值集合，键值对，键为服务（string），值为服务（键）下的特征值集合（list）
  Map serviceAndCharac = {};

  // 蓝牙是否连接
  bool isBLEConnected = false;

  List<String> content = ["message history ..."];

  // 发送的指令
  String sendCommand = "";

  TextEditingController textEditingController;

  ScrollController listviewController;

  // 有写属性的特征值集合
  List writeCharactS = [];

  // 有通知属性的特征值集合
  List notifyCharacts = [];

  // 使用的写特征值的下标
  int writeIndex = 0;

  // 使用的通知的特征值的下标集合，放到字符串中
  String notifyIndex = "0";

  // 总共有多少个特征值，用来计算listview的高度
  int charactsSize = 0;

  // 输入框焦点
  final FocusNode focusNode = FocusNode();

  List historys;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    textEditingController = TextEditingController(text: "");
    listviewController = ScrollController();
    // SpUtil.putString(SpUtil.HISTORY_COMMAND, "");//清空数据库
    var json = SpUtil.getString(SpUtil.HISTORY_COMMAND,defValue: "[]");
    print(json);
    if(json.isEmpty){
      historys = [];
    }else{
      historys = jsonDecode(json);
    }
    Ble.getInstance().setDeviceListener(this);
    Timer(Duration(milliseconds: 200), () {
      // 第一次连接蓝牙
      Ble.getInstance().disconnect();
      Ble.getInstance().connect(widget.deviceBle.address);
      Toast.show(S.of(context).ble_connecting, context, gravity: Toast.CENTER);
    });
    //监听输入框焦点得失
    focusNode.addListener(() {
      var hasFocus = focusNode.hasFocus;
      print("hasFoces:" + hasFocus.toString());
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    // Ble.getInstance().disconnect();
    super.dispose();
  }

  List<Widget> Box() => List.generate(13, (index) {
    return Container(
      alignment: Alignment.center,
      height: 30,
      margin: EdgeInsets.only(left: 5, right: 5),
      padding: EdgeInsets.only(left: 10, right: 10, bottom: 5, top: 5),
      decoration: BoxDecoration(
          color: Color(0xffdcdcdc),
          borderRadius: BorderRadius.all(Radius.circular(20))),
      child: Text(
        "ddddddddd",
        style: TextStyle(color: Colors.black),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceBle.name),
      ),
      body: GestureDetector(
        onTap: () {
          // 点击空白处失去焦点，隐藏键盘
          focusNode.unfocus();
        },
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Column(
            children: [
              // 输入框、发送按钮行
              Row(
                children: [
                  Expanded(
                      child: Container(
                        height: 48,
                        margin: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey, width: 1),
                            borderRadius: BorderRadius.all(Radius.circular(5))),
                        child: Row(
                          children: [
                            Expanded(
                                child: Container(
                                    height: 48,
                                    width: MediaQuery.of(context).size.width /
                                        3 *
                                        2 /
                                        2,
                                    child: TextField(
                                      onChanged: (value) {
                                        sendCommand = value;
                                        setState(() {});
                                      },
                                      focusNode: focusNode,
                                      controller: textEditingController,
                                      decoration: InputDecoration(
                                          counterText: "",
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 0, horizontal: 10),
                                          border: InputBorder.none,
                                          hintText: "order..."),
                                    ))),
                            Ink(
                              child: InkWell(
                                onTap: () {
                                  textEditingController.text = "";
                                  sendCommand = "";
                                  // 请求焦点
                                  focusNode.requestFocus();
                                  setState(() {});
                                },
                                child: Offstage(
                                  offstage: sendCommand.isEmpty,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    margin: EdgeInsets.all(14),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                        color: Color(0xffdcdcdc),
                                        borderRadius:
                                        BorderRadius.all(Radius.circular(20))),
                                    child: Icon(
                                      Icons.clear,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      )),
                  Ink(
                    child: InkWell(
                      onTap: () {
                        if (!isBLEConnected) {
                          Toast.show(
                              S.of(context).ble_disconnet_connecting, context,
                              gravity: Toast.CENTER);
                          Ble.getInstance()
                              .connect(widget.deviceBle.address);
                          Timer(Duration(milliseconds: 10000), () {
                            Ble.getInstance().disconnect();
                            Toast.show(
                                S
                                    .of(context)
                                    .connect_time_out_check_whether_ble_is_turned_on,
                                context,
                                gravity: Toast.CENTER);
                          });
                          return;
                        }
                        // 发送的指令不能为空
                        if (sendCommand.isEmpty) {
                          Toast.show(S.of(context).please_input_order, context,
                              gravity: Toast.CENTER);
                          return;
                        }
                        // 集合长度大于10就删除第一个数据，集合最大长度为10
                        print(historys);
                        if(historys.length>=10){
                          historys.removeAt(9);
                        }
                        print(historys);
                        // 当集合中已经有相同的指令就不再添加到集合中
                        if(!historys.contains(sendCommand)){
                          // 添加到集合
                          historys.insert(0, sendCommand);
                          // 同步到数据库
                          SpUtil.putString(SpUtil.HISTORY_COMMAND, jsonEncode(historys));
                        }
                        setState(() {

                        });
                        // 输入框失去焦点
                        // focusNode.unfocus();
                        // 通过蓝牙发送指令
                        Ble.getInstance().sendCommend(sendCommand);
                      },
                      child: Container(
                        height: 48,
                        margin: EdgeInsets.all(5),
                        width: 100,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(3)),
                            color: isBLEConnected ? Colors.blue : Colors.grey),
                        alignment: Alignment.center,
                        child: Text(
                          S.of(context).send,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  )
                ],
              ),
              // 历史记录
              Container(
                margin: EdgeInsets.only(top: 5,bottom: 5),
                alignment: Alignment.centerLeft,
                child: Wrap(// 流布局自动换行
                  spacing: 2,
                  runSpacing: 5,
                  children: List.generate(historys.length+1, (index) {
                    return GestureDetector(
                      onTap: (){
                        if(index == historys.length){
                          // 清空历史记录
                          historys.clear();
                          // 同步到数据库
                          SpUtil.putString(SpUtil.HISTORY_COMMAND, jsonEncode(historys));
                          setState(() {

                          });
                          return;
                        }
                        if (!isBLEConnected) {
                          Toast.show(
                              S.of(context).ble_disconnet_connecting, context,
                              gravity: Toast.CENTER);
                          Ble.getInstance()
                              .connect(widget.deviceBle.address);
                          Timer(Duration(milliseconds: 10000), () {
                            Ble.getInstance().disconnect();
                            Toast.show(
                                S
                                    .of(context)
                                    .connect_time_out_check_whether_ble_is_turned_on,
                                context,
                                gravity: Toast.CENTER);
                          });
                          return;
                        }
                        // 点击了历史记录的指令
                        sendCommand = historys[index];
                        // 输入框获的焦点
                        focusNode.requestFocus();
                        // 设置输入框的内容
                        textEditingController.text = sendCommand;
                        // 把光标放到输入框内容的最后面
                        textEditingController.selection = TextSelection.fromPosition(TextPosition(
                            affinity: TextAffinity.downstream,
                            offset: sendCommand.length
                        ));
                        setState(() {

                        });
                      },
                      child: index==historys.length?Container(
                        alignment: Alignment.center,
                        width: 120,
                        height: 30,
                        child: Text("${historys.length}/10 CLEAR",style: TextStyle(color: Colors.grey),),
                      ):Container(
                        // alignment: Alignment.center,
                        // width: 100,
                        height: 30,
                        margin: EdgeInsets.only(left: 5, right: 5),
                        padding: EdgeInsets.only(left: 10, right: 10, bottom: 5, top: 5),
                        decoration: BoxDecoration(
                            color: Color(0xffdcdcdc),
                            borderRadius: BorderRadius.all(Radius.circular(20))),
                        child: Text(
                          historys[index],
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // 打印收到的数据的输出框
              Container(
                height: 200,
                padding: EdgeInsets.all(3),
                width: MediaQuery.of(context).size.width,
                margin: EdgeInsets.all(3),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(5)),
                    border: Border.all(color: Colors.grey, width: 1)),
                child: ListView.builder(
                    itemCount: content.length,
                    controller: listviewController,
                    itemBuilder: (context, i) {
                      return Container(
                        // height: 30,
                        margin: EdgeInsets.only(bottom: 10),
                        width: MediaQuery.of(context).size.width,
                        child: content[i].contains("(")
                            ? RichText(
                          text: TextSpan(
                              text: content[i].split("(")[0] + "\t\t\t",
                              style: TextStyle(color: Colors.black),
                              children: [
                                TextSpan(
                                    text: content[i].split("(")[1],
                                    style: TextStyle(color: Colors.grey))
                              ]),
                        )
                            : Text(content[i]),
                      );
                    }),
              ),
              Expanded(
                  child: CustomScrollView(
                    shrinkWrap: true,
                    slivers: <Widget>[
                      SliverPadding(
                        padding: EdgeInsets.all(0),
                        sliver: SliverList(
                            delegate: new SliverChildListDelegate(<Widget>[
                              Column(
                                children: [
                                  Container(
                                    alignment: Alignment.centerLeft,
                                    color: Colors.grey,
                                    height: 30,
                                    child: Text(
                                        S.of(context).set_write_characteristics +
                                            " :" +
                                            writeCharactS.length.toString()),
                                  ),
                                  Container(
                                      height: writeCharactS.length * 40.0,
                                      child: ListView.builder(
                                          physics: NeverScrollableScrollPhysics(),
                                          itemCount: writeCharactS.length,
                                          itemBuilder: (context, index) {
                                            return GestureDetector(
                                              onTap: () {
                                                if (!isBLEConnected) {
                                                  return;
                                                }
                                                // 设置用这个特征值写数据给设备
                                                writeIndex = index;
                                                Ble.getInstance()
                                                    .setWriteCharator(
                                                    writeCharactS[index]['uuid']);
                                                setState(() {});
                                              },
                                              child: Container(
                                                color: writeIndex == index
                                                    ? Colors.pinkAccent
                                                    : Colors.white,
                                                alignment: Alignment.centerLeft,
                                                height: 40,
                                                padding: EdgeInsets.only(left: 20),
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      height: 20,
                                                      alignment: Alignment.centerLeft,
                                                      child: Text("c${index + 1}: " +
                                                          writeCharactS[index]['uuid']),
                                                    ),
                                                    Container(
                                                      height: 15,
                                                      alignment: Alignment.centerLeft,
                                                      child: Text(
                                                        "properties:" +
                                                            writeCharactS[index]
                                                            ['type'],
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.grey),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            );
                                          })),
                                  Container(
                                    alignment: Alignment.centerLeft,
                                    color: Colors.grey,
                                    height: 30,
                                    child: Text(
                                        S.of(context).set_notify_characteristics +
                                            " :" +
                                            notifyCharacts.length.toString()),
                                  ),
                                  Container(
                                      height: notifyCharacts.length * 40.0,
                                      child: ListView.builder(
                                          physics: NeverScrollableScrollPhysics(),
                                          itemCount: notifyCharacts.length,
                                          itemBuilder: (context, index) {
                                            return GestureDetector(
                                              onTap: () {
                                                // 接收来自这个特征值的数据（通知特征值可以设置多个）
                                                if (!isBLEConnected) {
                                                  return;
                                                }
                                                if (notifyIndex
                                                    .contains(index.toString())) {
                                                  notifyIndex = notifyIndex.replaceAll(
                                                      index.toString(), "");
                                                  Ble.getInstance()
                                                      .setNotifyCharactor(
                                                      notifyCharacts[index]['uuid'],
                                                      "false");
                                                } else {
                                                  notifyIndex += index.toString();
                                                  Ble.getInstance()
                                                      .setNotifyCharactor(
                                                      notifyCharacts[index]['uuid'],
                                                      "true");
                                                }
                                                print("notifyIndex:" + notifyIndex);
                                                setState(() {});
                                              },
                                              child: Container(
                                                color: notifyIndex
                                                    .contains(index.toString())
                                                    ? Colors.greenAccent
                                                    : Colors.white,
                                                alignment: Alignment.centerLeft,
                                                height: 40,
                                                padding: EdgeInsets.only(left: 20),
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      height: 20,
                                                      alignment: Alignment.centerLeft,
                                                      child: Text("c${index + 1}: " +
                                                          notifyCharacts[index]
                                                          ['uuid']),
                                                    ),
                                                    Container(
                                                      height: 15,
                                                      alignment: Alignment.centerLeft,
                                                      child: Text(
                                                        "properties:" +
                                                            notifyCharacts[index]
                                                            ['type'],
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.grey),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            );
                                          })),
                                  Container(
                                    alignment: Alignment.centerLeft,
                                    color: Colors.grey,
                                    height: 30,
                                    child: Text(
                                        S.of(context).all_service_and_characteristics +
                                            " s:" +
                                            serviceAndCharac.keys.length.toString() +
                                            " c:" +
                                            charactsSize.toString()),
                                  ),
                                  Container(
                                      height: charactsSize * 40.0 +
                                          (serviceAndCharac.keys.length * 30),
                                      child: ListView.builder(
                                          physics: NeverScrollableScrollPhysics(),
                                          itemCount: serviceAndCharac.keys.length,
                                          itemBuilder: (context, i) {
                                            return Column(
                                              mainAxisAlignment:
                                              MainAxisAlignment.start,
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  height: 30,
                                                  alignment: Alignment.centerLeft,
                                                  color: Color(0xf979797),
                                                  padding: EdgeInsets.only(left: 10),
                                                  width:
                                                  MediaQuery.of(context).size.width,
                                                  child: Text("s${i + 1}: " +
                                                      serviceAndCharac.keys
                                                          .toList()[i]),
                                                ),
                                                Container(
                                                  height: ((serviceAndCharac[
                                                  serviceAndCharac.keys
                                                      .toList()[i]] as List)
                                                      .length *
                                                      40.0),
                                                  width:
                                                  MediaQuery.of(context).size.width,
                                                  child: ListView.builder(
                                                      physics:
                                                      NeverScrollableScrollPhysics(),
                                                      itemCount: (serviceAndCharac[
                                                      serviceAndCharac.keys
                                                          .toList()[i]] as List)
                                                          .length,
                                                      itemBuilder: (context, index) {
                                                        return Container(
                                                          alignment:
                                                          Alignment.centerLeft,
                                                          height: 40,
                                                          padding:
                                                          EdgeInsets.only(left: 20),
                                                          child: Column(
                                                            children: [
                                                              Container(
                                                                height: 20,
                                                                alignment: Alignment
                                                                    .centerLeft,
                                                                child: Text("c${index + 1}: " +
                                                                    serviceAndCharac[
                                                                    serviceAndCharac
                                                                        .keys
                                                                        .toList()[i]]
                                                                    [
                                                                    index]['uuid']),
                                                              ),
                                                              Container(
                                                                height: 15,
                                                                alignment: Alignment
                                                                    .centerLeft,
                                                                child: Text(
                                                                  "properties:" +
                                                                      serviceAndCharac[
                                                                      serviceAndCharac
                                                                          .keys
                                                                          .toList()[i]]
                                                                      [
                                                                      index]['type'],
                                                                  style: TextStyle(
                                                                      fontSize: 10,
                                                                      color:
                                                                      Colors.grey),
                                                                ),
                                                              )
                                                            ],
                                                          ),
                                                        );
                                                      }),
                                                )
                                              ],
                                            );
                                          }))
                                ],
                              )
                            ])),
                      )
                    ],
                  ))
            ],
          ),
        ),
      ),
    );
  }

  @override
  void onBluetoothOff() {
    // TODO: implement onBluetoothOff
  }

  @override
  void onBluetoothOn() {
    // TODO: implement onBluetoothOn
  }

  @override
  void onConnectionStateChange(int status) {
    // TODO: implement onConnectionStateChange
    if (status == EventChannelConstant.STATE_CONNECTED) {
      // Toast.show("蓝牙连接成功", context, gravity: Toast.CENTER);
      isBLEConnected = true;
    } else if (status == EventChannelConstant.STATE_DISCONNECTED) {
      // Toast.show("蓝牙连接断开", context, gravity: Toast.CENTER);
      isBLEConnected = false;
    }
    setState(() {});
  }

  @override
  void onFoundDevice(List<DeviceBle> devices) {
    // TODO: implement onFoundDevice
    print("BlePage->onFoundDevice");
    // Toast.show("搜索到蓝牙设备", context, gravity: Toast.CENTER);
  }

  @override
  void onReConnected() {
    // TODO: implement onReConnected
  }

  @override
  void onReceivedDataListener(List<dynamic> byteData) {
    // TODO: implement onReceivedDataListener
    print("BlePage*****onReceivedDataListener");
    print(byteData);
    List<int> list = byteData.map((e) => e as int).toList();
    String data = "";
    try{
      // ASCALL码转换为字符串
      data = String.fromCharCodes(list);
    }catch(e){
      data = "--";
    }
    print("data******"+data.toString());
    print("add**********"+byteData.toString().length.toString());
    String byteStr = byteData.toList().toString();
    print("byteStr*****"+jsonEncode(byteData));
    String tempStr = (data + "( ") + json.encode(byteStr);
    print("all********"+tempStr.length.toString());
    print("all********"+tempStr);
    // 这个地方不用json.encode编码显示不出来
    content.add(data + "(" + json.encode(byteData.toString()));
    setState(() {});
    // 17ms(大于一帧的最小时间)后滚动listview列表，滚动到最下面
    Timer(Duration(milliseconds: 17), () {
      listviewController.jumpTo(listviewController.position.maxScrollExtent);
    });
  }

  @override
  void onScanStart() {
    // TODO: implement onScanStart
  }

  @override
  void onScanStop() {
    // TODO: implement onScanStop
  }

  @override
  void onServicesDiscovered() {
    // TODO: implement onServicesDiscovered
  }

  @override
  void onServicesNotSupport() {
    // TODO: implement onServicesNotSupport
  }

  @override
  void onServiceCharac(data) {
    // TODO: implement onServiceCharac
    print("blepage******************");
    print(data);
    serviceAndCharac = data;
    charactsSize = 0;
    writeCharactS.clear();
    notifyCharacts.clear();
    for (String key in serviceAndCharac.keys.toList()) {
      List characts = serviceAndCharac[key];
      for (int i = 0; i < characts.length; i++) {
        charactsSize++;
        if (characts[i]["type"].toString().contains("Write")) {
          writeCharactS.add(characts[i]);
        }
        if (characts[i].toString().contains('Notify')) {
          notifyCharacts.add(characts[i]);
        }
      }
    }
    setState(() {});
  }
}
