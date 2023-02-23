//
//  UXKit
//
//  Copyright © 2016-2019 ZeeZide GmbH. All rights reserved.
//
#if !os(macOS)
  import UIKit
  
  public typealias UXCollectionViewLayout           = UICollectionViewLayout
  public typealias UXCollectionViewFlowLayout       = UICollectionViewFlowLayout
  public typealias UXCollectionViewLayoutAttributes =
                       UICollectionViewLayoutAttributes
  public typealias UXCollectionViewDataSource       = UICollectionViewDataSource
  public typealias UXCollectionViewDelegate         = UICollectionViewDelegate
  public typealias UXCollectionViewDelegateFlowLayout =
                       UICollectionViewDelegateFlowLayout
  public typealias UXCollectionViewItem             = UICollectionViewCell

  
  public extension UICollectionView {
    
    var isSelectable : Bool { // Cocoa compat
      set { allowsSelection = newValue }
      get { return allowsSelection }
    }
    
    var selectionIndexPaths : [ IndexPath ] {
      return indexPathsForSelectedItems ?? []
    }
    
  }
#endif // !os(macOS)
