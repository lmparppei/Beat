//
//  TagDefinition.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.3.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BeatTagging.h"

@class BeatTagging;

NS_ASSUME_NONNULL_BEGIN

@interface TagDefinition : NSObject
@property (nonatomic) BeatTagType type;
@property (nonatomic) NSString *defId;
@property (nonatomic) NSString *name;
@property (nonatomic) NSMutableIndexSet *indices;
- (NSString*)typeAsString;
- (instancetype)initWithName:(NSString*)name type:(BeatTagType)type identifier:(NSString*)tagId;
- (bool)hasId:(NSString*)tagId;
@end

NS_ASSUME_NONNULL_END
