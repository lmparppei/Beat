//
//  BeatDocumentBaseController+AdditionalData.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 26.6.2025.
//
/*
 
 Handler for additional data which you might want to store for some reason or another.
 
 */

#import "BeatDocumentBaseController+AdditionalData.h"

@implementation BeatDocumentBaseController (AdditionalData)

- (void)setAdditionalData:(id)data key:(NSString*)key
{
    if (self.additionalData == nil) self.additionalData = NSMapTable.strongToWeakObjectsMapTable;
    if (data != nil && key != nil)
        [self.additionalData setValue:data forKey:key];
    else
        NSLog(@"WARNING: You tried setting nil value to additional data map");
}

- (id _Nullable)getAdditionalDataWithKey:(NSString*)key
{
    if (self.additionalData == nil) return nil;
    return [self.additionalData valueForKey:key];
}

@end
