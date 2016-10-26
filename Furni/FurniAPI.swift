//
// Copyright (C) 2015 Twitter, Inc. and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import Alamofire
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}


private typealias JSONObject = [String : AnyObject]

final class FurniAPI {
    static let sharedInstance = FurniAPI()

    // API base URL.
    fileprivate let apiBaseURL = "https://vso4w24kxa.execute-api.us-east-1.amazonaws.com/prod/"

    fileprivate var cachedCollections: [Collection] = []

    func getCollectionList(_ completion: @escaping ([Collection]) -> Void) {
        if cachedCollections.count > 0 {
            completion(cachedCollections)
        }

        get("collections") { JSON in
            if let result = JSON as? JSONObject {
                let collectionArray = result["collections"] as! [JSONObject]
                var collections: [Collection] = []
                for dict in collectionArray {
                    collections.append(Collection(dictionary: dict))
                }
                self.cachedCollections = collections
                completion(collections)
            }
        }
    }

    func getCollection(_ permalink: String, completion: @escaping (Collection) -> Void) {
        let collection = self.cachedCollections.filter{ $0.permalink == permalink }.first
        if collection?.products.count > 0 {
            completion(collection!)
        }

        get("collections/" + permalink) { JSON in
            if let result = JSON as? JSONObject {
                let productArray = result["products"] as! [JSONObject]
                for productDict in productArray {
                    collection!.products.append(Product(dictionary: productDict, collectionPermalink: permalink))
                }
                completion(collection!)
            }
        }
    }

    // Convenience method to perform a GET request on an API endpoint.
    fileprivate func get(_ endpoint: String, completion: @escaping (AnyObject?) -> Void) {
        request(endpoint, method: .get, encoding: JSONEncoding.default, parameters: nil, completion: completion)
    }

    // Convenience method to perform a POST request on an API endpoint.
    fileprivate func post(_ endpoint: String, parameters: [String: AnyObject]?, completion: @escaping (AnyObject?) -> Void) {
        request(endpoint, method: .post, encoding: JSONEncoding.default, parameters: parameters, completion: completion)
    }

    // Perform a request on an API endpoint using Alamofire.
    fileprivate func request(_ endpoint: String, method: Alamofire.HTTPMethod, encoding: Alamofire.ParameterEncoding, parameters: Alamofire.Parameters?, completion: @escaping (AnyObject?) -> Void) {
        let url = apiBaseURL + endpoint

        print("Starting \(method) \(url) (\(parameters ?? [:]))")
        Alamofire
            .request(url,
                     method: method,
                     parameters: parameters,
                     encoding: encoding,
                     headers: nil)
            .responseJSON { resultData in
                print("Finished \(method) \(url): \(resultData.response?.statusCode)")

                switch resultData.result {
                case .success(let JSON):
                    completion(JSON as AnyObject?)
                case .failure(let error):
                    print("Request failed with error: \(error)")
                    if let data = resultData.data {
                        print("Response data: \(String(data: data, encoding: .utf8)!)")
                    }

                    completion(nil)
                }
        }
    }
}

final class AuthenticatedFurniAPI {
    typealias CognitoID = String
    fileprivate let cognitoID: CognitoID

    init(cognitoID: CognitoID) {
        self.cognitoID = cognitoID
    }

    func registerUser(_ digitsUserID: String?, digitsPhoneNumber: String?, completion: @escaping (Bool) -> ()) {
        var parameters: JSONObject = ["cognitoId": self.cognitoID as AnyObject]
        if let digitsUserID = digitsUserID, let digitsPhoneNumber = digitsPhoneNumber {
            parameters["digitsId"] = digitsUserID as AnyObject?
            parameters["phoneNumber"] = digitsPhoneNumber as AnyObject?
        }

        FurniAPI.sharedInstance.post("users/", parameters: parameters) { response in
            let success = response != nil

            completion(success)
        }
    }

    func favoriteProduct(_ favorite: Bool, product: Product, completion: @escaping (Bool) -> ()) {
        product.isFavorited = favorite
        FurniAPI.sharedInstance.request("favorites", method: favorite ? .post : .delete, encoding: JSONEncoding.default, parameters: [
            "product": "\(product.id)",
            "collection": product.collectionPermalink,
            "cognitoId": self.cognitoID]) { response in
                let success = response != nil
                if !success {
                    product.isFavorited = !favorite
                }

                completion(success)
        }
    }

    func userFavoriteProducts(_ completion: @escaping ([Product]?) -> ()) {
        favoriteProducts(self.cognitoID) { completion($0?[self.cognitoID] ?? []) }
    }

    fileprivate func favoriteProducts(_ cognitoID: CognitoID?, completion: @escaping ([CognitoID : [Product]]?) -> ()) {
        let path = cognitoID ?? ""
        FurniAPI.sharedInstance.get("favorites/\(path)") { response in
            guard let productDictionariesPerCognitoID = response as? JSONObject else {
                print("Error parsing favorite products in response: \(response)")
                completion(nil)
                return
            }

            var productsPerCognitoID: [CognitoID : [Product]] = [:]

            for (cognitoID, productsDictionary) in productDictionariesPerCognitoID {
                guard let productDictionaries = ((productsDictionary as? JSONObject)?["products"]) as? [JSONObject] else {
                    print("Error parsing favorite products in response: \(response)")
                    completion(nil)
                    return
                }

                let products = productDictionaries.map { Product(dictionary: $0, collectionPermalink: ($0["collection"] as? String) ?? "") }.sorted { $0.id > $1.id }

                productsPerCognitoID[cognitoID] = products
            }

            completion(productsPerCognitoID)
        }
    }

    func uploadDigitsFriends(digitsUserIDs: [String], completion: @escaping (Bool) -> ()) {
        FurniAPI.sharedInstance.post("friendships", parameters: [
            "from": self.cognitoID as AnyObject,
            "to": digitsUserIDs as AnyObject
        ]) { response in
            print("\(response as! NSDictionary)")
            let success = response != nil

            completion(success)
        }
    }

    func friends(_ completion: @escaping ([User]?) -> ()) {
        FurniAPI.sharedInstance.get("friendships/\(self.cognitoID)") { response in
            guard let result = response as? JSONObject,
                let friendsDictionaries = result["friends"] as? [JSONObject] else {
                    completion(nil)
                    return
            }

            var users: [User] = []

            for friend in friendsDictionaries {
                let user = User()
                user.cognitoID = friend["cognitoId"] as? String
                user.digitsUserID = friend["digitsId"] as? String
                user.digitsPhoneNumber = friend["phoneNumber"] as? String

                user.populateWithLocalContact()

                users.append(user)
            }

            self.favoriteProducts(self.cognitoID) { productsByCognitoID in
                guard let productsByCognitoID = productsByCognitoID else {
                    completion(nil)
                    return
                }
                
                for user in users {
                    let favoriteProducts = user.cognitoID.flatMap { productsByCognitoID[$0] } ?? []
                    user.favorites = favoriteProducts
                }
                
                completion(users)
            }
        }
    }
}
