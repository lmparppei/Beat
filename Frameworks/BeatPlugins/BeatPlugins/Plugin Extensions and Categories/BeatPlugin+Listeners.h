//
//  BeatPlugin+Listeners.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 9.3.2025.
//

// NOTE: This header is public because we need to access some of the listener methods from the actual app

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol BeatPluginListenerExports <JSExport>

- (void)onTextChange:(JSValue* _Nullable)updateMethod;

- (void)setSelectionUpdate:(JSValue* _Nullable)updateMethod;
- (void)onSelectionChange:(JSValue* _Nullable)updateMethod;

- (void)onOutlineChange:(JSValue* _Nullable)updateMethod;
- (void)onSceneIndexUpdate:(JSValue* _Nullable)updateMethod;

- (void)onDocumentBecameMain:(JSValue* _Nullable)updateMethod;
- (void)onSceneHeadingAutocompletion:(JSValue* _Nullable)callback;
- (void)onCharacterAutocompletion:(JSValue* _Nullable)callback;
- (void)onPreviewFinished:(JSValue* _Nullable)updateMethod;
- (void)onPaginationFinished:(JSValue* _Nullable)updateMethod;
- (void)onDocumentSaved:(JSValue* _Nullable)updateMethod;
- (void)onEscape:(JSValue* _Nullable)updateMethod;

- (void)onNotepadChange:(JSValue* _Nullable)updateMethod;

@end

@protocol BeatTextChangeObserver;

@interface BeatPlugin (Listeners) <BeatPluginListenerExports, BeatTextChangeObserver>

#pragma mark Public event listener methods

- (void)documentDidBecomeMain;
- (void)documentDidResignMain;
- (void)documentWasSaved;
- (void)escapePressed;

- (void)updateText:(NSRange)range;
- (void)updateSelection:(NSRange)selection;
- (void)updateOutline:(OutlineChanges* _Nullable)changes;
- (void)updateSceneIndex:(NSInteger)sceneIndex;

- (void)previewDidFinish:(BeatPagination* _Nullable)operation indices:(NSIndexSet* _Nullable)indices;

- (void)clearObservables;

#pragma mark Autocompletion callbacks

- (NSArray<NSString*>* _Nullable)completionsForSceneHeadings; /// Called if the resident plugin has a callback for scene heading autocompletion
- (NSArray<NSString*>* _Nullable)completionsForCharacters; /// Called if the resident plugin has a callback for character cue autocompletion

@end

