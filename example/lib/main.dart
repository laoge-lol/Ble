import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:ble/DeviceBle.dart';
import 'package:ble/ble.dart';
import 'package:ble_example/blePage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:toast/toast.dart';

import 'SpUtil.dart';
import 'generated/l10n.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 强制竖屏
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  // runApp(MyApp());
  SpUtil.getInstance().then((value) => runApp(MyApp()));
}

class MyApp extends StatefulWidget {
  static final RouteObserver<PageRoute> routeObserver =
  RouteObserver<PageRoute>();

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  Locale _locale;

  @override
  void initState() {
    super.initState();
    requestPermission();
    // 初始化
    Ble.getInstance();
    initPlatformState();
    // 设置显示的默认语言
    _locale = Locale(SpUtil.getString(SpUtil.LANGUAGE, defValue: 'zh'), '');
  }

  requestPermission() async {
    PermissionStatus permissionStatus = await Permission.location.status;
    if (permissionStatus.isUndetermined) {
      List<Permission> permissions = [];
      if (Platform.isIOS) {
        permissions = [Permission.storage, Permission.phone];
      } else {
        permissions = [Permission.location,Permission.storage, Permission.phone];
      }
      Map<Permission, PermissionStatus> statuses = await permissions.request();
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await Ble.getInstance().platformVersion;
      print(platformVersion);
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      navigatorObservers: [MyApp.routeObserver],
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate
      ],
      supportedLocales: S.delegate.supportedLocales,
      theme: ThemeData(
        primaryColor: Colors.blue,
        primarySwatch: Colors.blue,
      ),
      home: Builder(builder: (BuildContext context) {
        return Localizations.override(
            context: context,
            locale: _locale,
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              appBar: AppBar(
                title: Text("Flutter Ble"),
              ),
              body: Index(),
              floatingActionButton: FloatingActionButton(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: "Lang\n", style: TextStyle(fontSize: 16)),
                    TextSpan(
                        text: "(" +
                            (_locale.languageCode == 'zh' ? 'ZH' : 'EN') +
                            ")",
                        style: TextStyle(fontSize: 7))
                  ]),
                  textAlign: TextAlign.center,
                ),
                onPressed: () {
                  setState(() {
                    print(_locale.languageCode);
                    SpUtil.putString(SpUtil.LANGUAGE,
                        _locale.languageCode == 'zh' ? 'en' : 'zh');
                    _locale =
                        Locale(_locale.languageCode == 'zh' ? 'en' : 'zh', '');
                    Toast.show(S.of(context).language, context);
                  });
                },
              ),
            ));
      }),
    );
  }
}

class Index extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return IndexState();
  }
}

class IndexState extends State<Index>
    with RouteAware
    implements DeviceListener {
  List<DeviceBle> devices = [];

  static bool BLEConnected = false;
  bool Scanning = false;

  @override
  void initState()  {
    // TODO: implement initState
    Ble.getInstance().setDeviceListener(this);
    super.initState();
    requestPermissionAndStartScan();
  }

  requestPermissionAndStartScan() async {
    PermissionStatus permissionStatus = await Permission.location.status;
    if (!permissionStatus.isUndetermined) {
      Ble.getInstance().startScanBluetooth;
    }
  }

  @override
  void didPushNext() {
    // TODO: implement didPushNext
    super.didPushNext();
    print("didPushNext");
    Ble.getInstance().stopScanBluetooth;
  }

  @override
  void didChangeDependencies() {
    // TODO: implement didChangeDependencies
    MyApp.routeObserver.subscribe(this, ModalRoute.of(context));
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    MyApp.routeObserver.unsubscribe(this);
  }

  @override
  void didPopNext() {
    print("didPopNext");
    devices.clear();
    setState(() {});
    Timer(Duration(milliseconds: 200), () {
      Ble().setDeviceListener(this);
      Ble.getInstance().disconnect();
      Ble.getInstance().startScanBluetooth;
    });
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    print(kMinInteractiveDimension);
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height -
          MediaQuery.of(context).padding.top,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
              bottom: 70,
              top: MediaQuery.of(context).padding.top,
              child: Column(
                children: [
                  Container(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height -
                          80 -
                          kToolbarHeight -
                          kMinInteractiveDimension,
                      child: ListView.builder(
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () async {
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (_) {
                                      return new BlePage(devices[index]);
                                    }));
                              },
                              child: Container(
                                padding: EdgeInsets.all(5),
                                height: 40,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 120,
                                      child: Text(
                                        devices[index].name,
                                        maxLines: 1,
                                      ),
                                    ),
                                    Expanded(
                                        child: Text(
                                          devices[index].address,
                                          maxLines: 1,
                                        )),
                                    Container(
                                      alignment: Alignment.centerRight,
                                      width: 50,
                                      child:
                                      Text(devices[index].rssi.toString()),
                                    )
                                  ],
                                ),
                              ),
                            );
                          })),
                ],
              )),
          Positioned(
              bottom: 30,
              child: GestureDetector(
                onTap: () async {
                  setState(() {
                    devices.clear();
                  });
                  PermissionStatus permissionStatus = await Permission.location.status;
                  if (!permissionStatus.isUndetermined) {
                    Ble.getInstance().startScanBluetooth;
                  }
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(50)),
                      color: Colors.blue,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey,
                            offset: Offset(2, 1),
                            blurRadius: 3,
                            spreadRadius: 2)
                      ]),
                  child: Icon(
                    Icons.autorenew,
                    color: Colors.white,
                  ),
                ),
              )),
          Positioned(
              bottom: 30,
              left: 20,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    devices.clear();
                  });
                  Ble.getInstance().startScanBluetooth;
                },
                child: Container(
                  alignment: Alignment.center,
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(50)),
                      color: Colors.blue,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey,
                            offset: Offset(2, 1),
                            blurRadius: 3,
                            spreadRadius: 2)
                      ]),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: "size\n",
                          style: TextStyle(color: Colors.white, fontSize: 10)),
                      TextSpan(
                        text: devices.length.toString(),
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      )
                    ]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ))
        ],
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
  }

  @override
  void onReConnected() {
    // TODO: implement onReConnected
  }

  @override
  void onReceivedDataListener(List<dynamic> byteData) {
    // TODO: implement onReceivedDataListener
  }

  @override
  void onScanStart() {
    // TODO: implement onScanStart
    print("onScanStart");
    Toast.show(
        S.of(context).start_searching_for_attached_bluetooth_devices, context,
        gravity: Toast.CENTER);
    Scanning = true;
    setState(() {});
  }

  @override
  void onScanStop() {
    // TODO: implement onScanStop
    print("onScanStop");
    Toast.show(
        S.of(context).stop_searching_for_attached_bluetooth_devices, context,
        gravity: Toast.CENTER);
    Scanning = false;
    setState(() {});
  }

  @override
  void onFoundDevice(List<DeviceBle> devices) {
    print("main->onFoundDevice");
    this.devices = devices;
    setState(() {});
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
  }
}
