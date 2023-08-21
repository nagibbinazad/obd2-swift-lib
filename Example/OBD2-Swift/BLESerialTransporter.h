//
//  Copyright (c) Dr. Michael Lauer Information Technology. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString* const BLESerialTransporterDidUpdateSignalStrength;

typedef void(^BLESerialTransporterConnectionBlock)(NSInputStream* _Nullable inputStream, NSOutputStream* _Nullable outputStream);

@interface BLESerialTransporter : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property(strong,nonatomic,readonly) NSNumber* signalStrength;

+(instancetype)transporterWithIdentifier:(nullable NSUUID*)identifier serviceUUIDs:(NSArray<CBUUID*>*)serviceUUIDs;
-(void)connectWithBlock:(BLESerialTransporterConnectionBlock)block;
-(void)disconnect;

-(void)startUpdatingSignalStrengthWithInterval:(NSTimeInterval)interval;
-(void)stopUpdatingSignalStrength;

@end

NS_ASSUME_NONNULL_END

