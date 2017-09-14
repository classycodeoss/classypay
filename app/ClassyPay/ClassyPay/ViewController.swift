//
//  Copyright © 2017 Classy Code GmbH. All rights reserved.
//
import UIKit
import UserNotifications
import CoreLocation

class ViewController: UIViewController {

    @IBOutlet weak var payView: UIView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var terminalLabel: UILabel!
    @IBOutlet weak var payButton: UIButton!
    
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        payView.isHidden = true
        AppDelegate.instance.beaconManager.delegate = self
        
        if CLLocationManager.authorizationStatus() != .authorizedAlways {
            locationManager.requestAlwaysAuthorization()
        }

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [ .sound, .alert ]) { (granted, error) in
            print("Granted: \(granted)")
        }
    }
    
    @IBAction func onPayButtonTouched(_ sender: Any) {
        payView.isHidden = true
    }
}

extension ViewController: BeaconManagerDelegate {
    func beaconManagerMonitoringIsEnabled(enabled: Bool) {
    }
    
    func beaconManagerDidDetectCloseProximity(to beacon: CLBeaconRegion) {
        terminalLabel.text = "Terminal \(beacon.minor!)"
        amountLabel.text = "\(beacon.major!).00 CHF"
        payView.isHidden = false
    }
}
