//
//  NSSound.swift
//  UXKit
//
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

#if !os(macOS) && canImport(AVFoundation)

  import class Foundation.Bundle
  import class AVFoundation.AVAudioPlayer

  public typealias NSSound = AVAudioPlayer

  public extension AVAudioPlayer {
    
    /// macOS compat shim to simulate `NSSound`
    convenience init?(named name: String) {
      guard let url = Bundle.main.url(forResource: name,
                                      withExtension: nil) else
      {
        return nil
      }
      do {
        try self.init(contentsOf: url)
      }
      catch {
        return nil
      }
    }
  }

#endif
