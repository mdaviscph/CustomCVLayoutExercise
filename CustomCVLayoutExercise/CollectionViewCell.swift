//
//  CollectionViewCell.swift
//
//  Copyright © 2017 Mike Davis. All rights reserved.
//

import UIKit

@IBDesignable
class CollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var detailLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.lightGray.cgColor
    }
}
