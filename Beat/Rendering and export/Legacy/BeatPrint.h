//
//  BeatPrint.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.10.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PrintView.h"
#import "BeatEditorDelegate.h"

@class Document;

NS_ASSUME_NONNULL_BEGIN

//@class Document;
@interface BeatPrint: NSObject <PrintViewDelegate>
@property (weak) id<BeatEditorDelegate> document;
//@property (weak) Document* document;

- (IBAction)open:(id)sender;
- (IBAction)openForPDF:(id)sender;

- (void)loadPreview;

// Move all PrintView values here
// @property (nonatomic) NSString* header;

@end

NS_ASSUME_NONNULL_END
