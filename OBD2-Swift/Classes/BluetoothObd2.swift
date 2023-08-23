//
//  BluetoothObd2.swift
//  OBD2-Swift
//
//  Created by Nagib Bin Azad on 20/8/23.
//

import Foundation
import CoreBluetooth

open class BluetoothObd2: OBD2 {
    
    public init(inputStream: InputStream, outputStream: OutputStream) {
        super.init(scanner: BleScanner(inputStream: inputStream, outputStream: outputStream))
    }
    
    @objc public func characteristicDidUpdateValue() -> Void {
        if let scanner = scanner as? BleScanner {
            scanner.characteristicDidUpdateValue()
        }
    }
    
    @objc public func characteristicDidWriteValue() -> Void {
        if let scanner = scanner as? BleScanner {
            scanner.characteristicDidWriteValue()
        }
    }
    
}
