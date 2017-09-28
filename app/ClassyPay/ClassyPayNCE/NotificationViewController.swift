//
//  Copyright © 2017 Classy Code GmbH. All rights reserved.
//
import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var messageLabel: UILabel!
    @IBOutlet var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func didReceive(_ notification: UNNotification) {
        titleLabel.text = notification.request.content.title
        messageLabel.text = notification.request.content.body
        imageView.image = UIImage(named: "notification_initiate")
    }

    func didReceive(_ response: UNNotificationResponse,
                    completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void) {
        if response.actionIdentifier == "initiate" {
            self.imageView.image = UIImage(named: "notification_progress")
            titleLabel.text = "Action in progress"
            messageLabel.text = "Please wait..."
            
            let backendService = BackendService()
            let actionUuid = response.notification.request.content.userInfo["actionUuid"] as! String
            backendService.performAction(actionUuid: actionUuid, completionHandler: { (serviceError) in
                DispatchQueue.main.async {
                    if let serviceError = serviceError {
                        self.imageView.image = UIImage(named: "notification_error")
                        self.titleLabel.text = "Action failed"
                        self.messageLabel.text = serviceError.localizedDescription
                    } else {
                        self.imageView.image = UIImage(named: "notification_done")
                        self.titleLabel.text = "Action succeeded"
                        self.messageLabel.text = "SUCCESS"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                        completion(.dismiss)
                    })
                }
            })
        } else if response.actionIdentifier == "cancel" {
            completion(.dismiss)
        }
    }

}
