//
//  BluetoothInputStream.swift
//  OBD2-Swift
//
//  Created by Nagib Bin Azad on 11/8/23.
//

import Foundation
import CoreBluetooth

public class BluetoothInputStream: InputStream {
    
    private var _delegate: StreamDelegate?
    private var _status: Stream.Status!
    private var _buffer: NSMutableData!
    private var _characteristic: CBCharacteristic
    private weak var _peripheral: CBPeripheral?

    @objc public init(characteristic: CBCharacteristic) {
        self._characteristic = characteristic
        super.init(data: Data()) // Initialize with an empty Data object
        self._delegate = self
        self._status = .notOpen
        self._peripheral = characteristic.service?.peripheral
    }
    
    //MARK: API
    @objc public func characteristicDidUpdateValue() -> Void {
        if let value = _characteristic.value {
            _buffer.append(value)
            self.delegate?.stream?(self, handle: .hasBytesAvailable)
        }
    }
    
    //MARK: Stream overrides
    public override var delegate: StreamDelegate? {
        set(delegate) {
            _delegate = delegate ?? self
        }
        get {
            return _delegate
        }
    }
    public override func open() {
        _status = .opening
        _buffer = NSMutableData()
        _status = .open
        self.delegate?.stream?(self, handle: .openCompleted)
    }
    public override func close() {
        _status = .closed
        self.delegate?.stream?(self, handle: .endEncountered)
    }
    public override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        // nothing to do here
    }
    public override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        // nothing to do here
    }
    public override func property(forKey key: Stream.PropertyKey) -> Any? {
        return nil
    }
    public override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool {
        return false
    }
    
    //MARK: InputStream overrides
    public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        if _status != .open {
            return -1
        }
        let maxBytesToRead = min(len, _buffer.length)
        memcpy( buffer, _buffer.bytes, maxBytesToRead );

        if  len < _buffer.length {
            let remainingBuffer = NSData(bytes: _buffer.bytes + maxBytesToRead, length: _buffer.length - maxBytesToRead)
            _buffer.setData(remainingBuffer as Data)
        }else {
            _buffer = NSMutableData();
        }
        
        return maxBytesToRead
    }
    
    public override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
    public override var hasBytesAvailable: Bool {
        if _status != .open {
            return false
        }
        return _buffer.length > 0
    }
}

extension BluetoothInputStream: StreamDelegate {
    
}
