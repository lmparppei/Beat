//
//  BeatTagItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.2.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BeatTagging.h"
#import "Line.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatTagItem : NSObject

@property (nonatomic) BeatTagType type;
@property (nonatomic) NSString *name;
@property (nonatomic) NSMutableIndexSet *indices;
@property (weak) NSMutableArray *lines;
+ (BeatTagItem*)withString:(NSString*)string type:(BeatTagType)type range:(NSRange)range;

-(NSColor*)color;
- (NSString*)key;
- (void)addRange:(NSRange)range;
- (NSArray*)ranges;
@end

NS_ASSUME_NONNULL_END
