//
//  BeatPasteboardItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.9.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BeatPasteboardItem : NSObject <NSPasteboardWriting, NSCopying, NSPasteboardReading, NSCoding, NSSecureCoding>

@property (nonatomic) NSAttributedString *attrString;
@property (nonatomic) NSDictionary<NSString*, NSArray<NSValue*>*>* attrRanges;

- (id)initWithAttrString:(NSAttributedString*)string;
+ (NSString*)sanitizeString:(NSString*)string;
+ (NSString*)pasteboardType;
@end

