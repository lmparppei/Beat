//
//  BeatPasteboardItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.9.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BeatPasteboardItem : NSObject <NSCopying, NSPasteboardWriting, NSPasteboardReading, NSCoding>

@property (nonatomic) NSAttributedString *attrString;

- (id)initWithAttrString:(NSAttributedString*)string;
+ (NSString*)sanitizeString:(NSString*)string;
+ (NSString*)pasteboardType;
@end

