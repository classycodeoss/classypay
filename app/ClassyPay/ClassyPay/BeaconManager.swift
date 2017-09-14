//
//  Copyright © 2017 Classy Code GmbH. All rights reserved.
//
import Foundation
import UIKit
import CoreLocation
import UserNotifications

protocol BeaconManagerDelegate {
    
    func beaconManagerMonitoringIsEnabled(enabled: Bool)
    func beaconManagerDidDetectCloseProximity(to beacon: CLBeaconRegion)
}

class BeaconManager: NSObject {
    static let uuid = UUID(uuidString: "33013f7f-cb46-4db6-b4be-542c310a81eb")!
    static let major: UInt16 = 204
    
    var delegate: BeaconManagerDelegate?
    let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = false
        
        let payAction = UNNotificationAction(identifier: "pay", title: "Pay", options: .foreground)
        let cancelAction = UNNotificationAction(identifier: "cancel", title: "Cancel", options: .foreground)
        
        let category = UNNotificationCategory(identifier: "payment", actions: [payAction, cancelAction],
                                              intentIdentifiers: [], options: [])
        let categories: Set = [ category ]
        UNUserNotificationCenter.current().setNotificationCategories(categories)
        UNUserNotificationCenter.current().delegate = self
    }
    
    fileprivate func processBeacon(beacon: CLBeaconRegion) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { (notificationSettings) in
            if notificationSettings.authorizationStatus == .authorized {
                let content = UNMutableNotificationContent()
                content.title = "ClassyPay"
                content.body = "Pay 4.50 CHF at Terminal \(beacon.minor!)"
                content.sound = UNNotificationSound.default()
                content.categoryIdentifier = "payment"
                content.userInfo["proximityUUID"] = beacon.proximityUUID.uuidString
                content.userInfo["minor"] = beacon.minor
                content.userInfo["major"] = beacon.major
                let notificationId = UUID().uuidString
                let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: nil)
                notificationCenter.add(request, withCompletionHandler: { (error) in
                    if let error = error {
                        print("Failed to schedule notification: \(error)")
                    } else {
                        print("Scheduled notification")
                    }
                })
            } else {
                print("Not authorized to show notification")
            }
        }
    }
    
    func isAuthorizerForBeaconMonitoring() -> Bool {
        return CLLocationManager.authorizationStatus() != .denied
    }
    
    func requestAuthorizationForBeaconMonitoring() {
        locationManager.requestAlwaysAuthorization()
    }
}

extension BeaconManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedAlways || status == .authorizedWhenInUse) {
            for monitoredRegion in locationManager.monitoredRegions {
                locationManager.stopMonitoring(for: monitoredRegion)
            }
            for minor: UInt16 in 1...20 {
                let beaconRegion = CLBeaconRegion(proximityUUID: BeaconManager.uuid, major: BeaconManager.major,
                                                  minor: minor, identifier: "region\(minor)")
                beaconRegion.notifyEntryStateOnDisplay = true
                locationManager.startMonitoring(for: beaconRegion)
            }
            print("Started monitoring for beacon regions")
            delegate?.beaconManagerMonitoringIsEnabled(enabled: true)
        } else {
            print("Not authorized for beacon region monitoring")
            delegate?.beaconManagerMonitoringIsEnabled(enabled: false)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion {
            print("ENTER beacon region: \(beaconRegion)")
            if UIApplication.shared.applicationState == .active {
                delegate?.beaconManagerDidDetectCloseProximity(to: beaconRegion)
            } else {
                processBeacon(beacon: beaconRegion)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion {
            print("EXIT beacon region: \(beaconRegion)")
        }
    }
}

extension BeaconManager: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let content = notification.request.content
        delegate?.beaconManagerDidDetectCloseProximity(to: content.userInfo["beaconRegion"] as! CLBeaconRegion)
    }
}
