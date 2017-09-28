//
//  Copyright © 2017 Classy Code GmbH. All rights reserved.
//
import Foundation

class BackendService {
    
    let urlSession = URLSession(configuration: .ephemeral)
    
    func lookupAction(proximityUuid: UUID, major: Int, minor: Int,
                        completionHandler: @escaping (Error?, String?) -> ()) {
        let url = URL(string: "https://httpbin.org/uuid")!
        urlSession.dataTask(with: url) { (data, response, error) in
            if let error = error {
                completionHandler(error, nil)
            } else {
                if let data = data {
                    do {
                        if let jsonObj = try JSONSerialization.jsonObject(with: data, options: []) as? [AnyHashable: AnyObject] {
                            let actionUuid = jsonObj["uuid"] as? String
                            completionHandler(nil, actionUuid)
                        }
                    } catch {
                        completionHandler(error, nil)
                    }
                }
            }
        }.resume()
    }
    
    func performAction(actionUuid: String, completionHandler: @escaping (Error?) -> ()) {
        let url = URL(string: "https://httpbin.org/delay/2")!
        urlSession.dataTask(with: url) { (data, response, error) in
            completionHandler(error)
        }.resume()
    }
}
