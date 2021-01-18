package com.lg.ble;

import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.content.Context;
import android.content.Intent;
import android.os.Binder;
import android.os.Build;
import android.os.CountDownTimer;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.text.TextUtils;
import android.util.Log;

import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

/**
 * 当你需要手动断开时,调用disconnect()方法，此时断开成功后会回调onConnectionStateChange方法,在这个方法中再调用close方法释放资源。
 * 如果在disconnect后立即调用close，会导致无法回调onConnectionStateChange方法。
 */
public class BleService extends Service {

    private static final String TAG = "BleService";
    // 蓝牙管理器
    private BluetoothManager mBluetoothManager;
    // 蓝牙适配器
    private BluetoothAdapter mBluetoothAdapter;
    // 蓝牙mac地址
    private String mBluetoothDeviceAddress;
    // 低功耗蓝牙对象
    private BluetoothGatt mBluetoothGatt;
    // 蓝牙断开状态
    private static final int STATE_DISCONNECTED = 0;
    // 蓝牙连接中状态
    private static final int STATE_CONNECTING = 1;
    // 蓝牙连接状态
    private static final int STATE_CONNECTED = 2;
    private TimeCountFirst timeFirst=null;   //断开自动重连定时器
    // 蓝牙连接成通知
    public final static String ACTION_GATT_CONNECTED = "com.flutterble.ACTION_GATT_CONNECTED";
    // 蓝牙连接成通知
    public final static String ACTION_GATT_RECONNECTED = "com.flutterble.ACTION_GATT_RECONNECTED";
    // 蓝牙连接断开通知
    public final static String ACTION_GATT_DISCONNECTED = "com.flutterble.ACTION_GATT_DISCONNECTED";
    // 发现蓝牙服务通知
    public final static String ACTION_GATT_SERVICES_DISCOVERED = "com.flutterble.ACTION_GATT_SERVICES_DISCOVERED";
    // 接收数据通知
    public final static String ACTION_DATA_AVAILABLE = "com.flutterble.ACTION_DATA_AVAILABLE";
    // 发送数据通知
    public final static String EXTRA_DATA = "com.flutterble.EXTRA_DATA";
    // 没有可用的服务通知
    public final static String DEVICE_DOES_NOT_SUPPORT_UART = "com.flutterble.DEVICE_DOES_NOT_SUPPORT_UART";

    // 发现服务及其子特征值通知
    public final static String ACTION_SERVICE_CHARACTERISTICS = "com.flutterble.SERVICE_AND_CHILDREN_CHARACTERISTIC";

    // 单个数据包最大值现在
    private static final int SEND_PACKET_SIZE = 160;
    // 空闲
    private static final int FREE = 0;
    // 数据发送中
    private static final int SENDING = 1;
    // 蓝牙状态，是否正在发送数据
    private int ble_status = FREE;
    // 数据包总数
    private int packet_counter = 0;
    // 发送数据节点
    private int send_data_pointer = 0;
    // 要发送的数据字节数组
    private byte[] send_data = null;
    // 第一个数据包
    private boolean first_packet = false;
    // 最后一个数据包
    private boolean final_packet = false;
    // 正在发送数据包
    private boolean packet_send = false;
    // 定时器
    private Timer mTimer;
    // 超时次数
    private int time_out_counter = 0;
    // 重连时间
    private int TIMER_INTERVAL = 100;
    // 超时时间
    private int TIME_OUT_LIMIT = 100;
    //要发送数据队列
    public ArrayList<byte[]> data_queue = new ArrayList<>();
    //是否正在发送数据
    boolean sendingStoredData = false;

    // 所有的特征值集合
    List<BluetoothGattCharacteristic> listCharacts = new ArrayList<>();
    // 所有的服务及其子特征值，键是服务的uuid，值是对应服务下的子特征值集合
    Map<String,List<Map<String,String>>> serviceAndCharacts = new HashMap();

    public Map<String, List<Map<String, String>>> getServiceAndCharacts() {
        return serviceAndCharacts;
    }

    // 写特征值的uuid
    String writeCharactUUid = null;
    // 通知特征值的uuid
    String readCharactUUid = null;

