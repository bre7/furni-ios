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
import UIKit
import Contacts

class User {
    var cognitoID: String?
    var twitterUserID: String?
    var twitterUsername: String?
    var digitsUserID: String?
    var digitsPhoneNumber: String?

    var fullName: String? = "Romain Huet"
    var image: UIImage? = UIImage(named: "Romain")!
    var postalAddress: CNPostalAddress?

    var favorites: [Product] = []

    // Enrich the user by fetching information from the local contact by phone number.
    func populateWithLocalContact() {
        guard let digitsPhoneNumber = digitsPhoneNumber else { return }

        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return }

        let store = CNContactStore()
        let fetchRequest = CNContactFetchRequest(keysToFetch: [CNContactPhoneNumbersKey as CNKeyDescriptor, CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPostalAddressesKey as CNKeyDescriptor, CNContactImageDataKey as CNKeyDescriptor])

        do {
            try store.enumerateContacts(with: fetchRequest) { (contact, stop) in
                let matchingPhoneNumbers = contact.phoneNumbers.map { $0.value }.filter {
                    phoneNumber($0, matchesPhoneNumberString: digitsPhoneNumber)
                }

                guard matchingPhoneNumbers.count > 0 else {
                    return
                }

                self.fullName = CNContactFormatter.string(from: contact, style: .fullName)
                self.image = contact.imageData.flatMap(UIImage.init)
                self.postalAddress = contact.postalAddresses.map { $0.value }.first

                stop.pointee = true
            }
        }
        catch let error as NSError {
            print("Error looking for contact: \(error)")
        }
    }
}

private func phoneNumber(_ phoneNumber: CNPhoneNumber, matchesPhoneNumberString phoneNumberString: String) -> Bool {
    return phoneNumberString.range(of: phoneNumber.stringValue.stringByRemovingOccurrencesOfCharacters(" )(- ")) != nil
}

// Note: This is a naive implementation that relies on global state. Avoid this in a production app.
extension Product {
    var isFavorited: Bool {
        get {
            return AccountManager.defaultAccountManager.user?.favorites.contains { $0.id == self.id } ?? false
        }
        set {
            guard let user = AccountManager.defaultAccountManager.user else { return }

            if newValue {
                user.favorites.append(self)
            } else {
                user.favorites = user.favorites.filter { $0.id != self.id }
            }
        }
    }
}
