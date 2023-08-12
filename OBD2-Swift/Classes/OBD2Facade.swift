//
//  OBD2Facade.swift
//  OBD2Swift
//
//  Created by Max Vitruk on 24/05/2017.
//  Copyright © 2017 Lemberg. All rights reserved.
//

import Foundation
import CoreBluetooth


protocol ScanDelegate {
    func didReceive()
}

open class OBD2 {
    
    public typealias CallBack = (Bool, Error?) -> ()
    
    private var scanner : Scanner
    
    public var stateChanged: StateChangeCallback? {
        didSet {
            scanner.stateChanged = stateChanged
        }
    }

    public init(host : String, port : Int){
        var readStream: InputStream?
        var writeStream: OutputStream?
        Stream.getStreamsToHost(withName: host, port: port, inputStream: &readStream, outputStream: &writeStream)
        guard let inputStream = readStream else { fatalError("Read stream not created") }
        guard let outputStream = writeStream else { fatalError("Write stream not created") }
        self.scanner = Scanner(inputStream: inputStream, outputStream: outputStream)
    }
    
    public init(reader: CBCharacteristic, writer: CBCharacteristic) {
        self.scanner = Scanner(inputStream: BluetoothInputStream(characteristic: reader), outputStream: BluetoothOutputStream(characteristic: writer))
    }
    
    var logger : Any?
    var cache : Any?
    
    public func connect(_ block : @escaping CallBack){
        scanner.startScan { (success, error) in
            block(success, error)
        }
    }
    
    
    /// Disconnect from OBD
    public func disconnect() {
        scanner.disconnect()
    }
    
    
    /// Stop scaning but leave active connection to obd
    public func stopScan() {
        scanner.cancelScan()
    }
    
    
    /// Pause all requests to OBD
    open func pauseScan() {
        scanner.pauseScan()
    }
    
    /// Resume requests to OBD
    open func resumeScan() {
        scanner.resumeScan()
    }
    
    /// Send request to OBD once
    ///
    /// - Parameters:
    ///   - command: command to send
    ///   - notifyObservers: should be result will be send to command observers. Default is true
    ///   - block: result of command execution
    public func request<T: CommandType>(command: T, notifyObservers: Bool = true, block: @escaping (_ descriptor: T.Descriptor?)->()){
        let dataRequest = command.dataRequest
        
        scanner.request(command: dataRequest, response: { (response) in
            let described = T.Descriptor(describe: response)
            block(described)
            if notifyObservers {
                self.dispatchToObserver(command: command, with: response)
            }
        })
    }
    
    
    /// Start send this command to OBD repetedly
    /// Result can be observed by registered observer
    ///
    /// - Parameter command: Command to execute
    public func request<T: CommandType>(repeat command: T) {
        let dataRequest = command.dataRequest
        scanner.startRepeatCommand(command: dataRequest) { (response) in
            self.dispatchToObserver(command: command, with: response)
        }
    }
    
    
    /// Stop send this command to OBD repetedly
    ///
    /// - Parameter command: Command to remover from repeat queue
    public func stop<T: CommandType>(repeat command: T) {
        let dataRequest = command.dataRequest
        scanner.stopRepeatCommand(command: dataRequest)
    }
    
    
    /// Check are this command alredy executing repeatedly
    ///
    /// - Parameter command: command to check
    /// - Returns: return true if command executing repetedly
    public func isRepeating<T: CommandType>(repeat command: T) -> Bool {
        let dataRequest = command.dataRequest
        return scanner.isRepeating(command: dataRequest)
    }
    
    private func dispatchToObserver<T : CommandType>(command : T, with response : Response){
        ObserverQueue.shared.dispatch(command: command, response: response)
    }
}


