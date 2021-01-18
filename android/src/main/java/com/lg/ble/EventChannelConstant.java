package com.lg.ble;

/**
 * Create by laoge
 * on 2020/7/16 0016
 */
class EventChannelConstant {
    public static int FOUND_DEVICES=1;//搜索到蓝牙设备
    public static int START_SACN=2;//开始扫描
    public static int STOP_SACN=3;//开始扫描
    public static int STATE_CONNECTED=4;//蓝牙状态改变，连接上了蓝牙
    public static int STATE_DISCONNECTED=5;//蓝牙状态改变，蓝牙连接断开
    public static int GATT_SERVICES_DISCOVERED=6;//发现可用的蓝牙服务
    public static int DOES_NOT_SUPPORT_UART=7;//服务或特征值不可用
    public static int DATA_AVAILABLE=8;//收到蓝牙设备发送的数据
    public static int BLUETOOTHOFF=9;//蓝牙关闭通知
    public static int BLUETOOTHON=10;//蓝牙开启通知
    public static int STATE_RECONNECTED=11;//蓝牙状态改变，重连上了之前的蓝牙，不需要发现服务
    public static int SERVICE_CHARACTERISTICS=12;//发现服务及其子特征值
}
