//
//  BeatDocumentBaseController+RegisteredViewsAndObservers.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.2.2025.
//

#import "BeatDocumentBaseController+RegisteredViewsAndObservers.h"

@implementation BeatDocumentBaseController (RegisteredViewsAndObservers)

/// Registers a normal editor view. They know if they are visible and can be reloaded both in sync and async.
- (void)registerEditorView:(id<BeatEditorView>)view
{
    if (self.registeredViews == nil) self.registeredViews = NSMutableSet.set;;
    [self.registeredViews addObject:view];
}

/// Reloads all editor views in background
- (void)updateEditorViewsInBackground
{
    for (id<BeatEditorView> view in self.registeredViews) {
        [view reloadInBackground];
    }
}

/// Registers a an editor view which displays outline data. Like usual editor views, they know if they are visible and can be reloaded both in sync and async.
- (void)registerSceneOutlineView:(id<BeatSceneOutlineView>)view
{
    if (self.registeredOutlineViews == nil) self.registeredOutlineViews = NSMutableSet.set;
    if (![self.registeredOutlineViews containsObject:view]) [self.registeredOutlineViews addObject:view];
}
/// Updates all outline views with given changes
- (void)updateOutlineViewsWithChanges:(OutlineChanges*)changes
{
    for (id<BeatSceneOutlineView>view in self.registeredOutlineViews) {
        [view reloadWithChanges:changes];
    }
}
/// Updates all outline views from scratch and in sync.
- (void)updateOutlineViews
{
    for (id<BeatSceneOutlineView> view in self.registeredOutlineViews) {
        [view reloadView];
    }
}

/// Registers an observer which checks when selection changes
- (void)registerSelectionObserver:(id<BeatSelectionObserver>)observer
{
    if (self.registeredSelectionObservers == nil) self.registeredSelectionObservers = NSMutableSet.set;
    [self.registeredSelectionObservers addObject:observer];
}

- (void)unregisterSelectionObserver:(id<BeatSelectionObserver>)observer
{
    [self.registeredSelectionObservers removeObject:observer];
}

/// Updates all selection observers with current selection
- (void)updateSelectionObservers
{
    for (id<BeatSelectionObserver>observer in self.registeredSelectionObservers) {
        [observer selectionDidChange:self.selectedRange];
    }
}

/// Registers a an editor view which hosts a plugin. Because plugins are separated into another framework, we need to have this weird placeholder protocol. One day I'll fix this.
- (void)registerPluginContainer:(id<BeatPluginContainerInstance>)view
{
    if (self.registeredPluginContainers == nil) self.registeredPluginContainers = NSMutableArray.new;
    [self.registeredPluginContainers addObject:(id<BeatPluginContainerInstance>)view];
}

- (void)registerPaginationBoundView:(id<BeatPaginationBoundOutlineView>)view
{
    if (self.registeredPaginationBoundViews == nil) self.registeredPaginationBoundViews = NSMutableArray.new;
    [self.registeredPaginationBoundViews addObject:view];
}

@end
