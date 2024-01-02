//
//  PreviewViewController.h
//  BeatQuickLook
//
//  Created by Lauri-Matti Parppei on 27.5.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class BeatDocument;
@class BeatFonts;

@interface PreviewViewController : NSViewController

@property (nonatomic) BeatDocument* document;
@property (nonatomic) NSRange selectedRange;
@property (nonatomic) BeatFonts* fonts;

@end
