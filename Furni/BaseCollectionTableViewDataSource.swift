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

protocol CollectionTableViewCellType {
    func configureWithCollection(_ collection: Collection)

    static var reuseIdentifier: String { get }
}

final class CollectionTableViewDataSource<CellClass: CollectionTableViewCellType>: NSObject, UITableViewDataSource where CellClass: UITableViewCell {
    var collections: [Collection] = []

    // MARK: UITableViewDataSource

    final func numberOfSections(in tableView: UITableView) -> Int {
        // Return each collection as a table view section.
        return collections.count
    }

    final func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return 1
    }

    final func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CellClass.reuseIdentifier, for: indexPath) as! CellClass

        // Find the corresponding collection.
        let collection = collections[indexPath.section]

        // Configure the cell with the collection.
        cell.configureWithCollection(collection)

        // Style the cell when in selection mode.
        cell.selectedBackgroundView = UIView(frame: cell.bounds)
        cell.selectedBackgroundView!.backgroundColor = UIColor.furniBeigeColor()


        // Return the collection cell.
        return cell
    }
}

