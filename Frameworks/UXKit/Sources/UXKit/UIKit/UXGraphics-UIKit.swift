//
//  UXKit
//
//  Copyright © 2016-2021 ZeeZide GmbH. All rights reserved.
//
#if !os(macOS)
  import Foundation
  import UIKit
  
  public typealias UXFloat            = CGFloat

  public typealias UXColor            = UIColor

  public typealias UXBezierPath       = UIBezierPath
  public typealias UXRect             = CGRect
  public typealias UXPoint            = CGPoint
  public typealias UXSize             = CGSize

  public typealias UXImage            = UIImage
  
  public typealias UXEdgeInsets       = UIEdgeInsets

  @inlinable
  public func UXEdgeInsetsMake(_ top    : CGFloat, _ left  : CGFloat,
                               _ bottom : CGFloat, _ right : CGFloat)
              -> UXEdgeInsets
  {
    return UXEdgeInsets(top: top, left: left, bottom: bottom, right: right)
  }

  public extension UXColor {
    
    /// macOS compat, using `.label` on iOS 13+ (dynamic), `.black` before.
    @inlinable
    static var textColor : UXColor {
      if #available(iOS 13, *) { return UXColor.label }
      else                     { return UXColor.black }
    }
  }

  public extension CGColor {
    
    // iOS has no CGColor(gray:alpha:)
    @inlinable
    static func new(gray: CGFloat, alpha: CGFloat) -> CGColor {
      return UIColor(red: gray, green: gray, blue: gray, alpha: alpha).cgColor
    }
  }

  public extension UXImage {
    
    typealias Name = String // use on older macOS bindings
    
    @inlinable
    static var applicationIconImage: UXImage? {
      guard let icon = (Bundle.main.infoDictionary?["CFBundleIconFiles"]
                       as? [ String ])?.first else { return nil }
      return UXImage(named: icon)
    }
  }

  public extension Bundle {
    
    @inlinable
    func image(forResource name: UXImage.Name) -> UXImage? {
      return UXImage(named: name, in: self, compatibleWith: nil)
    }
  }

  public extension UIImage {
    
    /// macOS `NSImage` compatibility method.
    /// This fetches the URL synchronously, i.e. the method will block until
    /// the result is available.
    /// Hence avoid using it for anything but file URLs.
    @inlinable
    convenience init?(contentsOf url: URL) {
      if url.isFileURL {
        self.init(contentsOfFile: url.path)
      }
      else {
        var fetchedData : Data?
        let group = DispatchGroup()
        group.enter()
        URLSession.shared.dataTask(with: url) { data, res, error in
          if let error = error {
            print("ERROR: failed to fetch image:", url.absoluteString, error)
          }
          fetchedData = data
          group.leave()
        }
        group.wait()
        
        guard let data = fetchedData else { return nil }
        
        self.init(data: data)
      }
    }
    
    /// macOS `NSImage` compatibility method, but avoid using it in production
    /// code.
    /// The difference to `init?(contentsOf:)` is that an `NSImage` that gets
    /// archived only stores the name of the image, not the actual contents.
    @available(*, deprecated, message: "Use `init(contentsOfFile:)`")
    convenience init(byReferencing url: URL) {
      self.init(contentsOfFile: url.path)!
    }
  }
#endif // !os(macOS)