    public void setWriteCharactUUid(String writeCharactUUid) {
        this.writeCharactUUid = writeCharactUUid;
    }

    /**
     * 设置释放接收特征值的通知
     * @param readCharactUUid 特征值uuid
     * @param isNotify 是否订阅通知
     */
    public void setNotifyCharact(String readCharactUUid,boolean isNotify){
        if(TextUtils.isEmpty(readCharactUUid)){
            throw new RuntimeException("notify uuid not be null");
        }
        if(listCharacts == null||listCharacts.size()==0){
            throw new RuntimeException("service and characteristic is empty");
        }
        this.readCharactUUid = readCharactUUid;
        BluetoothGattCharacteristic readCharact = null;
        // 遍历查找特征值
        for(int i=0;i<listCharacts.size();i++){
            if(readCharactUUid.equals(listCharacts.get(i).getUuid().toString())){
                readCharact = listCharacts.get(i);
                break;
            }
        }
        // 订阅
        mBluetoothGatt.setCharacteristicNotification(readCharact,isNotify);
        List<BluetoothGattDescriptor> descriptors = readCharact.getDescriptors();
//                    System.out.println("descriptors--------------");
//                    for(int i = 0;i<descriptors.size();i++){
//                        System.out.println(descriptors.get(i).getUuid().toString());
//                    }
        // 不知道这个BluetoothGattDescriptor是干嘛的，所有检测到有的话就把第一个给它,不加的话还收不到数据
        if(descriptors.size()>0) {
            BluetoothGattDescriptor descriptor = readCharact.getDescriptor(readCharact.getDescriptors().get(0).getUuid());
            if (descriptor != null) {
                descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                mBluetoothGatt.writeDescriptor(descriptor);
            }
        }
    }

    private Handler mHandler=new Handler(){
        @Override
        public void handleMessage(Message msg) {
            super.handleMessage(msg);
        }
    };



