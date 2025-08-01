//
//  BeatPlugin+Listeners.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 9.3.2025.
//

#import "BeatPlugin+Listeners.h"
#import <BeatPlugins/BeatPlugins-Swift.h>
#import "BeatPlugin+Menus.h"

@interface BeatPlugin ()
@end

@implementation BeatPlugin (Listeners)

#pragma mark - Resident plugin listeners

// This mess needs an update.
// Make a custom class for listeners, so they can be disabled with changing a property rather than using the endless amounts of booleans (which we're currently doing)
// Note on a train back to Helsinki after a very dark and horrible weekend in 2025: We anyway need to support the booleans and these setters, so I'm not sure if that's a good idea. It will be just an enum mess.

/** Creates a listener for changes in editor text.
 - note:When text is changed, selection will change, too. Avoid creating infinite loops by listening to both changes.
 */
- (void)onTextChange:(JSValue*)updateMethod
{
    [self setUpdateText:updateMethod];
}
- (void)setUpdateText:(JSValue *)updateMethod
{
    // Save callback
    self.updateTextMethod = updateMethod;
    [self makeResident];
}
- (void)updateText:(NSRange)range {
    if (self.updateTextMethod == nil || self.updateTextMethod.isNull) return;
    if (!self.onTextChangeDisabled) [self.updateTextMethod callWithArguments:@[@(range.location), @(range.length)]];
}

/// Creates a listener for changing selection in editor.
- (void)onSelectionChange:(JSValue*)updateMethod
{
    [self setSelectionUpdate:updateMethod];
}
- (void)setSelectionUpdate:(JSValue *)updateMethod
{
    // Save callback for selection change update
    self.updateSelectionMethod = updateMethod;
    
    [self makeResident];
}
- (void)updateSelection:(NSRange)selection
{
    if (!self.updateSelectionMethod || [self.updateSelectionMethod isNull]) return;
    if (!self.onSelectionChangeDisabled) [self.updateSelectionMethod callWithArguments:@[@(selection.location), @(selection.length)]];
}

/// Creates a listener for changes in outline.
- (void)onOutlineChange:(JSValue*)updateMethod
{
    [self setOutlineUpdate:updateMethod];
}
- (void)setOutlineUpdate:(JSValue *)updateMethod
{
    // Save callback for selection change update
    self.updateOutlineMethod = updateMethod;
    
    [self makeResident];
}
- (void)updateOutline:(OutlineChanges*)changes
{
    if (!self.updateOutlineMethod || [self.updateOutlineMethod isNull]) return;
    if (!self.onOutlineChangeDisabled) [self.updateOutlineMethod callWithArguments:@[changes]];
}

/// Creates a listener for selecting a new scene.
- (void)onSceneIndexUpdate:(JSValue*)updateMethod
{
    [self setSceneIndexUpdate:updateMethod];
}
- (void)setSceneIndexUpdate:(JSValue*)updateMethod
{
    // Save callback for selection change update
    self.updateSceneMethod = updateMethod;
    [self makeResident];
}
- (void)updateSceneIndex:(NSInteger)sceneIndex
{
    if (!self.onSceneIndexUpdateDisabled) [self.updateSceneMethod callWithArguments:@[@(sceneIndex)]];
}

/// Creates a listener for escape key
- (void)onEscape:(JSValue*)updateMethod
{
    self.escapeMethod = updateMethod;
    [self makeResident];
}
- (void)escapePressed
{
    if (self.escapeMethod && !self.escapeMethod.isNull) [self.escapeMethod callWithArguments:nil];
}

- (void)onNotepadChange:(JSValue*)updateMethod
{
#if TARGET_OS_OSX
    [self addObservedTextView:(id<BeatTextChangeObservable>)self.delegate.notepad method:updateMethod];
#endif
}

- (void)updateListener:(JSValue*)listener
{
    if (listener && !listener.isNull) [listener callWithArguments:nil];
}

