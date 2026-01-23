//
//  BeatDocumentBaseController+RegisteredViewsAndObservers.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.2.2025.
//

#import <BeatCore/BeatCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatDocumentBaseController (RegisteredViewsAndObservers)

/// Registers a normal editor view. They know if they are visible and can be reloaded both in sync and async.
- (void)registerEditorView:(id<BeatEditorView>)view;

/// Reloads all editor views in background
- (void)updateEditorViewsInBackground;

/// Registers a an editor view which displays outline data. Like usual editor views, they know if they are visible and can be reloaded both in sync and async.
- (void)registerSceneOutlineView:(id<BeatSceneOutlineView>)view;

/// Updates all outline views with given changes
- (void)updateOutlineViewsWithChanges:(OutlineChanges*)changes;

/// Updates all outline views from scratch and in sync.
- (void)updateOutlineViews;

/// Registers an outline view which requires pagination info
- (void)registerPaginationBoundView:(id<BeatPaginationBoundOutlineView>)view;

/// Registers an observer which checks when selection changes
- (void)registerSelectionObserver:(id<BeatSelectionObserver>)observer;
- (void)unregisterSelectionObserver:(id<BeatSelectionObserver>)observer;
/// Updates all selection observers with current selection
- (void)updateSelectionObservers;

/// Registers a an editor view which hosts a plugin. Because plugins are separated into another framework, we need to have this weird placeholder protocol. One day I'll fix this.
- (void)registerPluginContainer:(id<BeatPluginContainerInstance>)view;


@end

NS_ASSUME_NONNULL_END
