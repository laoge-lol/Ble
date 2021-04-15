#import "BlePlugin.h"

@interface BlePlugin (){
    // 所有的蓝牙设备集合
    NSMutableArray *peripheralDataArray;
    // 所有的服务及其子特征值的字典集合，以键值对保存，键是服务的uuid，值是特征值uuid和properties字典的集合
    NSMutableDictionary *serviceAndCharacteristicsArray;
    // 所有服务及其子特征值的字典集合，以键值对保存，键是服务的uuid，值是特征值对象的集合
    NSMutableDictionary *SAndCArray;
}
@end
#define channelOnPeropheralView @"peripheralView"
int const FOUND_DEVICES =  1;//搜索到蓝牙设备
int const START_SACN=2;//开始扫描
int const STOP_SACN=3;//开始扫描
int const STATE_CONNECTED=4;//蓝牙状态改变，连接上了蓝牙
int const STATE_DISCONNECTED=5;//蓝牙状态改变，蓝牙连接断开
int const GATT_SERVICES_DISCOVERED=6;//发现可用的蓝牙服务
int const DOES_NOT_SUPPORT_UART=7;//服务或特征值不可用
int const DATA_AVAILABLE=8;//收到蓝牙设备发送的数据
int const BLUETOOTHOFF=9;//蓝牙关闭通知
int const BLUETOOTHON=10;//蓝牙开启通知
int const STATE_RECONNECTED=11;//蓝牙状态改变，重连上了之前的蓝牙，不需要发现服务
int const SERVICE_CHARACTERISTICS=12;//发现服务和特征值
int const BLUETOOTH_NOT_FOUND=13;//没有找到蓝牙

@implementation BlePlugin
{
    NSString * tempAddress;//重连地址
}


- (instancetype)init
{
    self = [super init];
    return self;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    NSLog(@"registerWithRegistrar*****");
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_ble"
                                     binaryMessenger:[registrar messenger]];
    BlePlugin* instance = [[BlePlugin alloc] initWithChannel:registrar];
    [registrar addMethodCallDelegate:instance channel:channel];
    NSLog(@"registerWithRegistrar------");
}

// 注册eventchannel事件
-(instancetype)initWithChannel:(NSObject<FlutterPluginRegistrar> *) registrar{
    // 初始化变量
    _state = 0;
    _isConnected = false;
    _isSupport = true;
    FlutterEventChannel * eventChannel = [FlutterEventChannel eventChannelWithName:@"flutter_ble_event" binaryMessenger:[registrar messenger]];
    [eventChannel setStreamHandler:self];
    [self initBluetooth];
    return self;
}


#pragma mark - FlutterStreamHandler
- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments eventSink:(FlutterEventSink)events{
    NSLog(@"onListenWithArguments********");
    if(events){
        _eventSink = events;
    }
    return nil;
}

- (FlutterError * _Nullable)onCancelWithArguments:(id _Nullable)arguments{
    _eventSink = nil;
    return nil;
}

-(void)initBluetooth{
    //    [SVProgressHUD showInfoWithStatus:@"准备打开设备"];
    NSLog(@"initBluetooth");
    peripheralDataArray = [[NSMutableArray alloc]init];
    
    //初始化 蓝牙库
    _centralManager = [[CBCentralManager alloc]initWithDelegate:self queue:nil];
}

-(NSString*)DataTOjsonString:(id)object
{
    NSString *jsonString = nil;
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return jsonString;
}


