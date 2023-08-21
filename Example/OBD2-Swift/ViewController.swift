//
//  ViewController.swift
//  OBD2-Swift-lib-example
//
//  Created by Max Vitruk on 25/04/2017.
//  Copyright © 2017 Lemberg. All rights reserved.
//

import UIKit
import OBD2

class ViewController: UIViewController {
    static var host = "192.168.0.103"
    static var port = 35000
    
    //var scanTool = ELM327(host: host , port: port)
    var obd = OBD2(host: host, port: port)
    
    private var _transporter: BLESerialTransporter!
    private var _serviceUUIDS: [CBUUID] = [CBUUID]()
    
    @IBOutlet weak var dtcButton: UIButton!
    @IBOutlet weak var speedButton: UIButton!
    @IBOutlet weak var vinButton: UIButton!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    
    @IBOutlet weak var statusLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        
        updateUI(connected: false)
        
        
        
    }
    
    func setupOBD2() -> Void {
        
        let observer = Observer<Command.Mode01>()
        
        observer.observe(command: .pid(number: 12)) { (descriptor) in
            let respStr = descriptor?.shortDescription
            print("Observer : \(String(describing: respStr))")
        }
        
        ObserverQueue.shared.register(observer: observer)
        
        obd.stateChanged = { (state) in
            
            OperationQueue.main.addOperation { [weak self] in
                self?.onOBD(change: state)
            }
        }
    }
    
    func onOBD(change state:ScanState) {
        switch state {
        case .none:
            indicator.stopAnimating()
            statusLabel.text = "Not Connected"
            updateUI(connected: false)
            break
        case .connected:
            indicator.stopAnimating()
            statusLabel.text = "Connected"
            updateUI(connected: true)
            break
        case .openingConnection:
            connectButton.isHidden = true
            indicator.startAnimating()
            statusLabel.text = "Opening connection"
            break
        case .initializing:
            statusLabel.text = "Initializing"
            break
        }
    }
    
    func updateUI(connected: Bool) {
        dtcButton.isEnabled = connected
        speedButton.isEnabled = connected
        vinButton.isEnabled = connected
        connectButton.isHidden = connected
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    @IBAction func connect( _ sender : UIButton){
        //obd.requestTroubleCodes()
        obd.connect { [weak self] (success, error) in
            OperationQueue.main.addOperation({
                if let error = error {
                    print("OBD connection failed with \(error)")
                    self?.statusLabel.text = "Connection failed with error \(error)"
                    self?.updateUI(connected: false)
                }
            })
        }
    }
    
    @IBAction func bluetoothScan( _ sender : UIButton) {
        let uuids = ["FFF0", "FFE0", "BEEF" , "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2", "00001101-0000-1000-8000-00805F9B34FB"];
        uuids.forEach { uuid in
            _serviceUUIDS.append(CBUUID(string: uuid))
        }
        _transporter = BLESerialTransporter(identifier: nil, serviceUUIDs: _serviceUUIDS)
        _transporter.connect { inputStream, outputStream in
            if let inputStream = inputStream,
               let outputStream = outputStream {
                self.obd = OBD2(inputStream: inputStream, outputStream: outputStream)
            }
        }
//        let viewController = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(withIdentifier: "BluetoothScanViewControllerID") as! BluetoothScanViewController
//        viewController.modalPresentationStyle = .fullScreen
//        self.present(viewController, animated: true)
    }
    
    @IBAction func requestSpeed( _ sender : UIButton) {
        
        let command = Command.Mode01.pid(number: 12)
        if obd.isRepeating(repeat: command) {
            sender.setTitle("Start repeat speed", for: .normal)
            obd.stop(repeat: command)
        } else {
            sender.setTitle("Stop repeat", for: .normal)
            obd.request(repeat: command)
        }
    }
    
    @IBAction func request( _ sender : UIButton) {
        //obd.requestTroubleCodes()
        obd.request(command: Command.Mode03.troubleCode) { (descriptor) in
            let respStr = descriptor?.getTroubleCodes()
            print(respStr ?? "No value")
        }
    }
    
    @IBAction func pause( _ sender : UIButton) {
        obd.pauseScan()
    }
    
    @IBAction func resume( _ sender : UIButton) {
        obd.resumeScan()
    }
    
    @IBAction func requestVIN( _ sender : UIButton) {
        //obd.requestVIN()
        obd.request(command: Command.Mode09.vin) { (descriptor) in
            let respStr = descriptor?.VIN()
            print(respStr ?? "No value")
        }
        
        obd.request(command: Command.Custom.string("0902")) { (descr) in
            print("Response \(String(describing: descr?.getResponse()))")
        }
    }
    
}

