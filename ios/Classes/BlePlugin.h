#import <Flutter/Flutter.h>
#import <CoreBluetooth/CoreBluetooth.h>


@interface BlePlugin : NSObject<FlutterPlugin,FlutterStreamHandler,CBCentralManagerDelegate,CBPeripheralDelegate>

// ISO 底层向flutter上层发送事件
@property(strong,nonatomic)FlutterEventSink eventSink;
// 状态标志位
@property(assign,nonatomic)NSInteger state;
@property(assign,nonatomic)BOOL isConnected ;//蓝牙是否连接
@property(assign,nonatomic)BOOL isEnable;//蓝牙是否打开
@property(assign,nonatomic)BOOL isSupport;//蓝牙是否支持
// 蓝牙管理类
@property(strong,nonatomic)CBCentralManager* centralManager;
@property(retain,nonatomic)CBPeripheral* peripheral;// 当前连接的蓝牙外设
@property(retain,nonatomic)CBCharacteristic* writeCharacteristic;//写特征值
@property(retain,nonatomic)CBCharacteristic* readCharacteristic;// 读特征值
@end



