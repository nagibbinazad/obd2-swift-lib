//
//  Copyright (c) Dr. Michael Lauer Information Technology. All rights reserved.
//

#import "BLESerialTransporter.h"
#import "OBD2-Swift.h"

NSString* const LTBTLESerialTransporterDidUpdateSignalStrength = @"LTBTLESerialTransporterDidUpdateSignalStrength";

@implementation BLESerialTransporter
{
    CBCentralManager* _manager;
    NSUUID* _identifier;
    NSArray<CBUUID*>* _serviceUUIDs;
    CBPeripheral* _adapter;
    CBCharacteristic* _reader;
    CBCharacteristic* _writer;
    
    NSMutableArray<CBPeripheral*>* _possibleAdapters;
    
    dispatch_queue_t _dispatchQueue;
    
    BLESerialTransporterConnectionBlock _connectionBlock;
    BluetoothInputStream* _inputStream;
    BluetoothOutputStream* _outputStream;
    
    NSNumber* _signalStrength;
    NSTimer* _signalStrengthUpdateTimer;
}

#pragma mark -
#pragma mark Lifecycle

+(instancetype)transporterWithIdentifier:(NSUUID*)identifier serviceUUIDs:(NSArray<CBUUID*>*)serviceUUIDs
{
    return [[self alloc] initWithIdentifier:identifier serviceUUIDs:serviceUUIDs];
}

-(instancetype)initWithIdentifier:(NSUUID*)identifier serviceUUIDs:(NSArray<CBUUID*>*)serviceUUIDs
{
    if ( ! ( self = [super init] ) )
    {
        return nil;
    }
    
    _identifier = identifier;
    _serviceUUIDs = serviceUUIDs;
    
    _dispatchQueue = dispatch_queue_create( [NSStringFromClass(self.class) UTF8String], DISPATCH_QUEUE_SERIAL );
    _possibleAdapters = [NSMutableArray array];
    
    NSLog( @"Created w/ identifier %@, services %@", _identifier, _serviceUUIDs );
    
    return self;
}

-(void)dealloc
{
    [self disconnect];
}

#pragma mark -
#pragma mark API

-(void)connectWithBlock:(BLESerialTransporterConnectionBlock)block
{
    _connectionBlock = block;
    
    _manager = [[CBCentralManager alloc] initWithDelegate:self queue:_dispatchQueue options:nil];
}

-(void)disconnect
{
    [self stopUpdatingSignalStrength];
    
    [_inputStream close];
    [_outputStream close];
    
    if ( _adapter )
    {
        [_manager cancelPeripheralConnection:_adapter];
    }
    
    [_possibleAdapters enumerateObjectsUsingBlock:^(CBPeripheral * _Nonnull peripheral, NSUInteger idx, BOOL * _Nonnull stop) {
        [self->_manager cancelPeripheralConnection:peripheral];
    }];
}

-(void)startUpdatingSignalStrengthWithInterval:(NSTimeInterval)interval
{
    [self stopUpdatingSignalStrength];
    
    _signalStrengthUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(onSignalStrengthUpdateTimerFired:) userInfo:nil repeats:YES];
}

-(void)stopUpdatingSignalStrength
{
    [_signalStrengthUpdateTimer invalidate];
    _signalStrengthUpdateTimer = nil;
}

#pragma mark -
#pragma mark NSTimer

-(void)onSignalStrengthUpdateTimerFired:(NSTimer*)timer
{
    if ( _adapter.state != CBPeripheralStateConnected )
    {
        return;
    }
    
    [_adapter readRSSI];
}

#pragma mark -
#pragma mark <CBCentralManagerDelegate>

-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if ( central.state != CBManagerStatePoweredOn )
    {
        return;
    }
    NSArray<CBPeripheral*>* peripherals = [_manager retrieveConnectedPeripheralsWithServices:_serviceUUIDs];
    if ( peripherals.count )
    {
        NSLog( @"CONNECTED (already) %@", _adapter );
        if ( _adapter.state == CBPeripheralStateConnected )
        {
            _adapter = peripherals.firstObject;
            _adapter.delegate = self;
            [self peripheral:_adapter didDiscoverServices:nil];
        }
        else
        {
            [_possibleAdapters addObject:peripherals.firstObject];
            [self centralManager:central didDiscoverPeripheral:peripherals.firstObject advertisementData:@{} RSSI:@127];
        }
        return;
    }
    
    if ( _identifier )
    {
        peripherals = [_manager retrievePeripheralsWithIdentifiers:@[_identifier]];
    }
    if ( !peripherals.count )
    {
        // some devices are not advertising the service ID, hence we need to scan for all services
        [_manager scanForPeripheralsWithServices:nil options:nil];
        return;
    }
    
    _adapter = peripherals.firstObject;
    _adapter.delegate = self;
    NSLog( @"DISCOVER (cached) %@", _adapter );
    [_manager connectPeripheral:_adapter options:nil];
}

