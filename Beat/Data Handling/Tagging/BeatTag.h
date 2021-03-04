//
//  BeatTag.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.3.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BeatTagging.h"
#import "TagDefinition.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatTag : NSObject
@property (nonatomic) NSRange range;
@property (nonatomic) BeatTagType type;
@property (nonatomic) NSString *defId;
@property (nonatomic) NSString *tagId;
@property (nonatomic) TagDefinition *definition;
+ (BeatTag*)withDefinition:(TagDefinition*)def;
- (instancetype)initWithDefinition:(TagDefinition*)def;
- (NSString*)key;
- (NSString*)typeAsString;
@end

NS_ASSUME_NONNULL_END