    // 低功耗蓝牙连接监听
    private final BluetoothGattCallback mGattCallback = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            String intentAction;
            BlePlugin.state=status;
            LogUtils.v(TAG,"C/3. c:"+status+",newState:"+newState);
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                BlePlugin.isConnected=true;
                intentAction = ACTION_GATT_CONNECTED;
                BlePlugin.mConnectionState = STATE_CONNECTED;
                broadcastUpdate(intentAction);
                // 成功连接后尝试发现服务
                boolean discoverState=mBluetoothGatt.discoverServices();
                LogUtils.i(TAG, "D. Attempting to start service discovery:" + discoverState);
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                if(status==0){     //正常断开
                    LogUtils.v(TAG,"正常断开");
                    BlePlugin.isConnected=false;
                    intentAction = ACTION_GATT_DISCONNECTED;
                    BlePlugin.mConnectionState = STATE_DISCONNECTED;
                    broadcastUpdate(intentAction);
                }else {
                    LogUtils.v(TAG,"意外断开");
                    if(mBluetoothGatt != null){
                        mBluetoothGatt.disconnect();
                        mBluetoothGatt.close();
//                        mBluetoothGatt = null;
                    }
                    if(status == 133){
                        // 重连次数
                        if(retry>=5){
                            retry =0;
                            // 发送断开连接的广播，重置标志位
                            BlePlugin.isConnected=false;
                            intentAction = ACTION_GATT_DISCONNECTED;
                            BlePlugin.mConnectionState = STATE_DISCONNECTED;
                            broadcastUpdate(intentAction);
                            return;
                        }
                        retry ++;
                        connect(mBluetoothDeviceAddress);
                    }else{
                        //其他状态码直接发送断开连接广播，重置标志位
                        BlePlugin.isConnected=false;
                        intentAction = ACTION_GATT_DISCONNECTED;
                        BlePlugin.mConnectionState = STATE_DISCONNECTED;
                        broadcastUpdate(intentAction);
                    }
                }
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            LogUtils.v(TAG, "E. status:"+status+";mBluetoothGatt = " + gatt );
            if (status == BluetoothGatt.GATT_SUCCESS) {
                // 有可用的蓝牙服务
                broadcastUpdate(ACTION_GATT_SERVICES_DISCOVERED);
                List<BluetoothGattService> services = gatt.getServices();
                System.out.println("servicesize--------------");
                System.out.println(services.size());
                buildServiceAndCharacteristic(services);
                notifyCharacteristic();
                broadcastUpdate(ACTION_SERVICE_CHARACTERISTICS);
            } else {
                LogUtils.v(TAG, "发现服务失败,onServicesDiscovered received: " + status);
            }
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt gatt,
                                         BluetoothGattCharacteristic characteristic,
                                         int status) {
            LogUtils.w("onCharacteristicRead:***********");
            // 监听到数据
            if (status == BluetoothGatt.GATT_SUCCESS) {
                broadcastUpdate(ACTION_DATA_AVAILABLE, characteristic);
            }
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
            LogUtils.w("onCharacteristicChanged:***********");
            // 监听到数据
            broadcastUpdate(ACTION_DATA_AVAILABLE, characteristic);
        }
    };

    // 订阅特征值
    private void notifyCharacteristic() {
        BluetoothGattCharacteristic readCharact = null;
        if(!TextUtils.isEmpty(readCharactUUid)){
            for(int i = 0;i<listCharacts.size();i++){
                if(listCharacts.get(i).getUuid().toString().equals(readCharactUUid)){
                    readCharact = listCharacts.get(i);
                    break;
                }
            }
            mBluetoothGatt.setCharacteristicNotification(readCharact,true);
            List<BluetoothGattDescriptor> descriptors = readCharact.getDescriptors();
//                    System.out.println("descriptors--------------");
//                    for(int i = 0;i<descriptors.size();i++){
//                        System.out.println(descriptors.get(i).getUuid().toString());
//                    }
            // 不知道这个BluetoothGattDescriptor是干嘛的，所有检测到有的话就把第一个给它,不加的话还收不到数据
            if(descriptors.size()>0) {
                BluetoothGattDescriptor descriptor = readCharact.getDescriptor(readCharact.getDescriptors().get(0).getUuid());
                if (descriptor != null) {
                    descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                    mBluetoothGatt.writeDescriptor(descriptor);
                }
            }
        }
    }

    // 构建服务集合，特征值集合
    private void buildServiceAndCharacteristic(List<BluetoothGattService> services) {
        listCharacts.clear();
        serviceAndCharacts.clear();
        writeCharactUUid = null;
        readCharactUUid = null;
        for(int i = 0 ;i<services.size();i++){
            BluetoothGattService service = services.get(i);
            List<BluetoothGattCharacteristic> characteristics = service.getCharacteristics();
            listCharacts.addAll(characteristics);
            List<Map<String,String>> listCharacts = new ArrayList<>();
            for(int j = 0;j<characteristics.size();j++){
                Map<String,String> charactProperties = new HashMap<>();
                BluetoothGattCharacteristic characteristic = characteristics.get(j);
                charactProperties.put("uuid",characteristic.getUuid().toString());
                String type = "";
                if((characteristic.getProperties()&BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) !=0){
                    type += "Write Without Response ";
                    if(null == writeCharactUUid){
                        writeCharactUUid = characteristic.getUuid().toString();
                    }
                }
                if((characteristic.getProperties()&BluetoothGattCharacteristic.PROPERTY_NOTIFY) !=0){
                    type += "Notify ";
                    if(null == readCharactUUid){
                        readCharactUUid = characteristic.getUuid().toString();
                    }
                }
                if((characteristic.getProperties()&BluetoothGattCharacteristic.PROPERTY_WRITE) !=0){
                    type += "Write ";
                    if(null == writeCharactUUid){
                        writeCharactUUid = characteristic.getUuid().toString();
                    }
                }
                if((characteristic.getProperties()&BluetoothGattCharacteristic.PROPERTY_READ) !=0){
                    type += "Read ";

                }
                if(TextUtils.isEmpty(type)){
                    type = "None";
                }
                charactProperties.put("type",type);
                listCharacts.add(charactProperties);
            }
            serviceAndCharacts.put(service.getUuid().toString(),listCharacts);
        }
    }

    private int retry=0;

    // 发送广播通知
    private void broadcastUpdate(final String action) {
        final Intent intent = new Intent(action);
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
    }

    // 接收到蓝牙数据广播通知
    private void broadcastUpdate(final String action, final BluetoothGattCharacteristic characteristic) {
        final Intent intent = new Intent(action);
        intent.putExtra(EXTRA_DATA, characteristic.getValue());
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
    }

    public class LocalBinder extends Binder {
        public BleService getService() {
            return BleService.this;
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return mBinder;
    }

    @Override
    public boolean onUnbind(Intent intent) {
        // After using a given device, you should make sure that BluetoothGatt.close() is called
        // such that resources are cleaned up properly.  In this particular example, close() is
        // invoked when the UI is disconnected from the Service.
        close();
        return super.onUnbind(intent);
    }

    private final IBinder mBinder = new LocalBinder();

    /**
     * Initializes a reference to the local Bluetooth adapter.
     *
     * @return Return true if the initialization is successful.
     */
    public boolean initialize() {
        // For API level 18 and above, get a reference to BluetoothAdapter through BluetoothManager.
        if (mBluetoothManager == null) {
            mBluetoothManager = (BluetoothManager) getSystemService(Context.BLUETOOTH_SERVICE);
            if (mBluetoothManager == null) {
                LogUtils.e(TAG, "Unable to initialize BluetoothManager.");
                return false;
            }
        }
        mBluetoothAdapter = mBluetoothManager.getAdapter();
        if (mBluetoothAdapter == null) {
            LogUtils.e(TAG, "Unable to obtain a BluetoothAdapter.");
            return false;
        }
        return true;
    }

    /**
     * Connects to the GATT server hosted on the Bluetooth LE device.
     * @param address The device address of the destination device.
     * @return Return true if the connection is initiated successfully. The connection result
     *         is reported asynchronously through the
     *         {@code BluetoothGattCallback#onConnectionStateChange(android.bluetooth.BluetoothGatt, int, int)}
     *         callback.
     */
    public boolean connect(final String address) {
        if (mBluetoothAdapter == null || TextUtils.isEmpty(address)) {
            LogUtils.w(TAG, "BluetoothAdapter not initialized or unspecified address.");
            return false;
        }
        if(mBluetoothGatt !=null && mBluetoothManager.getConnectedDevices(BluetoothProfile.GATT_SERVER) !=null){
            for(BluetoothDevice device:mBluetoothManager.getConnectedDevices(BluetoothProfile.GATT_SERVER)){
                if(device.getAddress().equals(mBluetoothDeviceAddress)){//如果当前遍历出的连接设备和我们要连接的设备是同一设备
                    mBluetoothGatt.disconnect();// 先断开连接，解决133的问题
                    Log.d(TAG, "133: 133*****************");
                }
            }
            mBluetoothGatt.close();
            mBluetoothGatt = null;
        }
        final BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(address);
        if (device == null) {
            LogUtils.w(TAG, "Device not found.  Unable to connect.");
            return false;
        }
        // We want to directly connect to the device, so we are setting the autoConnect parameter to false.
        Log.d(TAG, "sdk_version:"+ Build.VERSION.SDK_INT);
        if(Build.VERSION.SDK_INT>= Build.VERSION_CODES.M){
            mBluetoothGatt = device.connectGatt(this, false, mGattCallback, BluetoothDevice.TRANSPORT_LE);
        }else {
            mBluetoothGatt = device.connectGatt(this, false, mGattCallback);
        }
        LogUtils.v(TAG, "B. 创建mBluetoothGatt开始连接...");
        mBluetoothDeviceAddress = address;
        BlePlugin.mConnectionState = STATE_CONNECTING;
        return true;
    }

    /**
     * Disconnects an existing connection or cancel a pending connection. The disconnection result
     * is reported asynchronously through the
     * {@code BluetoothGattCallback#onConnectionStateChange(android.bluetooth.BluetoothGatt, int, int)}
     * callback.
     */
    public void disconnect() {
        LogUtils.v(TAG,"2.disconnect()");
        if (mBluetoothAdapter == null || mBluetoothGatt == null) {
            return;
        }
        mBluetoothGatt.disconnect();
    }

    /**
     * After using a given BLE device, the app must call this method to ensure resources are
     * released properly.
     */
    public void close() {
        LogUtils.v(TAG, "4.mBluetoothGatt closed");
        if (mBluetoothGatt == null) {
            return;
        }
        mBluetoothDeviceAddress = null;
        mBluetoothGatt.close();
        mBluetoothGatt = null;
    }

    /**
     * Request a read on a given {@code BluetoothGattCharacteristic}. The read result is reported
     * asynchronously through the {@code BluetoothGattCallback#onCharacteristicRead(android.bluetooth.BluetoothGatt, android.bluetooth.BluetoothGattCharacteristic, int)}
     * callback.
     *
     * @param characteristic The characteristic to read from.
     */
    public void readCharacteristic(BluetoothGattCharacteristic characteristic) {
        if (mBluetoothAdapter == null || mBluetoothGatt == null) {
            LogUtils.v(TAG, "BluetoothAdapter not initialized");
            return;
        }
        mBluetoothGatt.readCharacteristic(characteristic);
    }

    /**
     * 设置写的服务，特征值
     * value 要发送给蓝牙设备的字节数据
     * return true/false 是否写成功
     * */
    public boolean writeRXCharacteristic(byte[] value) {
        if(mBluetoothGatt!=null){
            BluetoothGattCharacteristic writeCharact = null;
            for(int i=0;i<listCharacts.size();i++){
                if(listCharacts.get(i).getUuid().toString().equals(writeCharactUUid)){
                    writeCharact = listCharacts.get(i);
                    break;
                }
            }
            if(writeCharact == null){
                throw new RuntimeException("write characteristic can not be null");
            }
            writeCharact.setValue(value);
            //发送数据
            boolean status = mBluetoothGatt.writeCharacteristic(writeCharact);
            LogUtils.d(TAG, "write TXchar - status=" + status+",内容:"+ DataHandlerUtils.bytesToArrayList(value));
            return status;
        }else {
            return false;
        }
    }

    /**
     * Retrieves a list of supported GATT services on the connected device. This should be
     * invoked only after {@code BluetoothGatt#discoverServices()} completes successfully.
     * @return A {@code List} of supported services.
     */
    public List<BluetoothGattService> getSupportedGattServices() {
        if (mBluetoothGatt == null) return null;
        return mBluetoothGatt.getServices();
    }

    /**
     * 设置数据到内部缓冲区对BLE发送数据
     * data 要发送的数据
     * retry_status 是否需要重试 false 需要重试  true 不需要重试
     */
    public void BLE_send_data_set(byte[] data, boolean retry_status) {
        if (ble_status != FREE || BlePlugin.mConnectionState != STATE_CONNECTED) {
            //蓝牙没有连接或是正在接受或发送数据，此时将要发送的指令加入集合
            if (sendingStoredData) {
                if (!retry_status) {
                    data_queue.add(data);
                }
                return;
            } else {
                data_queue.add(data);
                start_timer();
            }
        } else {
            ble_status = SENDING;
            if (data_queue.size() != 0) {
                send_data = data_queue.get(0);
                sendingStoredData = false;
            } else {
                send_data = data;
            }
            packet_counter = 0;
            send_data_pointer = 0;
            //第一个包
            first_packet = true;
            BLE_data_send();
            if (data_queue.size() != 0) {
                data_queue.remove(0);
            }
            if (data_queue.size() == 0) {
                if (mTimer != null) {
                    mTimer.cancel();
                }
            }
        }
    }

    /**
     * @brief Send data using BLE. 发送数据到蓝牙
     */
    private void BLE_data_send() {
        int err_count = 0;
        int send_data_pointer_save;
        int wait_counter;
        boolean first_packet_save;
        while (!final_packet) {
            //不是最后一个包
            byte[] temp_buffer;
            send_data_pointer_save = send_data_pointer;
            first_packet_save = first_packet;
            if (first_packet) {
                //第一个包
                if ((send_data.length - send_data_pointer) > (SEND_PACKET_SIZE)) {
                    temp_buffer = new byte[SEND_PACKET_SIZE];//20
                    for (int i = 0; i < SEND_PACKET_SIZE; i++) {
                        //将原数组加入新创建的数组
                        temp_buffer[i] = send_data[send_data_pointer];
                        send_data_pointer++;
                    }
                } else {
                    //发送的数据包不大于20
                    temp_buffer = new byte[send_data.length - send_data_pointer];
                    for (int i = 0; i < temp_buffer.length; i++) {
                        //将原数组未发送的部分加入新创建的数组
                        temp_buffer[i] = send_data[send_data_pointer];
                        send_data_pointer++;
                    }
                    final_packet = true;
                }
                first_packet = false;
            } else {
                //不是第一个包
                if (send_data.length - send_data_pointer >= SEND_PACKET_SIZE) {
                    temp_buffer = new byte[SEND_PACKET_SIZE];
                    temp_buffer[0] = (byte) packet_counter;
                    for (int i = 1; i < SEND_PACKET_SIZE; i++) {
                        temp_buffer[i] = send_data[send_data_pointer];
                        send_data_pointer++;
                    }
                } else {
                    final_packet = true;
                    temp_buffer = new byte[send_data.length - send_data_pointer + 1];
                    temp_buffer[0] = (byte) packet_counter;
                    for (int i = 1; i < temp_buffer.length; i++) {
                        temp_buffer[i] = send_data[send_data_pointer];
                        send_data_pointer++;
                    }
                }
                packet_counter++;
            }
            packet_send = false;

            boolean status = writeRXCharacteristic(temp_buffer);
            if ((status == false) && (err_count < 3)) {
                err_count++;
                try {
                    Thread.sleep(50);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
                send_data_pointer = send_data_pointer_save;
                first_packet = first_packet_save;
                packet_counter--;
            }
            // Send Wait
            for (wait_counter = 0; wait_counter < 5; wait_counter++) {
                if (packet_send == true) {
                    break;
                }
                try {
                    Thread.sleep(10);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
        final_packet = false;
        ble_status = FREE;
    }

    /**
     * 定时器 每隔100ms重试一次，发送缓存到队列的数据
     */
    private void start_timer() {
        sendingStoredData = true;
        if (mTimer != null) {
            mTimer.cancel();
        }
        mTimer = new Timer(true);
        mTimer.schedule(new TimerTask() {
            @Override
            public void run() {
                timer_Tick();
            }
        }, 100, TIMER_INTERVAL);
    }

    /**
     * @brief Interval timer function.
     * 重试发送数据
     */
    private void timer_Tick() {
        if (data_queue.size() != 0) {
            sendingStoredData = true;
            BLE_send_data_set(data_queue.get(0), true);
        }
        if (time_out_counter < TIME_OUT_LIMIT) {
            time_out_counter++;
        } else {
            ble_status = FREE;
            time_out_counter = 0;
        }
        return;
    }

    /**
     * 30s自动重连
     */
    private class TimeCountFirst extends CountDownTimer {
        public TimeCountFirst(long millisInFuture, long countDownInterval) {
            super(millisInFuture, countDownInterval);
        }

        @Override
        public void onTick(long millisUntilFinished) {
            if(BlePlugin.isConnected){
                timeFirst.cancel();
                timeFirst=null;
            }else {
                disconnect();
                mHandler.postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        if(BlePlugin.mService!=null){
                            LogUtils.v(TAG,"试着自动重连："+BlePlugin.device_address);
                            BlePlugin.mService.connect(BlePlugin.device_address);
                        }
                    }
                },1000);
            }
        }

        @Override
        public void onFinish() {
            timeFirst.cancel();
            timeFirst=null;
            LogUtils.v(TAG,"连接超时,结束自动重连...");
            BlePlugin.state=3;
        }
    }

    @Override
    public void onDestroy() {
        //销毁
        super.onDestroy();
        if(timeFirst!=null){
            timeFirst.cancel();
            timeFirst=null;
        }
    }
}

