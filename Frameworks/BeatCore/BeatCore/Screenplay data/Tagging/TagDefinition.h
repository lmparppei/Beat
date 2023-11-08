//
//  TagDefinition.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatCore/BeatTagging.h>

@class BeatTagging;

NS_ASSUME_NONNULL_BEGIN

@protocol TagDefinitionExports <JSExport>
@property (nonatomic, readonly) NSString *defId;
@property (nonatomic, readonly) NSString *name;
- (NSString*)typeAsString;
- (NSDictionary*)serialized;
//- (NSString*)typeAsString;
//- (bool)hasId:(NSString*)tagId;
@end

@interface TagDefinition : NSObject <TagDefinitionExports, NSCopying, NSCoding>
@property (nonatomic) BeatTagType type;
@property (nonatomic) NSString *defId;
@property (nonatomic) NSString *name;
@property (nonatomic) NSMutableIndexSet *indices;
- (NSString*)typeAsString;
- (instancetype)initWithName:(NSString*)name type:(BeatTagType)type identifier:(NSString*)tagId; 
- (bool)hasId:(NSString*)tagId;
- (NSDictionary*)serialized;
@end

NS_ASSUME_NONNULL_END
