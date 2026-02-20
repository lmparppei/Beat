//
//  BeatPlugin+Tagging.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 12.2.2026.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatCore/BeatTagging.h>

@protocol BeatPluginTaggingExports <JSExport>

/// Returns all tags in the scene
- (NSDictionary*)tagsForScene:(OutlineScene*)scene;
/// Returns all available tag names
- (NSArray*)availableTags;

@end

@interface BeatPlugin (Tagging) <BeatPluginTaggingExports>

@end

