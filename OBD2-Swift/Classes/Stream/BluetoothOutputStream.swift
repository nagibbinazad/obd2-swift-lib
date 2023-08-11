//
//  BluetoothOutputStream.swift
//  OBD2-Swift
//
//  Created by Nagib Bin Azad on 12/8/23.
//

import Foundation
import CoreBluetooth

class BluetoothOutputStream: OutputStream {
    
    private var _delegate: StreamDelegate?
    private var _status: Stream.Status!
    private var _characteristic: CBCharacteristic
    
    init(characteristic: CBCharacteristic) {
        self._characteristic = characteristic
        super.init(toMemory: ())
        self._delegate = self
        self._status = .notOpen
    }
    
    //MARK: API
    func characteristicDidWriteValue() -> Void {
        self.delegate?.stream?(self, handle: .hasSpaceAvailable)
    }
    
    //MARK: Stream overrides
    override var delegate: StreamDelegate? {
        set(delegate) {
            _delegate = delegate ?? self
        }
        get {
            return _delegate
        }
    }
    override func open() {
        _status = .opening
        _status = .open
        self.delegate?.stream?(self, handle: .openCompleted)
        self.delegate?.stream?(self, handle: .hasSpaceAvailable)
    }
    override func close() {
        _status = .closed
        self.delegate?.stream?(self, handle: .endEncountered)
    }
    override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoopMode) {
        // nothing to do here
    }
    override func remove(from aRunLoop: RunLoop, forMode mode: RunLoopMode) {
        // nothing to do here
    }
    override func property(forKey key: Stream.PropertyKey) -> Any? {
        return nil
    }
    override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool {
        return false
    }
    
    //MARK: OutputStream overrides
    
    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        if _status != .open {
            return -1;
        }
        let maxWriteForCharacteristic = _characteristic.service?.peripheral?.maximumWriteValueLength(for: .withResponse) ?? 0
        let lengthToWrite = min( len, maxWriteForCharacteristic );
        let value = Data(bytes: buffer, count: lengthToWrite)
        _characteristic.service?.peripheral?.writeValue(value, for: _characteristic, type: .withResponse)
        return lengthToWrite
    }
    
    override var hasSpaceAvailable: Bool {
        if _status != .open {
            return false
        }
        return true
    }
}

extension BluetoothOutputStream: StreamDelegate {
    
}