//蓝牙状态监听，当蓝牙状态发生改变时，会触发此函数
- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    NSLog(@"centralManagerDidUpdateState.state=%ld",central.state);
    switch (central.state) {
        case CBManagerStatePoweredOn:
            NSLog(@"CBManagerStatePoweredOn");
            // 蓝牙开启监听
            _isEnable = true;
            if(_eventSink){
                _eventSink([self sendEvent:BLUETOOTHON]);
            }
            // 这个参数设置了，扫描到的设备会继续被扫描，如果不需要可以设置为nil
            //            NSMutableDictionary* option = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],CBCentralManagerScanOptionAllowDuplicatesKey, nil];
            // 开始扫描蓝牙设备
            //            [_centralManager scanForPeripheralsWithServices:nil options:nil]
            break;
        case CBManagerStatePoweredOff:
            NSLog(@"CBManagerStatePoweredOff");
            // 蓝牙关闭监听
            _isEnable = false;
            if(_peripheral){
                NSLog(@"iOS 蓝牙关闭，外设不为空，发送断开蓝牙通知");
                _state = 0;
                _isConnected = false;
                _eventSink([self sendEvent:BLUETOOTHOFF]);
            }else{
                NSLog(@"ISO 外设为空");
            }
            break;
        case CBManagerStateUnknown:
            NSLog(@"CBManagerStateUnknown");
            break;
        case CBManagerStateResetting:
            NSLog(@"CBManagerStateResetting");
            break;
        case CBManagerStateUnsupported:
            NSLog(@"CBManagerStateUnsupported");
            // 蓝牙不支持监听
            _isSupport = false;
            break;
        case CBManagerStateUnauthorized:
            NSLog(@"CBManagerStateUnauthorized");
            break;
        default:
            break;
    }
}
// 扫描到设备的监听
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    NSLog(@"扫描到设备：%@",peripheral.name);
    NSString * name  =[advertisementData objectForKey:@"kCBAdvDataLocalName"] ;
    NSLog(@"搜索到了设备LocalName:%@",name);
    NSLog(@"json:%@",advertisementData);
    // tempAddress 不为空 说明是重连外设，找到uuid相同的外设直接连接
    if(tempAddress){
        if([peripheral.identifier.UUIDString isEqualToString:tempAddress]){
            // 停止扫描外设
            [_centralManager stopScan];
            //连接前先调用断开之前外设的方法
            [_centralManager cancelPeripheralConnection:peripheral];
            //开始连接外设
            [_centralManager connectPeripheral:peripheral options:nil];
            _peripheral = peripheral;
            _state = 1;
            // 连接之后清空重连的暂存地址
            tempAddress = nil;
        }
        return;
    }
    if([advertisementData objectForKey:@"kCBAdvDataManufacturerData"]){
        NSString * str  =[[NSString alloc] initWithData:[advertisementData objectForKey:@"kCBAdvDataManufacturerData"] encoding:NSUTF8StringEncoding];
        NSLog(@"搜索到了设备UUID:%@",str);
    }
    // 处理发现的蓝牙设备
    [self addBlutoothDevice:peripheral advertisementData:advertisementData RSSI:RSSI];
}


//蓝牙连接失败回调
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(nonnull CBPeripheral *)peripheral error:(nullable NSError *)error{
    NSLog(@"连接失败：%@",[error localizedDescription]);
    _state = 0;
    _isConnected = false;
    _eventSink([self sendEvent:STATE_DISCONNECTED]);
}

// 蓝牙连接成功回调
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(nonnull CBPeripheral *)peripheral{
    // 外设委托
    [_peripheral setDelegate:self];
    // 发现服务
    NSLog(@"开始扫描服务");
    _writeCharacteristic = nil;
    _readCharacteristic = nil;
    [_peripheral discoverServices:nil];
    _state = 2;
    _isConnected = true;
    _eventSink([self sendEvent:STATE_CONNECTED]);
}
// 蓝牙连接断开回调
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error{
    _state = 0;
    _isConnected = false;
    _eventSink([self sendEvent:STATE_DISCONNECTED]);
}


