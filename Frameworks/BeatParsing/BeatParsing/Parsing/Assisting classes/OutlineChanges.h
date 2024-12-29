//
//  OutlineChanges.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 26.6.2023.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

@class OutlineScene;

typedef NS_ENUM(NSUInteger, OutlineChangeType) {
    none = 0,
    SceneAdded,
    SceneRemoved
};

@protocol OutlineChangesExports <JSExport>
@property (readonly, nonatomic) NSMutableSet<OutlineScene*>* added;
@property (readonly, nonatomic) NSMutableSet<OutlineScene*>* removed;
@property (readonly, nonatomic) NSMutableSet<OutlineScene*>* updated;
@property (readonly, nonatomic) bool needsFullUpdate;
- (bool)hasChanges;
@end

@interface OutlineChanges:NSObject <NSCopying, OutlineChangesExports>
@property (nonatomic) NSMutableSet<OutlineScene*>* added;
@property (nonatomic) NSMutableSet<OutlineScene*>* removed;
@property (nonatomic) NSMutableSet<OutlineScene*>* updated;
@property (nonatomic) bool needsFullUpdate;
- (bool)hasChanges;
@end