-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral*)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    if ( _adapter )
    {
        NSLog( @"[IGNORING] DISCOVER %@ (RSSI=%@) w/ advertisement %@", peripheral, RSSI, advertisementData );
        return;
    }
    
    NSLog( @"DISCOVER %@ (RSSI=%@) w/ advertisement %@", peripheral, RSSI, advertisementData );
    [_possibleAdapters addObject:peripheral];
    peripheral.delegate = self;
    [_manager connectPeripheral:peripheral options:nil];
}

-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog( @"CONNECT %@", peripheral );
    [peripheral discoverServices:_serviceUUIDs];
}

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog( @"Failed to connect %@: %@", peripheral, error );
}

-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog( @"Did disconnect %@: %@", peripheral, error );
    if ( peripheral == _adapter )
    {
        [_inputStream close];
        [_outputStream close];
    }
}

#pragma mark -
#pragma mark <CBPeripheralDelegate>

-(void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error
{
    if ( error )
    {
        NSLog( @"Could not read signal strength for %@: %@", peripheral, error );
        return;
    }
    
    _signalStrength = RSSI;
    [[NSNotificationCenter defaultCenter] postNotificationName:LTBTLESerialTransporterDidUpdateSignalStrength object:self];
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if ( _adapter )
    {
        NSLog( @"[IGNORING] SERVICES %@: %@", peripheral, peripheral.services );
        return;
    }
    
    if ( error )
    {
        NSLog( @"Could not discover services: %@", error );
        return;
    }
    
    if ( !peripheral.services.count )
    {
        NSLog( @"Peripheral does not offer requested services" );
    
        [_manager cancelPeripheralConnection:peripheral];
        [_possibleAdapters removeObject:peripheral];
        return;
    }
    
    _adapter = peripheral;
    _adapter.delegate = self;
    if ( _manager.isScanning )
    {
        [_manager stopScan];
    }
    
    CBService* atCommChannel = peripheral.services.firstObject;
    [peripheral discoverCharacteristics:nil forService:atCommChannel];
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    for ( CBCharacteristic* characteristic in service.characteristics )
    {
        if ( characteristic.properties & CBCharacteristicPropertyNotify )
        {
            NSLog( @"Did see notify characteristic" );
            _reader = characteristic;
            
            //[peripheral readValueForCharacteristic:characteristic];
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        
        if ( characteristic.properties & CBCharacteristicPropertyWrite )
        {
            NSLog( @"Did see write characteristic" );
            _writer = characteristic;
        }
    }
    
    if ( _reader && _writer )
    {
        [self connectionAttemptSucceeded];
    }
    else
    {
        [self connectionAttemptFailed];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
#ifdef DEBUG_THIS_FILE
    NSString* debugString = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    NSString* replacedWhitespace = [[debugString stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"] stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    NSLog( @"%@ >>> %@", peripheral, replacedWhitespace );
#endif
    
    if ( error )
    {
        NSLog( @"Could not update value for characteristic %@: %@", characteristic, error );
        return;
    }
    
    [_inputStream characteristicDidUpdateValue];
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ( error )
    {
        NSLog( @"Could not write to characteristic %@: %@", characteristic, error );
        return;
    }
    
    [_outputStream characteristicDidWriteValue];
}

#pragma mark -
#pragma mark Helpers

-(void)connectionAttemptSucceeded
{
    _inputStream = [[BluetoothInputStream alloc] initWithCharacteristic:_reader];
    _outputStream = [[BluetoothOutputStream alloc] initWithCharacteristic:_writer];
    _connectionBlock( _inputStream, _outputStream );
    _connectionBlock = nil;
}

-(void)connectionAttemptFailed
{
    _connectionBlock( nil, nil );
    _connectionBlock = nil;
}

@end
