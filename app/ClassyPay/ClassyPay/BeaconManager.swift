//
//  Copyright © 2017 Classy Code GmbH. All rights reserved.
//
import Foundation
import UIKit
import CoreLocation
import UserNotifications

class BeaconManager: NSObject {
    
    // iBeacon configuration: this must match your beacon setup
    let proximityUuid = UUID(uuidString: "33013f7f-cb46-4db6-b4be-542c310a81eb")!
    let major: UInt16 = 204
    let minorRange: CountableRange<UInt16> = 1..<21
    let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = false
        
        let initiateAction = UNNotificationAction(identifier: "initiate", title: "Pay", options: [])
        let cancelAction = UNNotificationAction(identifier: "cancel", title: "Cancel",
                                                options: [ .destructive ])
        let initiateCategory = UNNotificationCategory(identifier: "initiate", actions: [initiateAction, cancelAction],
                                                      intentIdentifiers: [], options: [])
        let categories: Set = [ initiateCategory ]
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
    
    fileprivate func notifyBeaconDetected(beacon: CLBeaconRegion) {
        AppDelegate.instance.backendService.lookupAction(proximityUuid: beacon.proximityUUID,
                                                         major: beacon.major!.intValue,
                                                         minor: beacon.minor!.intValue) { (error, actionUuid) in
            if let actionUuid = actionUuid {
                let notificationCenter = UNUserNotificationCenter.current()
                notificationCenter.getNotificationSettings { (notificationSettings) in
                    if notificationSettings.authorizationStatus == .authorized {
                        let content = UNMutableNotificationContent()
                        content.title = "Action requested"
                        content.body = "Perform action?"
                        content.sound = UNNotificationSound.default()
                        content.categoryIdentifier = "initiate"
                        content.userInfo["actionUuid"] = actionUuid
                        let request = UNNotificationRequest(identifier: actionUuid, content: content, trigger: nil)
                        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                    } else {
                        print("Not authorized to show notification")
                    }
                }
            } else if let error = error {
                print("Error occurred: \(error)")
            }
        }
    }
    
    func isAuthorizerForBeaconMonitoring() -> Bool {
        return CLLocationManager.authorizationStatus() != .denied
    }
}

extension BeaconManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedAlways || status == .authorizedWhenInUse) {
            for monitoredRegion in locationManager.monitoredRegions {
                locationManager.stopMonitoring(for: monitoredRegion)
            }
            
            for minor in minorRange {
                let beaconRegion = CLBeaconRegion(proximityUUID: proximityUuid, major: major,
                                                  minor: minor, identifier: "region\(minor)")
                beaconRegion.notifyEntryStateOnDisplay = true
                locationManager.startMonitoring(for: beaconRegion)
                print("Subscribing to proximityUUID: \(proximityUuid) major: \(major) minor: \(minor)")
            }
            print("Started monitoring for beacon regions")
        } else {
            print("Not authorized for beacon region monitoring")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion {
            print("ENTER beacon region: \(beaconRegion)")
            self.notifyBeaconDetected(beacon: beaconRegion)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion {
            print("EXIT beacon region: \(beaconRegion)")
        }
    }
}
