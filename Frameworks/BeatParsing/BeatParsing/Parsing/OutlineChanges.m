//
//  OutlineChanges.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 26.6.2023.
//

#import "OutlineChanges.h"

@implementation OutlineChanges
- (instancetype)init
{
    self = [super init];
    
    self.updated = NSMutableSet.new;
    self.removed = NSMutableSet.new;
    self.added = NSMutableSet.new;
    
    return self;
}
- (bool)hasChanges
{
    return (self.updated.count > 0 || self.removed.count > 0 || self.added.count > 0 || self.needsFullUpdate);
}
- (id)copy
{
    OutlineChanges* changes = OutlineChanges.new;
    changes.updated = self.updated;
    changes.removed = self.removed;
    changes.added = self.added;
    changes.needsFullUpdate = self.needsFullUpdate;
    
    return changes;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return self.copy;
}

@end
