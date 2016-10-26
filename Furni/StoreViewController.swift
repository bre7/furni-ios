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
import Optimizely

final class StoreViewController: UIViewController, UITableViewDelegate {

    fileprivate enum StoreLayout {
        case basic
        case rich
    }

    // MARK: Properties

    @IBOutlet fileprivate var tableView: UITableView!

    fileprivate let tableViewSectionHeaderHeight: CGFloat = 0.1
    fileprivate let tableViewSectionFooterHeight: CGFloat = 20

    fileprivate lazy var refreshControl = UIRefreshControl()

    fileprivate let collectionTableViewDataSource = CollectionTableViewDataSource<CollectionCell>()
    fileprivate let collectionPreviewTableViewDataSource = CollectionTableViewDataSource<CollectionPreviewCell>()

    fileprivate var dataSource: UITableViewDataSource? {
        didSet {
            self.tableView.dataSource = dataSource
            self.tableView.reloadData()
        }
    }

    fileprivate var storeLayout: StoreLayout = .basic {
        didSet {
            switch storeLayout {
            case .basic: self.dataSource = collectionTableViewDataSource
            case .rich: self.dataSource = collectionPreviewTableViewDataSource
            }
        }
    }

    var collections: [Collection] = [] {
        didSet {
            collectionTableViewDataSource.collections = collections
            collectionPreviewTableViewDataSource.collections = collections
            tableView.reloadData()
        }
    }

    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup the refresh control.
        tableView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(StoreViewController.fetchCollections), for: .valueChanged)

        // Fetch collections from the API.
        fetchCollections()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Setup A/B testing with Optimizely to switch layout based on a code block.
        Optimizely.codeBlocks(with: storeLayoutCodeBlock,
            blockOne: { [weak self] in self?.storeLayout = .basic },
            blockTwo: { [weak self] in self?.storeLayout = .rich },
            defaultBlock: { [weak self] in self?.storeLayout = .basic }
        )
    }

    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.cellHeightForLayout(self.storeLayout)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return tableViewSectionHeaderHeight
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return tableViewSectionFooterHeight
    }

    // MARK: UIStoryboardSegue Handling

    fileprivate func collectionAtIndexPath(_ indexPath: IndexPath) -> Collection {
        return self.collections[indexPath.section]
    }

    fileprivate enum Segue: String {
        case ViewCollectionBasicLayout = "ViewCollectionBasicLayoutSegue"
        case ViewCollectionRichLayout = "ViewCollectionRichLayoutSegue"
        case ViewProduct = "ViewProductSegue"
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier! {
        case Segue.ViewCollectionBasicLayout.rawValue, Segue.ViewCollectionRichLayout.rawValue:
            let indexPath = tableView.indexPathForSelectedRow!
            let collection = collectionAtIndexPath(indexPath)

            let productCollectionViewController = segue.destination as! ProductCollectionViewController
            productCollectionViewController.collection = collection

            // Log Content View Event in Answers.
            Answers.logContentView(withName: collection.name,
                contentType: "Collection",
                contentId: String(collection.id),
                customAttributes: nil
            )
        case Segue.ViewProduct.rawValue:
            // Note: this is a naive way of retrieving which product was tapped on the collection view. In a production app, this could be implemented in a more maintainable way without the use of storyboard segues.
            let cell = sender as! ProductPreviewCollectionViewCell
            let product = cell.product

            let productDetailViewController = segue.destination as! ProductDetailViewController
            productDetailViewController.product = product

            // Log Content View Event in Answers.
            Answers.logContentView(withName: product?.name,
                contentType: "Product",
                contentId: String(describing: product?.id),
                customAttributes: nil
            )
        default:
            fatalError("Unhandled Segue identifier \(segue.identifier)")
        }
    }

    fileprivate func cellHeightForLayout(_ layout: StoreLayout) -> CGFloat {
        switch layout {
        case .basic:
            return view.bounds.width / 2 + 10
        case .rich:
            return view.bounds.width / 2 + 100
        }
    }

    // MARK: API

    func fetchCollections() {
        // Fetch collections from the API.
        FurniAPI.sharedInstance.getCollectionList { collections in
            // Sort collections by most recent first and reload the table.
            self.collections = collections.sorted { $0.date!.compare($1.date! as Date) == .orderedDescending }
            self.tableView.reloadData()

            // Stop animating the refresh control.
            self.refreshControl.endRefreshing()
        }
    }
}
