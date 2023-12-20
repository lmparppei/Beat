//
//  BeatTemplateCell.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 6.7.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatTemplateCell:UICollectionViewCell {
	@objc @IBOutlet var icon:UIImageView?
	@objc @IBOutlet var title:UILabel?
	@objc @IBOutlet var labelView:UIView?
	@objc @IBOutlet var templateDescription:UILabel?
	@objc var url:URL?
	@objc var product:String?
}
