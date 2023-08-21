//
//  BleScanner.swift
//  OBD2-Swift
//
//  Created by Nagib Bin Azad on 20/8/23.
//

import Foundation

class BleScanner: Scanner {
    
    @objc public func characteristicDidUpdateValue() -> Void {
        if let inputStream = inputStream as? BluetoothInputStream {
            inputStream.characteristicDidUpdateValue()
        }
    }
    
    @objc public func characteristicDidWriteValue() -> Void {
        if let outputStream = outputStream as? BluetoothOutputStream {
            outputStream.characteristicDidWriteValue()
        }
    }
    
}
