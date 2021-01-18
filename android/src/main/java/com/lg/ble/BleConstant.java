package com.lg.ble;

/**
 * 与ble相关的常量配置
 */
public class BleConstant {

    //发送通知到蓝牙服务
    public static final String ACTION_SEND_DATA_TO_BLE = "com.flutterble.ACTION_SEND_DATA_TO_BLE";
    public static final String EXTRA_SEND_DATA_TO_BLE = "com.flutterble.EXTRA_SEND_DATA_TO_BLE";
    //绑定设备的action
    public static final String BIND_DEVICE = "com.flutterble.BIND_DEVICE";
    //用户解绑设备的action
    public static final String USER_UNBIND_DEVICE = "com.flutterble.USER_UNBIND_DEVICE";
    //需要绑定的蓝牙地址：intent参数名
    public static String BIND_DEVICE_ADDRESS = "BIND_DEVICE_ADDRESS";

}
