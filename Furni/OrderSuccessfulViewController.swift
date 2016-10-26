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
import TwitterKit
import Crashlytics

final class OrderSuccessfulViewController: UIViewController {

    // MARK: Properties

    @IBOutlet fileprivate weak var thanksLabel: UILabel!

    @IBOutlet fileprivate weak var orderNumberLabel: UILabel!

    @IBOutlet fileprivate weak var customerServiceLabel: UILabel!

    @IBOutlet fileprivate weak var twitterButton: UIButton!

    // MARK: IBActions

    @IBAction fileprivate func twitterButtonTapped(_ sender: AnyObject) {
        if AccountManager.defaultAccountManager.twitterIdentity != nil {
            tweetToFurni()
        } else {
            AccountManager.defaultAccountManager.authenticateWithService(.Twitter) { success in
                self.updateTwitterLabels()
            }
        }
    }

    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Assign the labels.
        let name = AccountManager.defaultAccountManager.user!.fullName ?? ""
        thanksLabel.text = !name.isEmpty ? "\(name)!" : ""
        orderNumberLabel.text = "#10212015"
        customerServiceLabel.layer.masksToBounds = true
        customerServiceLabel.drawTopBorderWithColor(UIColor.furniBrownColor(), height: 0.5)

        // Customize the Twitter button.
        twitterButton.decorateForFurni()
        twitterButton.setImage(UIImage(named: "Twitter")?.withRenderingMode(.alwaysTemplate), for: UIControlState())

        // Update Twitter / Customer Service labels.
        updateTwitterLabels()
    }

    fileprivate func updateTwitterLabels() {
        if AccountManager.defaultAccountManager.twitterIdentity != nil {
            customerServiceLabel.text = "Thank you for connecting your Twitter account! Tweet any questions @furni, we’re here to help! 💁"
            twitterButton.setTitle(" TWEET TO @FURNI", for: UIControlState())
        } else {
            customerServiceLabel.text = "Did you know you can link your Twitter account for a great customer experience? 💁"
            twitterButton.setTitle(" CONNECT WITH TWITTER", for: UIControlState())
        }
    }

    fileprivate func tweetToFurni() {
        // Use the TwitterKit to create a Tweet composer.
        let composer = TWTRComposer()

        // Prepare the Tweet.
        composer.setText("Hey @furni! ")

        // Present the composer to the user.
        composer.show(from: self) { result in
            if result == .done {
                // Log Custom Event in Answers.
                Answers.logCustomEvent(withName: "Tweet Completed", customAttributes: nil)
            } else if result == .cancelled {
                // Log Custom Event in Answers.
                Answers.logCustomEvent(withName: "Tweet Cancelled", customAttributes: nil)
            }
        }
    }
}
