//
//  BeatPrint.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.10.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PrintView.h"

@class Document;

/*
typedef enum : NSUInteger {
	BeatA4 = 0,
	BeatUSLetter
} BeatPaperSize;
 */

NS_ASSUME_NONNULL_BEGIN

@class Document;
@interface BeatPrint : NSObject <PrintViewDelegate>
@property (weak) Document* document;

- (IBAction)open:(id)sender;
- (IBAction)openForPDF:(id)sender;

// Move all PrintView values here
// @property (nonatomic) NSString* header;

@end

NS_ASSUME_NONNULL_END