/// This is the modern way to observe text changes in *any* objects
- (void)addObservedTextView:(id<BeatTextChangeObservable>)object method:(JSValue*)method
{
    if (self.observedTextViews == nil) self.observedTextViews = NSMutableDictionary.new;
    NSValue* val = [NSValue valueWithNonretainedObject:object];
    self.observedTextViews[val] = method;
    [object addTextChangeObserver:self];
}

- (void)observedTextDidChange:(id<BeatTextChangeObservable>)object
{
    [self.observedTextViews[[NSValue valueWithNonretainedObject:object]] callWithArguments:nil];
}

- (void)clearObservables
{
    for (NSValue* val in self.observedTextViews.allKeys) {
        id<BeatTextChangeObservable> object = val.nonretainedObjectValue;
        [object removeTextChangeObserver:self];
    }
    
    [self.observedTextViews removeAllObjects];
    self.observedTextViews = nil;
}


/// Creates a listener for the window becoming main.
- (void)onDocumentBecameMain:(JSValue*)updateMethod {
    self.documentDidBecomeMainMethod = updateMethod;
    [self makeResident];
}

- (void)documentDidBecomeMain {
    [self.documentDidBecomeMainMethod callWithArguments:nil];
    #if !TARGET_OS_IOS
    [self refreshMenus];
    #endif
}
- (void)documentDidResignMain {
    #if !TARGET_OS_IOS
    [self refreshMenus];
    #endif
}

/// Creates a listener for when preview was updated.
- (void)onPreviewFinished:(JSValue*)updateMethod {
    self.updatePreviewMethod = updateMethod;
    [self makeResident];
}
/// This is an alias for onPreviewFinished
- (void)onPaginationFinished:(JSValue*)updateMethod {
    [self onPreviewFinished:updateMethod];
}

/// - note: This is shown to be duplicate, but this is not the case. This is some unfortunate spaghetti caused by the placeholder `PluginInstace` protocol, as `BeatCore` is a separate framework from the plugins.
- (void)previewDidFinish:(BeatPagination*)pagination indices:(NSIndexSet*)changedIndices
{
    if (self.onPreviewFinishedDisabled) return;
    
    NSMutableArray<NSNumber*>* indices = NSMutableArray.new;
    [changedIndices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        [indices addObject:@(idx)];
    }];
    
    [self.updatePreviewMethod callWithArguments:@[indices, pagination]];
}

/// Creates a listener for when document was saved.
- (void)onDocumentSaved:(JSValue*)updateMethod
{
    self.documentSavedCallback = updateMethod;
    [self makeResident];
}

- (void)documentWasSaved {
    [self.documentSavedCallback callWithArguments:nil];
}


#pragma mark - Resident plugin data providers

/// Callback for when scene headings are being autocompleted. Can be used to inject data into autocompletion.
- (void)onSceneHeadingAutocompletion:(JSValue*)callback {
    self.sceneCompletionCallback = callback;
    [self makeResident];
}
/// Allows the plugin to inject data to scene heading autocompletion list. If the plugin does not have a completion callback, it's ignored.
- (NSArray<NSString*>*)completionsForSceneHeadings
{
    if (self.sceneCompletionCallback == nil) return @[];
    
    JSValue *value = [self.sceneCompletionCallback callWithArguments:nil];
    if (!value.isArray) return @[];
    else return value.toArray;
}
/// Callback for when character cues are being autocompleted. Can be used to inject data into autocompletion.
- (void)onCharacterAutocompletion:(JSValue*)callback {
    self.characterCompletionCallback = callback;
    [self makeResident];
}
/// Allows the plugin to inject data to character autocompletion list. If the plugin does not have a completion callback, it's ignored.
- (NSArray<NSString*>*)completionsForCharacters {
    if (self.characterCompletionCallback == nil) return @[];
    
    JSValue *value = [self.characterCompletionCallback callWithArguments:nil];
    if (!value.isArray) return @[];
    else return value.toArray;
}

@end
