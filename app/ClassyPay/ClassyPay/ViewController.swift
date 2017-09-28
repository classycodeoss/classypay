//
//  Copyright © 2017 Classy Code GmbH. All rights reserved.
//
import UIKit
import UserNotifications
import CoreLocation

class ViewController: UIViewController {

    @IBOutlet weak var statusView: UITextView!
    
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        statusView.text = ""
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateStatusView()
        super.viewWillAppear(animated)
    }
    
    private func updateStatusView() {
        UNUserNotificationCenter.current().getNotificationSettings { (notificationSettings) in
            let notificationsOk = notificationSettings.authorizationStatus == .authorized
            let notificationsStatusOk = "Notifications permission: \(notificationsOk ? "OK" : "NOK")"
            let locationPermissionGranted = CLLocationManager.authorizationStatus() == .authorizedAlways
            let locationStatusText = "Location permission: \(locationPermissionGranted ? "OK" : "NOK")"
            DispatchQueue.main.async {
                self.statusView.text = notificationsStatusOk + "\n" + locationStatusText
            }
        }
    }
    
    @IBAction func onRequestPermissionButtonTouched(_ sender: Any) {
        if CLLocationManager.authorizationStatus() != .authorizedAlways {
            locationManager.requestAlwaysAuthorization()
        }
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [ .sound, .alert ]) { (granted, error) in
            self.updateStatusView()
        }
    }
}

extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.updateStatusView()
    }
}
