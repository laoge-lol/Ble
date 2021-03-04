package com.lg.ble;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.content.pm.PackageManager;
import android.location.LocationManager;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.Log;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import com.alibaba.fastjson.JSON;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * BlePlugin
 */
public class BlePlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
  public static String device_address;             //记录最新绑定的地址，主动解绑时清空
  public static boolean isConnected;               //设备已连接
  public static boolean mConnected;               //连接状态,true时表示正在连接中
  public static int mConnectionState = 0;         //0-断开，1-正在连接，2-已连接
  public static int state = 0;                     //连接状态码
  public static boolean is_auth = false;             //设备授权
  public static boolean is_support = true;           //有可以的读写服务
  public static BleService mService = null;
  // flutter方法调用通道实例对象
  private MethodChannel channel;
  // 上下文
  private Context mContext;
  // 蓝牙适配器
  BluetoothAdapter bluetoothAdapter;
  private Handler mHandler = new Handler() {
    @Override
    public void handleMessage(Message msg) {

    }
  };
  // 扫描时间
  private long SCANTIME = 15000;
  private String TAG = BlePlugin.class.getSimpleName();
  // 重连次数
  private int count = 0;
  private static final int NO_SUPPORT = 3;      //无可用的读写蓝牙服务

  // flutter消息通知通道
  private EventChannel.EventSink eventSink = null;
  private EventChannel.StreamHandler streamHandler = new EventChannel.StreamHandler() {
    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
      Log.e(TAG, "onListen: " + events.toString());
      eventSink = events;
    }

    @Override
    public void onCancel(Object arguments) {
      eventSink = null;
    }
  };


  @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR2)
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    System.out.println("onAttachedToEngine**********");
    channel = new MethodChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "flutter_ble");
    channel.setMethodCallHandler(this);
    EventChannel eventChannel = new EventChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "flutter_ble_event");
    eventChannel.setStreamHandler(streamHandler);
    mContext = flutterPluginBinding.getApplicationContext();
    initBluetoothAdapter();
    initService();
  }


  // 初始化蓝牙适配器
  private void initBluetoothAdapter() {
    BluetoothManager bluetoothManager = (BluetoothManager) mContext.getSystemService(Context.BLUETOOTH_SERVICE);
    if (bluetoothManager != null) {
      bluetoothAdapter = bluetoothManager.getAdapter();
    }
  }

  // 初始化蓝牙服务
  private void initService() {
    LogUtils.e("initService************");
    Intent bindIntent = new Intent(mContext, BleService.class);
    //启动Service:1.需要启动的服务   2.接收服务开启或停止的消息   3.自动启动service
    mContext.bindService(bindIntent, mServiceConnection, Context.BIND_AUTO_CREATE);
    //注册蓝牙状态改变的广播
    LocalBroadcastManager.getInstance(mContext).registerReceiver(mBleStatusChangeReceiver, makeGattUpdateIntentFilter());
  }

  /**
   * 设置需要监听的蓝牙过滤器
   *
   * @return
   */
  private static IntentFilter makeGattUpdateIntentFilter() {
    final IntentFilter intentFilter = new IntentFilter();
    intentFilter.addAction(BleService.ACTION_GATT_CONNECTED);
    intentFilter.addAction(BleService.ACTION_GATT_RECONNECTED);
    intentFilter.addAction(BleService.ACTION_GATT_DISCONNECTED);
    intentFilter.addAction(BleService.DEVICE_DOES_NOT_SUPPORT_UART);
    intentFilter.addAction(BleService.ACTION_GATT_SERVICES_DISCOVERED);
    intentFilter.addAction(BleConstant.BIND_DEVICE);
    intentFilter.addAction(BleConstant.USER_UNBIND_DEVICE);
    intentFilter.addAction(BleService.ACTION_DATA_AVAILABLE);
    intentFilter.addAction(BleConstant.ACTION_SEND_DATA_TO_BLE);
    intentFilter.addAction(BluetoothAdapter.ACTION_STATE_CHANGED);
    intentFilter.addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED);
    intentFilter.addAction(BluetoothDevice.ACTION_ACL_CONNECTED);
    intentFilter.addAction(BleService.ACTION_SERVICE_CHARACTERISTICS);
    return intentFilter;
  }

  /**
   * 绑定service要实现的回调
   */
  private ServiceConnection mServiceConnection = new ServiceConnection() {
    //获取service传回的IBinder对象
    @Override
    public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
      mService = ((BleService.LocalBinder) iBinder).getService();
      LogUtils.d(TAG, "onServiceConnected mService= " + mService);
      if (!mService.initialize()) {
        LogUtils.e(TAG, "Unable to initialize Bluetooth");
        return;
      }
    }

    //客户端与service的连接意外丢失时调用
    @Override
    public void onServiceDisconnected(ComponentName componentName) {
      LogUtils.e(TAG, "与service的连接意外丢失:onServiceDisconnected");
      mService = null;
    }
  };

  /**
   * 监听bleService发出的广播
   */
  private final BroadcastReceiver mBleStatusChangeReceiver = new BroadcastReceiver() {
    @Override
    public void onReceive(Context context, Intent intent) {
      String action = intent.getAction();
      System.out.println("Android端收到广播：" + action);
      switch (action) {
        case BleService.ACTION_GATT_RECONNECTED:
          eventSink.success(sendEvent(EventChannelConstant.STATE_RECONNECTED));
          LogUtils.v(TAG, "STATE_RECONNECTED");
          BlePlugin.is_support = true;
          break;
        case BleService.ACTION_GATT_CONNECTED:
          eventSink.success(sendEvent(EventChannelConstant.STATE_CONNECTED));
          LogUtils.v(TAG, "ACTION_GATT_CONNECTED");
          BlePlugin.mConnected = false;
          break;
        case BleService.ACTION_GATT_DISCONNECTED:
          LogUtils.v(TAG, "ACTION_GATT_DISCONNECTED");
          BlePlugin.mConnected = false;
          //断开连接，释放资源GATT
          mService.close();
          eventSink.success(sendEvent(EventChannelConstant.STATE_DISCONNECTED));
          break;
        case BleService.ACTION_GATT_SERVICES_DISCOVERED:
          eventSink.success(sendEvent(EventChannelConstant.GATT_SERVICES_DISCOVERED));
          LogUtils.v(TAG, "有可用的蓝牙服务：ACTION_GATT_SERVICES_DISCOVERED");
//                    mService.enableTXNotification();
          BlePlugin.is_support = true;
          break;
        case BleService.ACTION_SERVICE_CHARACTERISTICS:
          // 发现服务及其子特征值
          System.out.println(mService.getServiceAndCharacts().toString());
          eventSink.success(sendEvent(EventChannelConstant.SERVICE_CHARACTERISTICS,new Gson().toJson(mService.getServiceAndCharacts())));
          break;
        case BleService.DEVICE_DOES_NOT_SUPPORT_UART:
          eventSink.success(sendEvent(EventChannelConstant.DOES_NOT_SUPPORT_UART));
          LogUtils.v(TAG, "DEVICE_DOES_NOT_SUPPORT_UART");
          BlePlugin.is_support = false;
          if (count == 2) {
            mHandler.sendEmptyMessage(NO_SUPPORT);
            return;
          }
          if (count < 2 && mService != null && !TextUtils.isEmpty(BlePlugin.device_address)) {    //启动2次自动重连
            mService.disconnect();
            mHandler.postDelayed(new Runnable() {
              @Override
              public void run() {
                LogUtils.v(TAG, "无读写服务时的重连：" + count);
                Intent intent = new Intent(BleConstant.BIND_DEVICE);
                intent.putExtra(BleConstant.BIND_DEVICE_ADDRESS, BlePlugin.device_address);
                LocalBroadcastManager.getInstance(mContext).sendBroadcast(intent);
              }
            }, 1500);
            count++;
          }
          break;
        case BleConstant.ACTION_SEND_DATA_TO_BLE:   //发送蓝牙数据
          LogUtils.v(TAG, "发送数据到蓝牙设备");
          byte[] send_data = intent.getByteArrayExtra(BleConstant.EXTRA_SEND_DATA_TO_BLE);
          if (mService != null && send_data != null) {
            mService.BLE_send_data_set(send_data, false);
          }
          break;
        case BleConstant.BIND_DEVICE:        // 绑定蓝牙设备
          if (BlePlugin.mConnectionState == 1) { //正在连接设备
//                        ivSignal.setVisibility(View.GONE);
//                        ivAnim.setVisibility(View.VISIBLE);
//                        ivAnim.animator(true);
          }
          if (BlePlugin.mConnected) {
            LogUtils.v(TAG, "当前有正在连接的设备...");
            return;
          }
          String address = intent.getStringExtra(BleConstant.BIND_DEVICE_ADDRESS);
          LogUtils.v(TAG, "A. BIND_DEVICE:" + address);
          if (mService != null && !TextUtils.isEmpty(address)) {
            BlePlugin.mConnected = true;
            boolean status = mService.connect(address);
            if (!status) {   //连接失败,为true时不一定能连成功，有可能出现： Disconnected from GATT server.
              LogUtils.e(TAG, "连接失败：" + address);
              BlePlugin.mConnected = false;
            } else {    //15秒超时
              mHandler.postDelayed(new Runnable() {
                @Override
                public void run() {
                  BlePlugin.mConnected = false;
                }
              }, 20000);
            }
          } else {
            LogUtils.v(TAG, "重新启动蓝牙服务");
            Intent bindIntent = new Intent(mContext, BleService.class);
            mContext.bindService(bindIntent, mServiceConnection, Context.BIND_AUTO_CREATE);
          }
          break;
        case BleConstant.USER_UNBIND_DEVICE:        // 解绑设备
          LogUtils.v(TAG, "1.手动断开连接");
          if (mService != null) {
            mService.disconnect();
          }
          break;
        case BleService.ACTION_DATA_AVAILABLE:
          //接收到设备发送过来的数据，发送出去
          byte[] txValue = intent.getByteArrayExtra(BleService.EXTRA_DATA);
          if(txValue.length>5)
            System.out.println(txValue[4]);
          List<Integer> datas = DataHandlerUtils.bytesToArrayList(txValue);
          eventSink.success(sendEvent(EventChannelConstant.DATA_AVAILABLE, datas));
          LogUtils.v(TAG, "原始:" + datas + ";接收数据:" + new String(txValue));
          if (txValue.length > 0) {
            String getData = new String(txValue);
            if (getData.contains("GAUT")) {   //授权成功
              is_auth = true;
            } else if (getData.contains("NAUT")) {  //授权失败
              is_auth = false;
            }
          }
          break;
        case BluetoothAdapter.ACTION_STATE_CHANGED:
          final int state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE,
                  BluetoothAdapter.ERROR);
          switch (state) {
            case BluetoothAdapter.STATE_OFF:
              System.out.println("Bluetooth off");
              eventSink.success(sendEvent(EventChannelConstant.BLUETOOTHOFF));
              break;
            case BluetoothAdapter.STATE_TURNING_OFF:
              System.out.println("Turning Bluetooth off...");
              break;
            case BluetoothAdapter.STATE_ON:
              System.out.println("Bluetooth on");
              eventSink.success(sendEvent(EventChannelConstant.BLUETOOTHON));
              break;
            case BluetoothAdapter.STATE_TURNING_ON:
              System.out.println("Turning Bluetooth on...");
              break;
          }
          break;
        case BluetoothDevice.ACTION_ACL_CONNECTED:
          Toast.makeText(context, "蓝牙设备已连接", Toast.LENGTH_SHORT).show();
          break;

        case BluetoothDevice.ACTION_ACL_DISCONNECTED:
          Toast.makeText(context, "蓝牙设备已断开", Toast.LENGTH_SHORT).show();
          break;
      }
    }
  };

  /**
   * 发送指令给ble设备校验权限
   *
   * @param[bytes] 授权码
   */
  private void auth(byte[] bytes) {
    if (!BlePlugin.isConnected) {
      return;
    }
    try {
      final Intent intent = new Intent(BleConstant.ACTION_SEND_DATA_TO_BLE);
      intent.putExtra(BleConstant.EXTRA_SEND_DATA_TO_BLE, bytes);
      LocalBroadcastManager.getInstance(mContext).sendBroadcast(intent);
      LogUtils.v(TAG, "发送广播:" + new String(bytes) + ";真实数据：" + DataHandlerUtils.bytesToArrayList(bytes));
    } catch (Exception e) {
    }
  }


  /**
   * 发送指令给ble设备
   *
   * @param[bytes] 要发送的byte数据
   */
  private void broadcastData(byte[] bytes) {
    if (!BlePlugin.isConnected) {
      throw new RuntimeException("BLE not connected");
    }
    try {
      final Intent intent = new Intent(BleConstant.ACTION_SEND_DATA_TO_BLE);
      intent.putExtra(BleConstant.EXTRA_SEND_DATA_TO_BLE, bytes);
      LocalBroadcastManager.getInstance(mContext).sendBroadcast(intent);
      LogUtils.v(TAG, "发送广播:" + new String(bytes) + ";真实数据：" + DataHandlerUtils.bytesToArrayList(bytes));
    } catch (Exception e) {
    }
  }

  //检查手机是否支持蓝牙
  private boolean isSupport() {
    if (bluetoothAdapter != null) {
      return true;
    }
    return false;
  }

  //检查手机蓝牙是否打开
  private boolean isEnabled() {
    if (bluetoothAdapter != null) {
      if (bluetoothAdapter.isEnabled()) {
        return true;
      }
    }
    return false;
  }

  //开始扫描搜索蓝牙设备
  private boolean startScanBluetooth() {
    if (mDevices == null) {
      mDevices = new ArrayList<>();
      bleDeviceBeans = new ArrayList<>();
    }
    mDevices.clear();
    bleDeviceBeans.clear();
    if (bluetoothAdapter != null) {
      if (!bluetoothAdapter.isEnabled()) {
        throw new RuntimeException("open ble before discover");
      }
      bluetoothAdapter.startLeScan(scanCallback);
      eventSink.success(sendEvent(EventChannelConstant.START_SACN, "start scan ble"));
      return true;
    }
    return false;
  }

  //停止扫描蓝牙设备
  private void stopScanBluetooth() {
    if (mDevices != null) {
      mDevices.clear();
      bleDeviceBeans.clear();
      bluetoothAdapter.stopLeScan(scanCallback);
      eventSink.success(sendEvent(EventChannelConstant.STOP_SACN, "stop scan ble"));
    }
  }

  //连接到蓝牙
  private void connect(String address) {
    BlePlugin.device_address = address;
    mService.connect(address);
  }

  // 打开蓝牙
  private void enabled() {
    if (!bluetoothAdapter.isEnabled()) {
      bluetoothAdapter.enable();
    }
  }

  //手动断开蓝牙连接
  private void disconnect() {
    mService.disconnect();
  }

  //蓝牙当前状态
  // connected 已连接
  // connecting 正在连接
  // disconnect 未连接
  private String status() {
    return mConnectionState == 2 ? "connected" : mConnectionState == 1 ? "connecting" : "disconnect";
  }

  //蓝牙是否连接
  private boolean isConnect() {
    return isConnected;
  }

  // 蓝牙设备列表
  private List<BluetoothDevice> mDevices;
  // 蓝牙设备列表
  private List<String> bleDeviceBeans;
  // 扫描蓝牙设备监听
  private BluetoothAdapter.LeScanCallback scanCallback = new BluetoothAdapter.LeScanCallback() {
    @Override
    public void onLeScan(BluetoothDevice device, int rssi, byte[] scanRecord) {
      System.out.println("scanning");
      if (mDevices.contains(device)) {
        return;
      } else {
//                if (TextUtils.isEmpty(device.getName())) {
//                    return;
//                }
        // 如果搜到的到蓝牙设备的名称为空，则赋值为 "NULLName"
        if (rssi > -90) {         //过滤掉信号弱的设备
          mDevices.add(device);
          // 转成string，再添加到集合
          bleDeviceBeans.add(new Gson().toJson(new BleDeviceBean(device.getAddress(), TextUtils.isEmpty(device.getName()) ? "NUllName" : device.getName(), rssi)));
          //排序
          Collections.sort(bleDeviceBeans);
          System.out.println("bleDeviceBeans:" + new Gson().toJson(bleDeviceBeans, new TypeToken<List<String>>() {
          }.getType()));
          Map map = sendEvent(EventChannelConstant.FOUND_DEVICES, new Gson().toJson(bleDeviceBeans));
          //发送给flutter
          System.out.println("map:" + map.toString());
          eventSink.success(map);
          System.out.println(JSON.toJSONString(map));

        }
      }
    }
  };

  // 发送给flutter
  private Map sendEvent(int code, Object obj) {
    Map<String, Object> map = new HashMap();
    map.put("code", code);
    if (obj != null) {
      map.put("data", JSON.toJSON(obj));
    }
    return map;
  }

  // 发送给flutter
  private Map sendEvent(int code) {
    Map<String, Object> map = new HashMap();
    map.put("code", code);
    return map;
  }

  // This static function is optional and equivalent to onAttachedToEngine. It supports the old
  // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
  // plugin registration via this function while apps migrate to use the new Android APIs
  // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
  //
  // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
  // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
  // depending on the user's project. onAttachedToEngine or registerWith must both be defined
  // in the same class.
  public static void registerWith(Registrar registrar) {
    System.out.println("registerWith************");
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "flutter_ble");
    channel.setMethodCallHandler(new BlePlugin());

  }

  // flutter调用原生Android处理方法
  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    System.out.println(call.method);
    switch (call.method) {
      case "getPlatformVersion":
        result.success("Android " + Build.VERSION.RELEASE);
        break;
      case "isSupport":
        result.success(isSupport());
        break;
      case "setWriteCharactor":
        mService.setWriteCharactUUid(call.argument("uuid").toString());
        break;
      case "setNotifyCharactor":
        mService.setNotifyCharact(call.argument("uuid").toString(),call.argument("isNotify").equals("true")?true:false);
        break;
      case "isEnabled":
        result.success(isEnabled());
        break;
      case "startScanBluetooth":
        result.success(startScanBluetooth());
        break;
      case "stopScanBluetooth":
        stopScanBluetooth();
        break;
      case "connect":
        connect(call.argument("address").toString());
        break;
      case "enabled":
        enabled();
        break;
      case "disconnect":
        disconnect();
        break;
      case "status":
        result.success(status());
        break;
      case "isConnect":
        result.success(isConnect());
        break;
      case "auth":
        auth(call.argument("authCode").toString().getBytes());
        break;
      case "broadcastData":
        // 发送ASCALL码
        broadcastData(call.argument("command").toString().getBytes());
        break;
      case "broadcastOData":
        // 发送二进制数据
        Gson gson = new Gson();
        ArrayList<Integer> json = gson.fromJson(call.argument("command").toString(), new TypeToken<ArrayList<Integer>>() {
        }.getType());
        System.out.println(list2byte(json));
        System.out.println("byte数组----------");
        System.out.println(list2byte(json)[0]);
        broadcastData(list2byte(json));
        break;
      case "isCommanding":
        result.success(mService.sendingStoredData);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  // 十进制数组转换为byte数组
  private byte[] list2byte(List list) {
    System.out.println("127127127-----");
    System.out.println((byte) ((Integer) 127).intValue());
    System.out.println("128128128-----");
    System.out.println((byte) ((Integer) 128).intValue());
    byte[] bytes = new byte[list.size()];
    for (int i = 0; i < list.size(); i++) {
      bytes[i] = (byte) ((Integer) list.get(i)).intValue();
      System.out.println(bytes[i]);
    }
    return bytes;
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    Log.d(TAG, "onDetachedFromEngine: *************");
    // 释放资源，解绑服务和取消注册广播
    channel.setMethodCallHandler(null);
    mContext.unbindService(mServiceConnection);
    LocalBroadcastManager.getInstance(mContext).unregisterReceiver(mBleStatusChangeReceiver);
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    System.out.println("fffffffffffffffffffffffffff");
//        initPermission(binding.getActivity());
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {

  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
//        mContext = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivity() {

  }

  /**
   * 申请权限 留给上层
   */
  private void initPermission(Activity activity) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      //请求定位打开
      LocationManager locationManager = (LocationManager) mContext.getSystemService(Context.LOCATION_SERVICE);
      if (!locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
        final AlertDialog.Builder builder = new AlertDialog.Builder(mContext);
        final String action = Settings.ACTION_LOCATION_SOURCE_SETTINGS;
        final String message = "需要定位权限";
        builder.setMessage(message)
                .setPositiveButton(android.R.string.ok,
                        new DialogInterface.OnClickListener() {
                          @Override
                          public void onClick(DialogInterface d, int id) {
                            mContext.startActivity(new Intent(action));
                            d.dismiss();
                          }
                        })
                .setNegativeButton(android.R.string.cancel,
                        new DialogInterface.OnClickListener() {
                          @Override
                          public void onClick(DialogInterface d, int id) {
                            d.cancel();
                          }
                        });
        builder.create().show();
      }
      if (mContext.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
        activity.requestPermissions(new String[]{Manifest.permission.ACCESS_COARSE_LOCATION}, 1);
      }
    }
  }
}
