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
import Crashlytics
import Stripe
import Alamofire

private struct PaymentConfiguration {
    // Stripe Key: https://dashboard.stripe.com/account/apikeys
    let stripePublishableKey: String

    // Backend Charge URL: https://github.com/stripe/example-ios-backend
    let backendChargeURLString: String

    // Apple Pay: https://stripe.com/docs/mobile/apple-pay
    let appleMerchantID: String
}

final class CartViewController: UITableViewController, PKPaymentAuthorizationViewControllerDelegate {

    // MARK: Properties

    fileprivate let cart = Cart.sharedInstance

    fileprivate let paymentConfiguration: PaymentConfiguration? = PaymentConfiguration(
        stripePublishableKey: "Your Stripe Publishable Key",
        backendChargeURLString: "Your Backend Charge URL",
        appleMerchantID: "merchant.xyz.furni"
    )

    override func awakeFromNib() {
        super.awakeFromNib()

        // Listen to notifications about the cart being updated.
        NotificationCenter.default.addObserver(self, selector: #selector(CartViewController.cartUpdatedNotificationReceived), name: NSNotification.Name(rawValue: Cart.cartUpdatedNotificationName), object: self.cart)
    }

    // Order price in cents.
    fileprivate var orderPriceCents: Float = 0

    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Put a label as the background view to display when the cart is empty.
        let emptyCartLabel = UILabel()
        emptyCartLabel.numberOfLines = 0
        emptyCartLabel.textAlignment = .center
        emptyCartLabel.textColor = UIColor.furniDarkGrayColor()
        emptyCartLabel.font = UIFont.systemFont(ofSize: CGFloat(20))
        emptyCartLabel.text = "Your cart is empty.\nGo add some nice products! 😉"
        tableView.backgroundView = emptyCartLabel
        tableView.backgroundView?.isHidden = true
        tableView.backgroundView?.alpha = 0
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.tableView.reloadData()
        toggleEmptyCartLabel()
    }


    // MARK: IBActions

