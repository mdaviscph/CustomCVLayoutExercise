//
//  CollectionViewLayout.swift
//
//  Copyright © 2017 Mike Davis. All rights reserved.
//

import UIKit

protocol CollectionViewLayoutDelegate: class {
    func cellSize(forItemAt indexPath: IndexPath) -> CGSize?
}

final class CollectionViewLayout: UICollectionViewLayout {

    private struct Constants {
        static let defaultCellWidth: CGFloat = 100
        static let defaultCellHeight: CGFloat = 50
    }
    /// Retain the layout attributes for each cell to improve performance. The frame.origin in these
    /// attributes is used to prevent the first row and column from scrolling.
    private var cellAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    
    /// Used to retain a calculated collectionViewContentSize.
    private var contentSize: CGSize = .zero
    
    weak var layoutDelegate: CollectionViewLayoutDelegate?
    
    override var collectionViewContentSize: CGSize {
        return contentSize
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = cellAttributes[indexPath]
        assert(attributes != nil, "IndexPath for layoutAttributesForItem is unexpected!")
        return attributes
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var result: [UICollectionViewLayoutAttributes] = []
        for attributes in cellAttributes.values {
            if rect.intersects(attributes.frame) {
                result.append(attributes)
            }
        }
        return result
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }

    // The UICollectionViewLayoutAttributes are created for all cells the first time this function is called.
    // The layout attributes are saved in a dictionary that is keyed using the IndexPath. The frame for each cell
    // is created with an origin based on a fixed cell width and height. Once the user start scrolling and this
    // method is called due to the layout being invalid, the origin of the frame is adjusted such that the first
    // row (section) and column (item) do not scroll. The zIndex is used so the the first row and column show
    // over top of the other cells.
    override func prepare() {
        guard let collectionView = collectionView else { return }
        
        var contentWidth: CGFloat = 0
        var contentHeight: CGFloat = 0
        let xOffset = collectionView.contentOffset.x
        let yOffset = collectionView.contentOffset.y
        
        let sectionCount = collectionView.numberOfSections
        
        for section in 0..<sectionCount {
            let cellHeight = layoutDelegate?.cellSize(forItemAt: IndexPath(item: 0, section: section))?.height ?? Constants.defaultCellHeight
            var yPos = contentHeight
            contentHeight += cellHeight
            
            var sectionContentWidth: CGFloat = 0
            let itemCount = collectionView.numberOfItems(inSection: section)
            
            for item in 0..<itemCount {
                let indexPath = IndexPath(item: item, section: section)
                let cellWidth = layoutDelegate?.cellSize(forItemAt: indexPath)?.width ?? Constants.defaultCellWidth
                var xPos = sectionContentWidth
                sectionContentWidth += cellWidth
                contentWidth = max(contentWidth, sectionContentWidth)

                let attributes: UICollectionViewLayoutAttributes
                if let existingAttributes = cellAttributes[indexPath] {
                    attributes = existingAttributes
                } else {
                    attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                    switch (section, item) {
                    case (0, 0):
                        attributes.zIndex = 4
                    case (0, _):
                        attributes.zIndex = 3
                    case (_, 0):
                        attributes.zIndex = 2
                    default:
                        attributes.zIndex = 1
                    }
                }
                // First row (section) and first column (item) do not scroll.
                if section == 0 {
                    if item == 0 {
                        xPos = xOffset
                    }
                    yPos = yOffset
                } else if item == 0 {
                    xPos = xOffset
                }
                
                attributes.frame = CGRect(x: xPos, y: yPos, width: cellWidth, height: cellHeight)
                cellAttributes[indexPath] = attributes
            }
        }

        contentSize = CGSize(width: contentWidth, height: contentHeight)
    }
    
    // Use the contentOffset to end scrolling on the boundary of cells. This relies on the cell size to have a consistent row (section)
    // height and column (item) width. Note that indexPathForItem at:CGPoint is not accurate here and occassionally returns [0,0].
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {

        func xPosOnCellBoundary(for xPos: CGFloat) -> CGFloat? {
            guard let collectionView = collectionView, let delegate = layoutDelegate else { return nil }
            var totalWidth: CGFloat = 0
            for item in 0..<collectionView.numberOfItems(inSection: 0) {
                guard let width = delegate.cellSize(forItemAt: IndexPath(item: item, section: 0))?.width else { continue }
                if xPos < totalWidth + (width / 2) {
                    return totalWidth
                }
                totalWidth += width
            }
            return nil
        }
        
        func yPosOnCellBoundary(for yPos: CGFloat) -> CGFloat? {
            guard let collectionView = collectionView, let delegate = layoutDelegate else { return nil }
            var totalHeight: CGFloat = 0
            for section in 0..<collectionView.numberOfSections {
                guard let height = delegate.cellSize(forItemAt: IndexPath(item: 0, section: section))?.height else { continue }
                if yPos < totalHeight + (height / 2) {
                    return totalHeight
                }
                totalHeight += height
            }
            return nil
        }
        
        // Using the contentOffset to find a cell requires us to adjust for the fixed row and column before we find the upper-left-most 
        // cell that we use to adjust the final scrolling position and then after to adjust the returned contentOffset.
        // TODO: Verify that this works for flicks. Handle scrolling to very last row and column.
        guard let delegate = layoutDelegate,
            let originCellSize = delegate.cellSize(forItemAt: IndexPath(item: 0, section: 0)),
            let xPos = xPosOnCellBoundary(for: proposedContentOffset.x + originCellSize.width),
            let yPos = yPosOnCellBoundary(for: proposedContentOffset.y + originCellSize.height) else { return proposedContentOffset }
        return CGPoint(x: xPos - originCellSize.width, y: yPos - originCellSize.height)
    }
    
}
