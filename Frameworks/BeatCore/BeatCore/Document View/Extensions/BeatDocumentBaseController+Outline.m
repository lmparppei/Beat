//
//  BeatDocumentBaseController+Outline.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import "BeatDocumentBaseController+Outline.h"

@implementation BeatDocumentBaseController (Outline)


#pragma mark - Outline update

- (void)outlineDidUpdateWithChanges:(OutlineChanges*)changes
{
    if (changes.hasChanges == false) return;
    
    // Redraw scene numbers
    for (OutlineScene* scene in changes.updated) {
        if (self.currentLine != scene.line) [self.layoutManager invalidateDisplayForCharacterRange:scene.line.textRange];
    }

    // Update outline views
    for (id<BeatSceneOutlineView> view in self.registeredOutlineViews) {
        [view reloadWithChanges:changes];
    }
    
    // Update plugin agent
    [(id<BeatPluginAgentInstance>)self.pluginAgent updatePluginsWithOutline:self.parser.outline changes:changes];
}

@end
