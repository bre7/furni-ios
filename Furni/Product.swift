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

import UIKit

class Product {
    let id: Int
    let collectionPermalink: String
    let name: String
    let description: String
    let price: Float
    let retailPrice: Float
    let percentOff: Int
    let currency: String
    let productURL: URL
    let imageURL: URL

    init(id: Int, collectionPermalink: String, name: String, description: String, price: Float, retailPrice: Float, percentOff: Int, currency: String, productURL: URL, imageURL: URL) {
        self.id = id
        self.collectionPermalink = collectionPermalink
        self.name = name
        self.description = description
        self.price = price
        self.retailPrice = retailPrice
        self.percentOff = percentOff
        self.currency = currency
        self.productURL = productURL
        self.imageURL = imageURL
    }

    init(dictionary: [String : AnyObject], collectionPermalink permalink: String) {
        // Note: This is a naive implementation of JSON parsing.
        // In a production Swift app, we recommend using a library such as Decodable: https://github.com/Anviking/Decodable

        id = dictionary["id"] as! Int
        collectionPermalink = permalink
        name = (dictionary["name"] as! String).trimmingCharacters(in: CharacterSet.whitespaces)
        description = (dictionary["description"] as! String).trimmingCharacters(in: CharacterSet.whitespaces)
        price = (dictionary["price"] as! NSString).floatValue
        retailPrice = (dictionary["retail_price"] as! NSString).floatValue
        if let _ = dictionary["percentoff"] as? Int {
            percentOff = dictionary["percentoff"] as! Int
        } else {
            percentOff = 0
        }
        currency = "USD"
        productURL = URL(string: (dictionary["url"] as! String!))!

        // Save the image URL and make sure it is HTTPS.
        var imageURLComponents = URLComponents(string: dictionary["image_url"] as! String)!
        imageURLComponents.scheme = "https"
        imageURL = imageURLComponents.url!
    }
}