// 发现蓝牙设备的服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    if(error){
        NSLog(@"error discover service:%@",[error localizedDescription]);
        return;
    }
    if(serviceAndCharacteristicsArray != nil){
        serviceAndCharacteristicsArray = [[NSMutableDictionary alloc]init];
        SAndCArray = [[NSMutableDictionary alloc]init];
    }
    for (CBService* service in peripheral.services) {
        NSLog(@"扫描到的服务的UUID:%@",service.UUID.UUIDString);
        NSLog(@"开始发现服务下的特征值");
        [_peripheral discoverCharacteristics:nil forService:service];
    }
}
// 找到特征值回调
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    
    NSString * serviceUUID = service.UUID.UUIDString;
    //如果字典不为空
    if(serviceAndCharacteristicsArray != nil){
        NSMutableArray * temp =[serviceAndCharacteristicsArray objectForKey:serviceUUID];
        // 且对于服务的键的值不为空，说明已经添加过这个服务，不再添加到字典
        if(temp != nil){
            return;
        }
    }
    NSMutableArray * cs = [[NSMutableArray alloc]init];
    NSMutableArray * css = [[NSMutableArray alloc]init];
    for (CBCharacteristic* characteristic in service.characteristics) {
        NSMutableDictionary * p = [[NSMutableDictionary alloc]init];
        [p setObject:characteristic.UUID.UUIDString forKey:@"uuid"];
        NSString * properties = @"";
        if(characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse){
            if(_writeCharacteristic == nil){
                _writeCharacteristic = characteristic;
            }
            properties = [properties stringByAppendingFormat:@"%@",@"Write Without Response "];
        }
        if(characteristic.properties & CBCharacteristicPropertyNotify){
            if(_readCharacteristic == nil){
                _readCharacteristic = characteristic;
            }
            properties = [properties stringByAppendingFormat:@"%@",@"Notify "];
        }
        if(characteristic.properties & CBCharacteristicPropertyWrite){
            if(_writeCharacteristic == nil){
                _writeCharacteristic = characteristic;
            }
            properties = [properties stringByAppendingFormat:@"%@",@"Write "];
        }
        if(characteristic.properties & CBCharacteristicPropertyRead){
            properties = [properties stringByAppendingFormat:@"%@",@"Read "];
        }
        if(properties.length==0){
            properties = @"None";
        }
        [p setObject:properties forKey:@"type"];
        [cs addObject:p];
        [css addObject:characteristic];
    }
    if(serviceAndCharacteristicsArray == nil){
        serviceAndCharacteristicsArray = [[NSMutableDictionary alloc]init];
        SAndCArray = [[NSMutableDictionary alloc]init];
    }
    if(_readCharacteristic != nil){
        [_peripheral setNotifyValue:YES forCharacteristic:_readCharacteristic];
    }
    [serviceAndCharacteristicsArray setObject:cs forKey:serviceUUID];
    [SAndCArray setObject:css forKey:serviceUUID];
    NSDate * jsondata = [NSJSONSerialization dataWithJSONObject:serviceAndCharacteristicsArray options:NSJSONWritingPrettyPrinted error:nil];
    NSString * jsonString = [[NSString alloc]initWithData:jsondata encoding:NSUTF8StringEncoding];
    NSLog(@"string:%@",jsonString);
    NSDictionary * param3 = [self sendEvent:SERVICE_CHARACTERISTICS data:jsonString];
    NSLog(@"string:%@",param3.description);
    // 通过eventchannel 发生数据给上层flutter
    _eventSink(param3);
}
// 写数据失败回调
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    NSLog(@"写数据失败，原因：%@",[error localizedDescription]);
}
// 监听特征值变化（蓝牙设备发送数据）
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if(error){
        NSLog(@"error didUpdateNotificationStateForCharacteristic:%@",[error localizedDescription]);
        return;
    }
    unsigned char data1[characteristic.value.length];
    [characteristic.value getBytes:&data1 length:characteristic.value.length];
    NSString * tempStr = [NSString stringWithFormat:@"%s",data1];
    NSLog(@"tempStr = %@",tempStr);
    NSString* data = [characteristic.value description];
    //    NSLog(characteristic.value);
    NSLog(@"接收到的数据时：%@",data);
    for (int i=0; i<[characteristic.value length]; i++) {
        NSLog(@"数据：%d = %d",i,data1[i]);
    }
    
    
}
//
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if(error){
        NSLog(@"error didUpdateValueForCharacteristic:%@",[error localizedDescription]);
        return;
    }
    unsigned char data1[characteristic.value.length];
    NSLog(@"发送数据的charact的uuid是：%@",characteristic.UUID.UUIDString);
    [characteristic.value getBytes:&data1 length:characteristic.value.length];
    NSString* data = [characteristic.value description];
    //    NSLog(characteristic.value);
    NSLog(@"接收到的数据时222：%@",data);
    NSMutableArray * arr = [[NSMutableArray alloc]init];
    for (int i=0; i<[characteristic.value length]; i++) {
        [arr addObject:@(data1[i])];
        //        NSLog(@"数据222：%d = %d",i,data1[i]);
    }
    //    NSLog(@"ISO 发送的数据：%@",arr);
    _eventSink([self sendEvent:DATA_AVAILABLE data:arr]);
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSLog(@"handleMethodCall=======%@",call.method);
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    }else if([@"isSupport" isEqualToString:call.method]){
        return result([NSNumber numberWithBool:_isSupport?YES:NO]);
    }else if([@"setWriteCharactor" isEqualToString:call.method]){
        NSMutableDictionary* dic =  call.arguments;
        NSString* uuid =  [dic objectForKey:@"uuid"];
        for(NSString * serviceUUid in SAndCArray){
            NSArray * characs = [SAndCArray objectForKey:serviceUUid];
            for(CBCharacteristic* c in characs){
                if([c.UUID.UUIDString isEqualToString:uuid]){
                    _writeCharacteristic = c;
                    break;
                }
            }
        }
    }else if([@"setNotifyCharactor" isEqualToString:call.method]){
        NSMutableDictionary* dic =  call.arguments;
        NSString* uuid =  [dic objectForKey:@"uuid"];
        NSString* isNotify =  [dic objectForKey:@"isNotify"];
        NSLog(@"isNorify:%@",[isNotify isEqualToString:@"true"]?@"true":@"false");
        for(NSString * serviceUUid in SAndCArray){
            NSArray * characs = [SAndCArray objectForKey:serviceUUid];
            for(CBCharacteristic* c in characs){
                if([c.UUID.UUIDString isEqualToString:uuid]){
                    [_peripheral setNotifyValue:[isNotify isEqualToString:@"true"]?YES:NO forCharacteristic:c];
                    break;
                }
            }
        }
    } else if([@"isEnabled" isEqualToString:call.method]){
        return result([NSNumber numberWithBool:_isEnable?YES:NO]);
    }else if([@"startScanBluetooth" isEqualToString:call.method]){
        //停止之前的连接
        [_centralManager stopScan];
        [_centralManager scanForPeripheralsWithServices:nil options:nil];
        // 清空存储蓝牙设备的数组
        peripheralDataArray = [[NSMutableArray alloc]init];
        _eventSink([self sendEvent:START_SACN data:@"start scan ble"]);
        //baby.scanForPeripherals().begin().stop(10);
        return result([NSNumber numberWithBool:YES]);
    }else if([@"stopScanBluetooth" isEqualToString:call.method]){
        [_centralManager stopScan ];
        if(![_centralManager isScanning]){
            _eventSink([self sendEvent:STOP_SACN data:@"stop scan ble"]);
        }
    }else if([@"connect" isEqualToString:call.method]){
        NSMutableDictionary* dic =  call.arguments;
        NSString* address =  [dic objectForKey:@"address"];
        NSLog(@"address:%@",address);
        NSArray *peripherals = [peripheralDataArray valueForKey:@"peripheral"];
        if(peripherals.count<=0){
            NSLog(@"数组中没有数据");
            tempAddress = address;
            //扫描查找uuid和tempAddress（重连地址）一样的蓝牙设备，找到后直接连接。不设置超时时间
            [_centralManager stopScan];
            [_centralManager scanForPeripheralsWithServices:nil options:nil];
            return;
        }else{
            tempAddress = nil;
        }
        NSInteger temp = -1;
        for (CBPeripheral* peripheral in peripherals) {
            NSLog(@"ios 遍历数组，peripheral.name=%@",peripheral.name);
            NSLog(@"ios 遍历数组，peripheral.identifier=%@",peripheral.identifier.UUIDString);
            if([peripheral.identifier.UUIDString isEqualToString: address]){
                NSLog(@"ios 在数组中找到了对应的peripheral=================");
                [_centralManager stopScan];
                [_centralManager connectPeripheral:peripheral options:nil];
                _peripheral = peripheral;
                _state = 1;
                temp = 1;
                break;
            }
        }
        if(temp==-1){
            NSLog(@"没有找到对应uuid的蓝牙设备");
            _eventSink([self sendEvent:BLUETOOTH_NOT_FOUND data:@"the bluetooth device you want to connect was not found"]);
        }
        
    }else if([@"disconnect" isEqualToString:call.method]){
        [_centralManager stopScan];
        tempAddress = nil;
        if(_peripheral){
            if(_isConnected){
                [_centralManager cancelPeripheralConnection:_peripheral];
            }
        }
    }else if([@"status" isEqualToString:call.method]){
        return result([NSNumber numberWithBool:_state]);
    }else if([@"isConnect" isEqualToString:call.method]){
        return result([NSNumber numberWithBool:_isConnected?YES:NO]);
    }else if([@"auth" isEqualToString:call.method]){
        // 发送数据给蓝牙外设
        NSMutableDictionary* dic =  call.arguments;
        NSString* authCode =  [dic objectForKey:@"authCode"];
        NSLog(@"authCode:%@",authCode);
        [_peripheral writeValue:[authCode dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:_writeCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }else if([@"broadcastData" isEqualToString:call.method]){
        //发送ASCALL码数据
        NSMutableDictionary* dic =  call.arguments;
        NSString* command =  [dic objectForKey:@"command"];
        NSLog(@"command:%@",command);
        NSLog(@"String command:%@",[command dataUsingEncoding:NSUTF8StringEncoding]);
        NSInteger temp = 0;
        [_peripheral writeValue:[command dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:_writeCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }else if([@"broadcastOData" isEqualToString:call.method]){
        //发送二进制数据
        NSMutableDictionary* dic =  call.arguments;
        NSString* command =  [dic objectForKey:@"command"];
        NSData* data = [command dataUsingEncoding:NSUnicodeStringEncoding];
        NSArray * json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        NSInteger len = [json count];
        NSMutableData *datas = [[NSMutableData alloc] init];
        for(int i= 0;i<len;i++){
            // *** 这个地方直接使用json[i] 转int类型值，不是十进制数据，需要专门转string后再转int才能是正确的十进制数据，如果有其他办法请修改；***
            //获取数据转字符串
            NSString * str = [NSString stringWithFormat:@"%@",json[i]];
            NSLog(@"testStr-->%@",str);
            // 字符串转int
            int intValue = [str intValue];
            NSLog(@"%d",intValue);
            NSData * byteData = [[NSData alloc] init];
            // 将十进制数据放入byte
            Byte b = (Byte) intValue;
            Byte bs[1] = {b};
            // 放入到NSData
            byteData = [NSData dataWithBytes:bs length:sizeof(b)];
            NSLog(@"data-->%@",byteData);
            // 放入NSData数组里面
            [datas appendData:byteData];
        }
        NSLog(@"%ld",datas.length);
        [_peripheral writeValue:datas forCharacteristic:_writeCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }else if([@"isCommanding" isEqualToString:call.method]){
        //是否正在发送指令，不支持iso，支持安卓
        return result([NSNumber numberWithBool:NO]);
    }else {
        result(FlutterMethodNotImplemented);
    }
}
// 扫描到的蓝牙处理
-(void)addBlutoothDevice:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
    // 剔除名字为空的
    //    if(!peripheral.name){
    //        NSLog(@"1111111111111111");
    //        return;
    //    }
    // 剔除信号弱的
    if([RSSI intValue]<= -90){
        NSLog(@"222222222222222");
        return;
    }
    NSArray *peripherals = [peripheralDataArray valueForKey:@"peripheral"];
    if(![peripherals containsObject:peripheral]) {
        NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:peripherals.count inSection:0];
        [indexPaths addObject:indexPath];
        
        NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
        [item setValue:peripheral forKey:@"peripheral"];
        [item setValue:RSSI forKey:@"RSSI"];
        [item setValue:advertisementData forKey:@"advertisementData"];
        [peripheralDataArray addObject:item];
    }else{
        // 已经发现的不再添加进去
        return;
    }
    // 处理扫描到的蓝牙数据，发送给我上层
    NSMutableArray * temp = [[NSMutableArray alloc]init];
    for (NSMutableDictionary * peripheral in peripheralDataArray) {
        CBPeripheral * p = [peripheral objectForKey:@"peripheral"];
        NSString * name = p.name;
        if(p.name.length<=0){
            name = @"NullName";
        }
        // value -> key 结构
        NSDictionary * dict =[NSDictionary dictionaryWithObjectsAndKeys:name,@"name",
                              [peripheral objectForKey:@"RSSI"],@"rssi",p.identifier.UUIDString , @"address",nil];
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
        NSLog(@"json字典里面的内容为--》%@", jsonData );
        NSString* text =[[NSString alloc] initWithData:jsonData
                                              encoding:NSUTF8StringEncoding];
        [temp addObject:text];
    }
    NSDate * jsondata = [NSJSONSerialization dataWithJSONObject:temp options:kNilOptions error:nil];
    NSString * jsonString = [[NSString alloc]initWithData:jsondata encoding:NSUTF8StringEncoding];
    NSString *string = [temp description];
    NSLog(@"string:%@",string);
    NSDictionary * param3 = [self sendEvent:FOUND_DEVICES data:jsonString];
    NSLog(@"string:%@",param3.description);
    // 通过eventchannel 发生数据给上层flutter
    _eventSink(param3);
}

// 发送数据封装
-(NSDictionary *)sendEvent:(NSInteger) code data:(id) data{
    NSDictionary * param = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:code],@"code",data,@"data", nil];
    return param;
}

// 发送数据封装
-(NSDictionary *)sendEvent:(NSInteger) code{
    NSDictionary * param = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:code],@"code", nil];
    return param;
}

@end
