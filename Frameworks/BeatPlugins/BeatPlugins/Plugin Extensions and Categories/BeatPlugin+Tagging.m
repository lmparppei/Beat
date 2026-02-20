//
//  BeatPlugin+Tagging.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 12.2.2026.
//

#import "BeatPlugin+Tagging.h"

@implementation BeatPlugin (Tagging)

#pragma mark - Tagging interface

- (BeatTagging *)tagging
{
    return self.delegate.tagging;
}

- (NSArray*)availableTags
{
    return BeatTagging.categories;
}

- (NSDictionary*)tagsForScene:(OutlineScene *)scene
{
    return [self.delegate.tagging tagsForScene:scene];
}

@end
