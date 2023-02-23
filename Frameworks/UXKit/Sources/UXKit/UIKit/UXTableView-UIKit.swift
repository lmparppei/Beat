//
//  UXKit
//
//  Copyright © 2016-2021 ZeeZide GmbH. All rights reserved.
//
#if !os(macOS)
  import UIKit
  
  public typealias UXTableView          = UITableView

  /**
   * This is the type of the view a tableview datasource is expected to return
   * (when creating a view for a row).
   *
   * On AppKit, this can be any view, but on UIKit, it *must* be a
   * UITableViewCell.
   *
   * Also note that on AppKit there is a `NSTableCellView`. This is *not* the
   * same like the `UITableViewCell`! The `NSTableCellView` doesn't create its
   * contents, but purely serves as an outlet holder for IB.
   *
   * To workaround that, we provide an own `NSTableViewCell` which tries to
   * mirror what `UITableViewCell` does.
   */
  public typealias UXTableViewCellType  = UITableViewCell

  /**
   * A concrete view which you can use in a view datasource. It provides an
   * image, label, detail-label, and a set of different styles.
   *
   * On iOS, this is builtin via `UITableViewCell`, and on macOS we provide
   * an own class for that (`NSTableViewCell`).
   */
  public typealias UXTableViewCell      = UITableViewCell // same on iOS

  public typealias UXTableViewCellStyle = UITableViewCell.CellStyle
  public extension UITableView.RowAnimation {
    static var effectFade = UITableView.RowAnimation.fade
    static var effectGap  = UITableView.RowAnimation.middle // TBD
    static var slideUp    = UITableView.RowAnimation.top
    static var slideDown  = UITableView.RowAnimation.bottom
    static var slideLeft  = UITableView.RowAnimation.left
    static var slideRight = UITableView.RowAnimation.right
  }

  public protocol UXTableViewCellInit : AnyObject {
    init(style: UXTableViewCellStyle, reuseIdentifier: String?)
    func prepareForReuse()
  }

  public extension UITableView {
    // TBD: maybe we should hide those and just use the iOS versions
    
    func insertRows(at indexes: IndexSet,
                    withAnimation ao : UITableView.RowAnimation = .automatic)
    {
      // fade, right, left, top, bottom, none, middle, automatic
      insertRows(at: indexes.map { IndexPath(row: $0, section: 0)}, with: ao)
    }
    
    func removeRows(at indexes: IndexSet,
                    withAnimation ao : UITableView.RowAnimation = .automatic)
    {
      deleteRows(at: indexes.map { IndexPath(row: $0, section: 0)}, with: ao)
    }
    
    func reloadData(forRowIndexes rows: IndexSet, columnIndexes cols: IndexSet)
    {
      reloadRows(at: rows.map { IndexPath(row: $0, section: 0)},
                 with: .none) // This: flickrs too much: .automatic
    }
  }

  public extension UITableView {
    
    /// Careful: Unlike on macOS this only works for single section table views.
    var selectedRow : Int { // macOS API
      assert((dataSource?.numberOfSections?(in: self) ?? 0) < 2)
      guard let ip = indexPathForSelectedRow else { return NSNotFound }
      return ip.row
    }
    
    var numberOfSelectedRows : Int {
      return indexPathsForSelectedRows?.count ?? 0
    }
    
    /// Careful: Unlike on macOS this only works for single section table views.
    func isRowSelected(_ row: Int) -> Bool {
      assert((dataSource?.numberOfSections?(in: self) ?? 0) < 2)
      guard let ip = indexPathForSelectedRow else { return false }
      return ip.row == row
    }
    
    func deselectAll(_ sender: Any?) {
      guard let ips = indexPathsForSelectedRows else { return }
      for ip in ips {
        deselectRow(at: ip, animated: false)
      }
    }

    func deselectRow(_ row: Int) {
      deselectRow(at: IndexPath(row: row, section: 0), animated: true)
    }
    
    func selectRowIndexes(_ rows: IndexSet, byExtendingSelection extend: Bool) {
      let oldSelection =
        IndexSet((indexPathsForSelectedRows ?? []).lazy.map { $0.row })
      
      if !extend {
        for oldRow in oldSelection {
          guard !rows.contains(oldRow) else { continue }
          deselectRow(at: IndexPath(row: oldRow, section: 0), animated: true)
        }
      }
      
      for newRow in rows {
        guard !oldSelection.contains(newRow) else { continue }
        selectRow(at: IndexPath(row: newRow, section: 0), animated: true,
                  scrollPosition: .none)
      }
    }
  }

  public extension UITableView {
    
    /// AppKit compatibility version for `dequeueReusableCell`. The `owner` is
    /// the owner of an eventual nib (don't) and not used here.
    func makeView(withIdentifier id: UXUserInterfaceItemIdentifier, owner: Any?)
         -> UITableViewCell?
    {
      return dequeueReusableCell(withIdentifier: id)
    }
  }
#endif // !os(macOS)
