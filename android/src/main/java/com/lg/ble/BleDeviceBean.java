package com.lg.ble;

import androidx.annotation.NonNull;

/**
 * 蓝牙设备对象
 * 包含蓝牙地址、蓝牙名称、蓝牙信号强度(rssi)
 * 这个类在混淆的时候不要被混淆掉，不然json解析的时候会出错
 */
public class BleDeviceBean implements Comparable {
    private String address;
    private String name;
    private int rssi;

    public BleDeviceBean(String address, String name, int rssi) {
        this.address = address;
        this.name = name;
        this.rssi = rssi;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public int getRssi() {
        return rssi;
    }

    public void setRssi(int rssi) {
        this.rssi = rssi;
    }

    @Override
    public String toString() {
        return "BleDeviceBean{" +
                "address='" + address + '\'' +
                ", name='" + name + '\'' +
                ", rssi=" + rssi +
                '}';
    }

    @Override
    public int compareTo(@NonNull Object o) {
        int compareRssi = ((BleDeviceBean)o).getRssi();
        return compareRssi-this.rssi;
    }


}
