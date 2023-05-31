//
//  BeatPrintDialog.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.4.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <BeatCore/BeatEditorDelegate.h>

@interface BeatPrintDialog: NSWindowController
@property (weak) id<BeatEditorDelegate> documentDelegate;

- (IBAction)open:(id)sender;
- (IBAction)openForPDF:(id)sender;

- (void)loadPreview;

+ (BeatPrintDialog*)showForPDF:(id)delegate;
+ (BeatPrintDialog*)showForPrinting:(id)delegate;

@end
