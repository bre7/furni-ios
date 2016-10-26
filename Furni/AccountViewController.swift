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

final class AccountViewController: UIViewController {

    // MARK: Properties

    @IBOutlet fileprivate weak var pictureImageView: UIImageView!

    @IBOutlet fileprivate weak var nameLabel: UILabel!

    @IBOutlet fileprivate weak var signOutButton: UIButton!

    // MARK: IBActions

    @IBAction fileprivate func signOutButtonTapped(_ sender: AnyObject) {
        AccountManager.defaultAccountManager.signOut()

        SignInViewController.presentSignInViewController() { _ in }
    }

    @IBAction fileprivate func learnMoreButtonTapped(_ sender: AnyObject) {
        let url = URL(string: "http://furni.xyz")!
        if #available(iOS 10, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url)
        }
    }

    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        signOutButton.decorateForFurni()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Add rounded corners to the image.
        pictureImageView.layer.cornerRadius = pictureImageView.bounds.width / 2
        pictureImageView.layer.masksToBounds = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Assign the user name and image.
        let user = AccountManager.defaultAccountManager.user
        user?.populateWithLocalContact()
        self.nameLabel.text = user?.fullName
        self.pictureImageView.image = user?.image
    }
}
