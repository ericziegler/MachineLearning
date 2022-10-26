//
//  UIKitExtensions.swift
//  MachineLearning
//
//  Created by Eric Ziegler on 1/5/22.
//

import UIKit

// MARK: - TopAlignedLabel

class TopAlignedLabel: UILabel {

    override func drawText(in rect: CGRect) {
        if let stringText = text, let font = font {
            let stringTextAsNSString = stringText as NSString
            let labelStringSize = stringTextAsNSString.boundingRect(with: CGSize(width: self.frame.width,height: CGFloat.greatestFiniteMagnitude),
                                                                    options: NSStringDrawingOptions.usesLineFragmentOrigin,
                                                                    attributes: [NSAttributedString.Key.font: font],
                                                                    context: nil).size
            super.drawText(in: CGRect(x:0,y: 0,width: self.frame.width, height:ceil(labelStringSize.height)))
        } else {
            super.drawText(in: rect)
        }
    }

}
