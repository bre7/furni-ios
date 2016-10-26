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

final class SignInViewController: UIViewController {

    static let storyboardIdentifier = "SignInViewController"

    // MARK: Properties

    @IBOutlet fileprivate weak var signInDigitsButton: UIButton!

    @IBOutlet fileprivate weak var signInTwitterButton: UIButton!

    fileprivate var completion: ((_ success: Bool) -> ())?

    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Decorate the Sign In with Digits and Twitter buttons.
        signInDigitsButton.decorateForFurni()
        signInTwitterButton.decorateForFurni()

        // Add custom images to the buttons with the proper rendering mode.
        signInDigitsButton.setImage(UIImage(named: "Digits")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
        signInTwitterButton.setImage(UIImage(named: "Twitter")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
    }

    fileprivate func authenticateWithService(_ service: Service) {
        AccountManager.defaultAccountManager.authenticateWithService(service) { success in
            if success {
                self.dismiss(animated: true) {
                    self.completion?(success)
                    self.completion = nil
                }
            }
        }
    }

    // MARK: IBActions

    @IBAction fileprivate func signInDigitsButtonTapped(_ sender: UIButton) {
        self.authenticateWithService(.Digits)
    }

    @IBAction fileprivate func signInTwitterButtonTapped(_ sender: UIButton) {
        self.authenticateWithService(.Twitter)
    }

    @IBAction fileprivate func closeButtonTapped(_ sender: AnyObject) {
        appDelegate.tabBarController.dismiss(animated: true) { }
    }

    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }

    static func presentSignInViewController(withCompletion completion: @escaping ((Bool) -> ())) {
        let signInViewController = UIStoryboard.mainStoryboard.instantiateViewController(withIdentifier: SignInViewController.storyboardIdentifier) as! SignInViewController
        signInViewController.completion = completion

        // Create a blur effect.
        // let blurEffect = UIBlurEffect(style: .Dark)
        // let blurEffectView = UIVisualEffectView(effect: blurEffect)
        // blurEffectView.frame = UIScreen.mainScreen().bounds
        // signInViewController.view.backgroundColor = UIColor.clearColor()
        // signInViewController.view.insertSubview(blurEffectView, atIndex: 0)

        // Customize the sign in view controller presentation and transition styles.
        signInViewController.modalPresentationStyle = .overCurrentContext
        signInViewController.modalTransitionStyle = .crossDissolve

        // Present the sign in view controller.
        appDelegate.tabBarController.present(signInViewController, animated: true, completion: nil)
    }
}
