package com.lg.ble;

import java.util.ArrayList;
import java.util.List;

/**
 * 数据操作工具类
 */
public class DataHandlerUtils {

    private static final String TAG = "tzz_DataHandlerUtils";

    /**
     * 拼接字节数组
     * @param data1
     * @param data2
     * @return
     */
    public static byte[] addBytes(byte[] data1, byte[] data2) {
        byte[] data3 = data1;
        if (data2 != null && data2.length != 0){
            data3 = new byte[data1.length + data2.length];
            System.arraycopy(data1, 0, data3, 0, data1.length);
            System.arraycopy(data2, 0, data3, data1.length, data2.length);
        }
        return data3;
    }


    /**
     * byte[] --> 十六进制的字符串
     * @param bytes
     * @return
     */
    public static String bytesToHexStr(byte[] bytes){
        StringBuilder stringBuilder = new StringBuilder();
        if (bytes == null || bytes.length <= 0) {
            return null;
        }
        for (int i = 0; i < bytes.length; i++) {
            int v = bytes[i] & 0xFF;
            String hv = Integer.toHexString(v);
            if (hv.length() < 2) {
                stringBuilder.append(" " + 0 + hv);
            }else{
                stringBuilder.append(" " + hv);
            }
        }
        return stringBuilder.toString();
    }

    /**
     * 字节数组转化成集合
     */
    public static List<Integer> bytesToArrayList(byte[] bytes){
        List<Integer> datas = new ArrayList<>();
        for (int i = 0; i < bytes.length; i++) {
            datas.add(bytes[i] & 0xff);
        }
        return datas;
    }

    /**
     * 字节数组转化成集合
     */
    public static List<Integer> bytesToArrayListForEcg(byte[] bytes){
        List<Integer> datas = new ArrayList<>();
        for (int i = 2; i < bytes.length; i++) {
            if (i%2==0&&bytes.length%2==0){
                datas.add((bytes[i]&0xff)+(bytes[i+1]&0xff)*256);
            }
        }
        return datas;
    }
}