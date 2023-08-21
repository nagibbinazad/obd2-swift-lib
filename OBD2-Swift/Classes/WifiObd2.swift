//
//  WifiObd2.swift
//  OBD2-Swift
//
//  Created by Nagib Bin Azad on 20/8/23.
//

import Foundation

open class WifiObd2: OBD2 {
    
    public init(host : String, port : Int){
        var readStream: InputStream?
        var writeStream: OutputStream?
        Stream.getStreamsToHost(withName: host, port: port, inputStream: &readStream, outputStream: &writeStream)
        guard let inputStream = readStream else { fatalError("Read stream not created") }
        guard let outputStream = writeStream else { fatalError("Write stream not created") }
        super.init(scanner: Scanner(inputStream: inputStream, outputStream: outputStream))
    }
    
}
