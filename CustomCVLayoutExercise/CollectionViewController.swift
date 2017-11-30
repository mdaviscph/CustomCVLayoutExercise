//
//  CollectionViewController.swift
//
//  Copyright © 2017 Mike Davis. All rights reserved.
//

import UIKit

/// Static UICollectionViewController (expects fixed number of rows and columns but can be resized).
/// Fixed column zero (will not scroll). Scrolling ends on cell boundary (horizontal or vertical).
/// Variable row height. Requires attributed strings.
final class CollectionViewController: UICollectionViewController, CollectionViewLayoutDelegate {

    // TODO: the following should be provided by an outside data source.
    private struct Constants {
        struct RowZero {
            static let font = UIFont(name: "AvenirNext-Demibold", size: 11.0)!
            static let color = UIColor.black
            static let backgroundColor = UIColor(red: 230.0/255.0, green: 232.0/255.0, blue: 232.0/255.0, alpha: 1.0)
        }
        struct ColumnZero {
            static let titleFont = UIFont(name: "AvenirNext-Italic", size: 12.0)!
            static let authorFont = UIFont(name: "AvenirNext-Regular", size: 12.0)!
            static let color = UIColor.black
            static let backgroundColor = UIColor(red: 219.0/255.0, green: 220.0/255.0, blue: 220.0/255.0, alpha: 1.0)
            static let width: CGFloat = 100
        }
        struct Body {
            static let font = UIFont(name: "AvenirNext-Medium", size: 11.0)!
            static let color = UIColor.darkGray
            static let backgroundColor = UIColor.white
            static let width: CGFloat = 120
        }
        struct RowColumnZero {
            static let backgroundColor = UIColor(red: 195.0/255.0, green: 196.0/255.0, blue: 196.0/255.0, alpha: 1.0)
        }
        static let verticalPadding: CGFloat = 8.0
        static let horizontalPadding: CGFloat = 8.0
        static let constrainedCellHeight: CGFloat = 120.0    // cell height before padding will be approx. constrained to this value
        static let minimumCellHeight: CGFloat = 38.0
    }
    
    // TODO: eventually use data provided by outside data source. For now use dummy data.
    let sectionCount = RowAndColumnLabels.columnZero.count
    let itemCount = RowAndColumnLabels.rowZero.count
    
    // TODO: do we benefit from caching attributed strings? If they change we must rebuild cached cell sizes.
    /// Dictionary used to cache attributed strings for cell content, key is IndexPath.
    var cachedAttributedString: [IndexPath: NSAttributedString] = [:]
    /// Dictionary used to cache the cell sizes for performance, key is IndexPath.
    var cachedCellSize: [IndexPath: CGSize] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        (collectionView?.collectionViewLayout as? CollectionViewLayout)?.layoutDelegate = self
        
