//
//  UXKit
//
//  Copyright © 2016-2021 ZeeZide GmbH. All rights reserved.
//
#if os(macOS)
  import Cocoa
    
  @available(OSX 10.11, *)
  public typealias UXCollectionViewLayout           = NSCollectionViewLayout

  @available(OSX 10.11, *)
  public typealias UXCollectionViewFlowLayout       = NSCollectionViewFlowLayout

  @available(OSX 10.11, *)
  public typealias UXCollectionViewLayoutAttributes =
                     NSCollectionViewLayoutAttributes

  public typealias UXCollectionViewDataSource       = NSCollectionViewDataSource
  public typealias UXCollectionViewDelegate         = NSCollectionViewDelegate
  public typealias UXCollectionViewDelegateFlowLayout =
                     NSCollectionViewDelegateFlowLayout
  public typealias UXCollectionViewItem             = NSCollectionViewItem
#endif

