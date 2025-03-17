//
//  BeatPlugin+Listeners.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 9.3.2025.
//

// NOTE: This header is public because we need to access some of the listener methods from the actual app

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol BeatTextChangeObserver;

@protocol BeatPluginListenerExports <JSExport>

- (void)onTextChange:(JSValue*)updateMethod;

- (void)setSelectionUpdate:(JSValue *)updateMethod;
- (void)onSelectionChange:(JSValue*)updateMethod;

- (void)onOutlineChange:(JSValue*)updateMethod;
- (void)onSceneIndexUpdate:(JSValue*)updateMethod;

- (void)onDocumentBecameMain:(JSValue*)updateMethod;
- (void)onSceneHeadingAutocompletion:(JSValue*)callback;
- (void)onCharacterAutocompletion:(JSValue*)callback;
- (void)onPreviewFinished:(JSValue*)updateMethod;
- (void)onPaginationFinished:(JSValue*)updateMethod;
- (void)onDocumentSaved:(JSValue*)updateMethod;
- (void)onEscape:(JSValue*)updateMethod;

- (void)onNotepadChange:(JSValue*)updateMethod;

@end

@interface BeatPlugin (Listeners) <BeatPluginListenerExports>

#pragma mark Public event listener methods

- (void)documentDidBecomeMain;
- (void)documentDidResignMain;
- (void)documentWasSaved;
- (void)escapePressed;

- (void)updateText:(NSRange)range;
- (void)updateSelection:(NSRange)selection;
- (void)updateOutline:(OutlineChanges*)changes;
- (void)updateSceneIndex:(NSInteger)sceneIndex;

- (void)previewDidFinish:(BeatPagination*)pagination indices:(NSIndexSet*)changedIndices;

- (void)clearObservables;

#pragma mark Autocompletion callbacks

- (NSArray<NSString*>*)completionsForSceneHeadings; /// Called if the resident plugin has a callback for scene heading autocompletion
- (NSArray<NSString*>*)completionsForCharacters; /// Called if the resident plugin has a callback for character cue autocompletion

@end

