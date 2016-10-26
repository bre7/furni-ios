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
import AlamofireImage

final class CartItemCell: UITableViewCell {

    static let reuseIdentifier = "CartItemCell"

    var cartItemQuantityChangedCallback: (() -> ())!

    fileprivate weak var cartItem: CartItem!

    // MARK: Properties

    @IBOutlet fileprivate weak var nameLabel: UILabel!

    @IBOutlet fileprivate weak var priceLabel: UILabel!

    @IBOutlet fileprivate weak var quantityLabel: UILabel!

    @IBOutlet fileprivate weak var quantityStepper: UIStepper!

    @IBOutlet fileprivate weak var availabilityLabel: UILabel!

    @IBOutlet fileprivate weak var productImageView: UIImageView!

    // MARK: IBActions

    @IBAction fileprivate func quantityStepperValueChanged(_ sender: UIStepper) {
        let value = Int(sender.value)
        cartItem!.quantity = value
        quantityLabel.text = "Quantity: \(value)"
        cartItemQuantityChangedCallback()
    }

    override func awakeFromNib() {
        // Resize the stepper.
        quantityStepper.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        // Draw a border layer at the top.
        self.drawTopBorderWithColor(UIColor.furniBrownColor(), height: 0.5)
    }

    func configureWithCartItem(_ cartItem: CartItem) {
        self.cartItem = cartItem

        // Assign the labels.
        nameLabel.text = cartItem.product.name
        priceLabel.text = cartItem.price.asCurrency
        availabilityLabel.text = "In Stock"
        quantityLabel.text = "Quantity: \(cartItem.quantity)"
        quantityStepper.value = Double(cartItem.quantity)

        // Load the image from the network and give it the correct aspect ratio.
        productImageView.af_setImage(withURL: cartItem.product.imageURL)
    }
}