    @IBAction func beginPayment(_ sender: AnyObject) {
        // Check if a payment configuration is available.
        guard let paymentConfiguration = self.paymentConfiguration else {
            self.displayLackOfPaymentConfigurationAlert()
            return
        }

        // Only returns nil if we are on iOS < 8.
        let paymentRequest = Stripe.paymentRequest(withMerchantIdentifier: paymentConfiguration.appleMerchantID)

        // Check if Apple Pay is available.
        guard Stripe.canSubmitPaymentRequest(paymentRequest) else {
            print("Apple Pay is not available.")
            return
        }

        // Update the shipping contact using the user postal address.
        if let user = AccountManager.defaultAccountManager.user {
            user.populateWithLocalContact()
            
            let contact = PKContact()
            var name = PersonNameComponents()
            name.givenName = user.fullName
            contact.name = name

            contact.phoneNumber = user.digitsPhoneNumber.map(CNPhoneNumber.init)
            contact.postalAddress = user.postalAddress
            paymentRequest.shippingContact = contact
        }

        // Setup the payment request.
        paymentRequest.requiredShippingAddressFields = .postalAddress
        paymentRequest.requiredBillingAddressFields = .email
        paymentRequest.paymentSummaryItems = [
            PKPaymentSummaryItem(label: "Subtotal", amount: NSDecimalNumber(value: cart.subtotalAmount() as Float)),
            PKPaymentSummaryItem(label: "Shipping", amount: NSDecimalNumber(value: cart.shippingAmount() as Float)),
            PKPaymentSummaryItem(label: "Furni", amount: NSDecimalNumber(value: cart.totalAmount() as Float))
        ]

        // Log Start Checkout Event in Answers.
        Answers.logStartCheckout(withPrice: NSDecimalNumber(value: cart.totalAmount() as Float),
            currency: "USD",
            itemCount: cart.productCount() as NSNumber?,
            customAttributes: nil
        )

        // Setup and present the payment view controller.
        let paymentAuthViewController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest)
        paymentAuthViewController.delegate = self
        present(paymentAuthViewController, animated: true, completion: nil)
    }

    fileprivate func displayLackOfPaymentConfigurationAlert() {
        let alert = UIAlertController(
            title: "You need to set your Stripe publishable key.",
            message: "You can find your publishable key at https://dashboard.stripe.com/account/apikeys",
            preferredStyle: .alert
        )
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }

    // MARK: PKPaymentAuthorizationViewControllerDelegate

    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: (@escaping (PKPaymentAuthorizationStatus) -> Void)) {

        // Note: We pretend the payment is successful for demo purposes.
        completion(.success)

        // Navigation to the order successful view controller.
        self.performSegue(withIdentifier: "OrderSuccessfulSegue", sender: self)

        // Reset the cart.
        self.cart.reset()

        // Setup the Stripe API client to create a token from the payment.
        let apiClient = STPAPIClient(publishableKey: paymentConfiguration!.stripePublishableKey)
        apiClient.createToken(with: payment, completion: { token, error in
            guard let token = token else {
                completion(.failure)
                return
            }
            self.createBackendChargeWithToken(token, completion: { result, error in
                guard result == .success else {
                    completion(.failure)
                    return
                }
                // Log Purchase Custom Events in Answers.
                for item in self.cart.items {
                    Answers.logPurchase(withPrice: NSDecimalNumber(value: item.product.price as Float),
                        currency: "USD",
                        success: true,
                        itemName: item.product.name,
                        itemType: "Furni",
                        itemId: String(item.product.id),
                        customAttributes: ["Quantity": item.quantity]
                    )
                }
            })
        })
    }

    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        dismiss(animated: true) { }
    }

    // MARK: Stripe

    func createBackendChargeWithToken(_ token: STPToken, completion: @escaping (PKPaymentAuthorizationStatus, Error?) -> Void ) {
        guard let backendChargeURLString = paymentConfiguration?.backendChargeURLString, !backendChargeURLString.isEmpty else {
            completion(.failure, NSError(domain: StripeDomain, code: 50, userInfo: [NSLocalizedDescriptionKey: "You created a token! Its value is \(token.tokenId). Now configure your backend to accept this token and complete a charge."]))
            return
        }

        let url = URL(string: backendChargeURLString)!.appendingPathComponent("charge")
        let chargeParams: [String: AnyObject] = ["stripeToken": token.tokenId as AnyObject, "amount": orderPriceCents as AnyObject]

        // Create the POST request to the backend to process the charge.
        request(url, method: .post, parameters: chargeParams)
            .responseJSON(completionHandler: { dataResponse in
                if dataResponse.response?.statusCode == 200 {
                    completion(.success, nil)
                } else {
                    completion(.failure, nil)
                }
            })
    }

    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return cart.isEmpty() ? 0 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of items in the cart.
        return cart.items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CartItemCell.reuseIdentifier, for: indexPath) as! CartItemCell

        // Find the corresponding cart item.
        let cartItem = cart.items[indexPath.row]

        // Keep a weak reference on the table view.
        cell.cartItemQuantityChangedCallback = { [unowned self] in
            self.refreshCartDisplay()
            self.tableView.reloadData()
        }

        // Configure the cell with the cart item.
        cell.configureWithCartItem(cartItem)

        // Return the cart item cell.
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }

        // Remove this item from the cart and refresh the table view.
        cart.items.remove(at: indexPath.row)

        // Either delete some rows within the section (leaving at least one) or the entire section.
        if cart.items.count > 0 {
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else {
            tableView.deleteSections(IndexSet(integer: indexPath.section), with: .fade)
        }

        // Log Custom Event in Answers.
        Answers.logCustomEvent(withName: "Edited Cart", customAttributes: nil)
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = tableView.dequeueReusableCell(withIdentifier: CartFooterCell.reuseIdentifier) as! CartFooterCell

        // Configure the footer with the cart.
        footerView.configureWithCart(cart)

        // Return the footer view.
        return footerView.contentView
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let tableViewHeight = UIScreen.main.bounds.height - tableView.frame.origin.y - tabBarController!.tabBar.bounds.height
        return max(150, tableViewHeight - CGFloat(80 * cart.items.count))
    }

    // MARK: Utilities

    @objc fileprivate func cartUpdatedNotificationReceived() {
        // Update the price of the cart in cents.
        orderPriceCents = cart.totalAmount() * 100.0

        // Refresh the cart display.
        self.refreshCartDisplay()
    }

    fileprivate func refreshCartDisplay() {
        let cartTabBarItem = self.parent!.tabBarItem

        // Update the tab bar badge.
        let productCount = cart.productCount()
        cartTabBarItem!.badgeValue = productCount > 0 ? String(productCount) : nil

        // Update the tab bar icon.
        if productCount > 0 {
            cartTabBarItem?.image = UIImage(named: "Cart-Full")
            cartTabBarItem?.selectedImage = UIImage(named: "Cart-Full-Selected")
        } else {
            cartTabBarItem?.image = UIImage(named: "Cart")
            cartTabBarItem?.selectedImage = UIImage(named: "Cart-Selected")
        }

        // Toggle the empty cart label if needed.
        toggleEmptyCartLabel()
    }

    fileprivate func toggleEmptyCartLabel() {
        if cart.isEmpty() {
            UIView.animate(withDuration: 0.15, animations: {
                self.tableView.backgroundView!.isHidden = false
                self.tableView.backgroundView!.alpha = 1
            }) 
        } else {
            UIView.animate(withDuration: 0.15,
                animations: {
                    self.tableView.backgroundView!.alpha = 0
                },
                completion: { finished in
                    self.tableView.backgroundView!.isHidden = true
                }
            )
        }
    }
}