        // Create caches for better performance.
        cachedAttributedString = attributedStringsForCells(sectionCount: sectionCount, itemCount: itemCount)
        cachedCellSize = calculatedCellSizes(sectionCount: sectionCount, itemCount: itemCount)
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sectionCount
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return itemCount
    }

    // Row == Section, Column == Item: each row is a separate section. The cell for the column is the item within that section.
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: CollectionViewCell.self), for: indexPath) as! CollectionViewCell
        let backgroundColor: UIColor
        switch (indexPath.isRowZero, indexPath.isColumnZero) {
        case (false, false):
            backgroundColor = Constants.Body.backgroundColor
        case (false, true):
            backgroundColor = Constants.ColumnZero.backgroundColor
        case (true, false):
            backgroundColor = Constants.RowZero.backgroundColor
        case (true, true):
            backgroundColor = Constants.RowColumnZero.backgroundColor
        }
        cell.backgroundColor = backgroundColor
        if let attributedText = cachedAttributedString[indexPath] {
            cell.detailLabel?.attributedText = attributedText
        } else {
            assertionFailure("Missing attributed text for cell \(indexPath)")
            cell.detailLabel?.text = "ERROR"
        }
        return cell
    }
    
    /// Dummy function for providing text as an NSAttributedString. This will need to be provided by outside DataSource.
    private func attributedString(forItemAt indexPath: IndexPath) -> NSAttributedString {
        let attributedText: NSAttributedString
        if indexPath.isRowZero, let text = RowAndColumnLabels.rowZero[safe: indexPath.item] {
            let attributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: Constants.RowZero.font, NSAttributedStringKey.foregroundColor: Constants.RowZero.color]
            attributedText = NSAttributedString(string: text, attributes: attributes)
        } else if indexPath.isColumnZero, let (title, author) = RowAndColumnLabels.columnZero[safe: indexPath.section] {
            let titleAttributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: Constants.ColumnZero.titleFont, NSAttributedStringKey.foregroundColor: Constants.ColumnZero.color]
            let authorAttributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: Constants.ColumnZero.authorFont, NSAttributedStringKey.foregroundColor: Constants.ColumnZero.color]
            let mutableAttributed = NSMutableAttributedString(string: title, attributes: titleAttributes)
            mutableAttributed.append(NSAttributedString(string: ", \(author)", attributes: authorAttributes))
            attributedText = mutableAttributed
        } else {
            let text = "Row \(indexPath.section), Column \(indexPath.item)"
            let attributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: Constants.Body.font, NSAttributedStringKey.foregroundColor: Constants.Body.color]
            attributedText = NSAttributedString(string: text, attributes: attributes)
        }
        return attributedText
    }
    
    /// Build the attributed strings for all known cells.
    private func attributedStringsForCells(sectionCount: Int, itemCount: Int) -> [IndexPath: NSAttributedString] {
        var attributedStringDictionary: [IndexPath: NSAttributedString] = [:]
        for section in 0..<sectionCount {
            for item in 0..<itemCount {
                let indexPath = IndexPath(item: item, section: section)
                attributedStringDictionary[indexPath] = attributedString(forItemAt: indexPath)
            }
        }
        return attributedStringDictionary
    }
    
    /// Precalculate all of the cell sizes for all known cells.
    private func calculatedCellSizes(sectionCount: Int, itemCount: Int) -> [IndexPath: CGSize] {
        var cellSizeDictionary: [IndexPath: CGSize] = [:]
        
        // Calculate height using bounding rect of attributed string with constraining width and height.
        func cellHeight(forAttributedText text: NSAttributedString, constrainedToWidth width: CGFloat) -> CGFloat {
            let size = text.boundingRect(with: CGSize(width: width, height: Constants.constrainedCellHeight), options: .usesLineFragmentOrigin, context: nil)
            return size.height.rounded(.up) + (Constants.verticalPadding * 2)
        }
        
        // Widths are fixed. Dummy this here for now. This will need to be provided by outside DataSource.
        func cellWidth(forItemAt item: Int) -> CGFloat {
            let width: CGFloat
            switch item {
            case 0:
                width = Constants.ColumnZero.width
            default:
                width = Constants.Body.width
            }
            return width
        }
        
        // For cell size we get the width with a single call (because width is fixed. For the cell height we must look at the
        // attributed strings for all cells in the same section (row).
        func cellSize(forItemAt indexPath: IndexPath) -> CGSize {
                
            // Even though we are only getting the height of a cell we need to get the maximum height of all cells in the row (section)
            // because the height is the same for all cells in a row.
            var maxHeight: CGFloat = 0
            for item in 0..<itemCount {
                let itemIndexPath = IndexPath(item: item, section: indexPath.section)
                let width = cellWidth(forItemAt: item)
                if let attributedText = cachedAttributedString[itemIndexPath] {
                    let height = cellHeight(forAttributedText: attributedText, constrainedToWidth: width - (Constants.verticalPadding * 2))
                    maxHeight = max(maxHeight, height)
                }
            }
            
            let width = cellWidth(forItemAt: indexPath.item)
            let height = max(maxHeight, Constants.minimumCellHeight)
            let size = CGSize(width: width, height: height)
            
            return size
        }

        for section in 0..<sectionCount {
            
            // Calculate the size of the leftmost cell first because this will fix the height for all cells in section (row).
            let leftmostCellIndexPath = IndexPath(item: 0, section: section)
            let leftmostCellSize = cellSize(forItemAt: leftmostCellIndexPath)
            cellSizeDictionary[leftmostCellIndexPath] = leftmostCellSize
            
            // Then we use that height for setting the size of all columns (items) in this section (row).
            let height = leftmostCellSize.height
            
            for item in 1..<itemCount {
                let itemIndexPath = IndexPath(item: item, section: section)
                let width = cellWidth(forItemAt: item)
                let size = CGSize(width: width, height: height)
                cellSizeDictionary[itemIndexPath] = size
            }
        }
        return cellSizeDictionary
    }
    
    // MARK: CollectionViewLayoutDelegate
    
    func cellSize(forItemAt indexPath: IndexPath) -> CGSize? {
        return cachedCellSize[indexPath]
    }

}

public extension IndexPath {
    var isRowZero: Bool {
        return (self.section == 0)
    }
    var isColumnZero: Bool {
        return (self.item == 0)
    }
}

public extension Collection {
    
    /// Returns the element at the specified index iff it is within bounds, otherwise nil.
    //  from: http://stackoverflow.com/questions/25329186/safe-bounds-checked-array-lookup-in-swift-through-optional-bindings
    public subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
