//
//  BeatDocumentBaseController.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 7.11.2023.
//

#import "BeatDocumentBaseController.h"
#import <BeatCore/BeatCore-Swift.h>
#import <BeatCore/BeatTextIO.h>
#import <BeatCore/BeatRevisions.h>
#import <BeatCore/BeatCompatibility.h>
#import <BeatCore/NSTextView+UX.h>
#import <BeatCore/BeatEditorFormatting.h>
#import <BeatCore/BeatUserDefaults.h>
#import <BeatCore/BeatLayoutManager.h>
//#import <BeatCore/BeatFonts.h>
#import <BeatCore/BeatFontSet.h>
#import <BeatThemes/BeatThemes.h>

#define FORWARD_TO( CLASS, TYPE, METHOD ) \
- (TYPE)METHOD { [CLASS METHOD]; }

@interface BeatDocumentBaseController() <ContinuousFountainParserDelegate>
@end

@implementation BeatDocumentBaseController

#pragma mark - Identity

#if TARGET_OS_OSX
- (id)document
{
    return self;
}
#endif

- (NSUUID*)uuid
{
    if (_uuid == nil) _uuid = NSUUID.new;
    return _uuid;
}

- (nonnull NSString *)fileNameString {
    NSLog(@"fileNameString: Override in OS-specific implementation");
    return @"";
}

/// Marks the document as changed
- (void)addToChangeCount
{
    if (self.documentIsLoading) return;
    
#if TARGET_OS_OSX
    [self updateChangeCount:BXChangeDone];
#else
    NSLog(@"!!! Implement addToChangeCount on iOS");
#endif

}


#pragma mark - Setting getters and setters
// TODO: Maybe toss these into a Swift extension or a category?

- (bool)showRevisions
{
    return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowRevisions];
}

- (bool)showRevisedTextColor
{
    return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowRevisedTextColor];
}

- (bool)printSceneNumbers
{
    return [self.documentSettings getBool:DocSettingPrintSceneNumbers];
}

- (void)setPrintSceneNumbers:(bool)value
{
    [self.documentSettings setBool:DocSettingPrintSceneNumbers as:value];
}

- (bool)autocomplete
{
    return [BeatUserDefaults.sharedDefaults getBool:BeatSettingAutocomplete];
}
- (void)setAutocomplete:(bool)autocomplete
{
    [BeatUserDefaults.sharedDefaults saveBool:autocomplete forKey:BeatSettingAutocomplete];
}

- (bool)autoLineBreaks
{
    return [BeatUserDefaults.sharedDefaults getBool:BeatSettingAutomaticLineBreaks];
}
- (void)setAutoLineBreaks:(bool)autoLineBreaks
{
    [BeatUserDefaults.sharedDefaults saveBool:autoLineBreaks forKey:BeatSettingAutomaticLineBreaks];
}

- (bool)automaticContd
{
    return [BeatUserDefaults.sharedDefaults getBool:BeatSettingAutomaticContd];
}
- (void)setAutomaticContd:(bool)automaticContd
{
    [BeatUserDefaults.sharedDefaults saveBool:automaticContd forKey:BeatSettingAutomaticContd];
}

- (bool)matchParentheses
{
    return [BeatUserDefaults.sharedDefaults getBool:BeatSettingMatchParentheses];
}
- (void)setMatchParentheses:(bool)value
{
    [BeatUserDefaults.sharedDefaults saveBool:value forKey:BeatSettingMatchParentheses];
}

- (bool)hidePageNumbers
{
    return false;
}


#pragma mark - Editor styles

- (BeatStylesheet *)editorStyles
{
    BeatStylesheet* styles = [BeatStyles.shared editorStylesFor:[self.documentSettings getString:DocSettingStylesheet] delegate:(id<BeatEditorDelegate>)self];
    return (styles != nil) ? styles : BeatStyles.shared.defaultEditorStyles;
}
- (BeatStylesheet *)styles
{
    BeatStylesheet* styles = [BeatStyles.shared stylesFor:[self.documentSettings getString:DocSettingStylesheet]];
    return (styles != nil) ? styles : BeatStyles.shared.defaultStyles;
}

- (void)resetStyles
{
    [BeatStyles.shared reset];
    [self reloadStyles];
}

/// Reloads __current__ stylesheet. Does NOT reload all styles if the stylesheet has changed.
- (void)reloadStyles
{
    ((BeatLayoutManager*)self.layoutManager).pageBreaksMap = nil;
    
    [self.styles reloadWithExportSettings:self.exportSettings];
    [self.editorStyles reloadWithExportSettings:self.exportSettings];
    [self resetPreview];
    
    // Let's reformat certain types of elements (and hope the user doesn't have like 9999999999 of each)
    [self.formatting formatAllLinesOfType:heading];
    [self.formatting formatAllLinesOfType:shot];
    
    // NOTE: This might need to be called in OS-specific implementation as well.
}

- (void)setStylesheet:(NSString*)name
{
    // Check that this sheet exists
    BeatStylesheet* styles = [BeatStyles.shared stylesFor:[self.documentSettings getString:DocSettingStylesheet]];
    if (styles == nil) name = @"";
    
    // Store the new stylesheet
    [self.documentSettings setString:DocSettingStylesheet as:name];
}

- (void)setStylesheetAndReformat:(NSString*)name
{
    [self setStylesheet:name];
    
    // Re-read all styles, just in case
    [self reloadFonts];
    [self.styles reloadWithExportSettings:self.exportSettings];
    [self.editorStyles reloadWithExportSettings:self.exportSettings];
    
    // Format all lines
    [self.formatting formatAllLines];
        
    [self resetPreview];
}

/// Returns __actual__ line height for editor view
- (CGFloat)editorLineHeight
{
    return self.editorStyles.page.lineHeight;
}

/// Returns LINE HEIGHT MODIFIER (!!!), not actual line height
- (CGFloat)lineHeight
{
    return self.editorStyles.page.lineHeight / 12.0;
}

- (void)ensureLayout
{
    NSLog(@"ensureLayout should be overridden by the OS-specific class.");
}

/// Returns disabled types from styles
- (NSIndexSet*)disabledTypes
{
    return self.editorStyles.document.getDisabledTypes;
}


#pragma mark - Document setting shorthands

#pragma mark Page size

/// Returns the current page size, or default size if none is applied
- (BeatPaperSize)pageSize
{
    if ([self.documentSettings has:DocSettingPageSize]) {
        return [self.documentSettings getInt:DocSettingPageSize];
    } else {
        return [BeatUserDefaults.sharedDefaults getInteger:@"defaultPageSize"];
    }
}

/// Remember to override/supplement this in OS-specific implementations to correctly set view size
- (void)setPageSize:(BeatPaperSize)pageSize
{
    [self.documentSettings setInt:DocSettingPageSize as:pageSize];
    if (!self.documentIsLoading) [self.formatting resetSizing];
    
    [self.previewController resetPreview];
}


#pragma mark Export settings

-(BeatExportSettings*)exportSettings
{
    BeatExportSettings* settings = [BeatExportSettings operation:ForPreview delegate:(id<BeatExportSettingDelegate>)self];
    return settings;
}


#pragma mark - Text view delegate / events

/// Common text view delegate method
- (void)textDidChange
{
    if (self.documentIsLoading) return;
 
        // Begin from top if no last changed range was set
    if (self.lastChangedRange.location == NSNotFound) self.lastChangedRange = NSMakeRange(0, 0);

    // Update formatting
    [self applyFormatChanges];

    // Save attributed text to cache
    self.attrTextCache = [self getAttributedText];
    
    // Check for changes in outline. If any changes are found, all registered outline views will be updated.
    [self.parser checkForChangesInOutline];

    // Editor views should register themselves and have to conform to BeatEditorView protocol,
    // which includes methods for reloading both in sync and async
    [self updateEditorViewsInBackground];
    
    // Paginate
    [self.previewController createPreviewWithChangedRange:self.lastChangedRange sync:false];
    
    // A larger chunk of text was pasted. Ensure layout.
    if (self.lastChangedRange.length > 5) [self ensureLayout];
    
    // Update any running plugins
    [(id<BeatPluginAgentInstance>)self.pluginAgent updatePlugins:self.lastChangedRange];
    
    // Update any listeners
    for (BeatChangeListener listener in self.changeListeners.allValues) listener(self.lastChangedRange);
}



#pragma mark - Line lookup

- (Line*)currentLine
{
    _previouslySelectedLine = _currentLine;
    
    NSInteger location = self.selectedRange.location;
    Line* currentLine;
    
    if (location >= self.text.length) {
        // Check if we're on the last line
        currentLine = self.parser.lines.lastObject;
    } else {
        // Otherwise get the line at given position
        Line *line = [self.parser lineAtPosition:location];
        currentLine = line;
    }
    
    _currentLine = currentLine;
    return currentLine;
}

/// Null references to possibly deleted lines
- (void)lineWasRemoved:(Line *)line
{
    if (_currentLine == line) _currentLine = nil;
    if (_previouslySelectedLine == line) _previouslySelectedLine = nil;
}


#pragma mark - Scene lookup

- (OutlineScene*)currentScene
{
    // If we are not on the main thread, return the latest known scene
    if (!NSThread.isMainThread) return _currentScene;
    
    OutlineScene* scene = [self getCurrentSceneWithPosition:self.selectedRange.location];
    _currentScene = scene;
    return scene;
}

- (OutlineScene*)getCurrentSceneWithPosition:(NSInteger)position
{
    NSArray* outline = self.parser.safeOutline;
    // If the position is inside the stored current scene, just return that.
    if (_currentScene && NSLocationInRange(position, _currentScene.range) && [outline containsObject:_currentScene]) {
        return _currentScene;
    }
    
    // At the end, return last scene
    if (position >= self.text.length) return outline.lastObject;
    
    OutlineScene *prevScene;
    for (OutlineScene *scene in outline) {
        if (NSLocationInRange(position, scene.range))  {
            return scene;
        } else if (position >= NSMaxRange(prevScene.range) && position < scene.position && prevScene) {
            return prevScene;
        }
        
        prevScene = scene;
    }
    
    return nil;
}

- (OutlineScene*)getPreviousScene
{
    NSArray *outline = self.parser.safeOutline;
    if (outline.count == 0) return nil;
    
    NSInteger lineIndex = [self.parser indexOfLine:self.currentLine] ;
    if (lineIndex == NSNotFound || lineIndex >= self.parser.lines.count - 1) return nil;
    
    for (NSInteger i = lineIndex - 1; i >= 0; i--) {
        Line* line = self.parser.lines[i];
        
        if (line.type == heading || line.type == section) {
            for (OutlineScene *scene in outline) {
                if (scene.line == line) return scene;
            }
        }
    }
    
    return nil;
}
- (OutlineScene*)getNextScene
{
    NSArray *outline = self.parser.safeOutline;
    if (outline.count == 0) return nil;
    
    NSInteger lineIndex = [self.parser indexOfLine:self.currentLine] ;
    if (lineIndex == NSNotFound || lineIndex >= self.parser.lines.count - 1) return nil;
    
    for (NSInteger i = lineIndex + 1; i < self.parser.lines.count; i++) {
        Line* line = self.parser.lines[i];
        
        if (line.type == heading || line.type == section) {
            for (OutlineScene *scene in outline) {
                if (scene.line == line) return scene;
            }
        }
    }
    
    return nil;
}


#pragma mark - Show scene numbers

- (bool)showSceneNumberLabels
{
    return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowSceneNumbers];
}

- (void)setShowSceneNumberLabels:(bool)showSceneNumberLabels
{
    [BeatUserDefaults.sharedDefaults saveBool:showSceneNumberLabels forKey:BeatSettingShowSceneNumbers];
}


#pragma mark - Pagination

- (bool)showPageNumbers
{
    return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowPageNumbers];
}

- (void)setShowPageNumbers:(bool)showPageNumbers
{
    [BeatUserDefaults.sharedDefaults saveBool:showPageNumbers forKey:BeatSettingShowPageNumbers];
    [self.textView textViewNeedsDisplay];
}


#pragma mark - Formatting
/// TODO: WHY ARE THESE HERE???? Move to `BeatFormatting`
/// Not so fast – some sort of reformatting control is nice to have in this object for theme delegate conformance. Although why aren't themes in `BeatCore` to begin with?

- (IBAction)reformatEverything:(id)sender
{
    [self.parser resetParsing];
    [self applyFormatChanges];
    [self.formatting formatAllLines];
}

- (void)reformatAllLines
{
    [self.formatting reformatLinesAtIndices:[NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.lines.count)]];
}

/// When something was changed, this method takes care of reformatting every line
- (void)applyFormatChanges
{
    [self.parser.changedIndices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx >= _parser.lines.count) *stop = true;
        else [_formatting formatLine:self.parser.lines[idx]];
    }];
    
    [self.parser.changedIndices removeAllIndexes];
}

- (void)reformatLinesAtIndices:(NSMutableIndexSet *)indices
{
    [self.formatting reformatLinesAtIndices:indices];
}

- (void)renderBackgroundForRange:(NSRange)range
{
    NSArray *lines = [self.parser linesInRange:range];
    for (Line* line in lines) {
        [self.formatting refreshRevisionTextColorsInRange:line.textRange];
        [self.layoutManager invalidateDisplayForCharacterRange:line.textRange];
    }
}

- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear
{
    [self.layoutManager invalidateDisplayForCharacterRange:line.textRange];
}

/// Forces a type on a line and formats it accordingly. Can be abused to do strange and esoteric stuff.
- (void)setTypeAndFormat:(Line*)line type:(LineType)type
{
    line.type = type;
    [self.formatting formatLine:line];
}

- (void)renderBackgroundForLines
{
    for (Line* line in self.lines) {
        [self.formatting refreshRevisionTextColorsInRange:line.textRange];
        [self.layoutManager invalidateDisplayForCharacterRange:line.textRange];
    }
}



#pragma mark - Parser shorthands

- (NSMutableArray<Line*>* _Nonnull)lines
{
    return _parser.lines;
}

- (NSArray<OutlineScene*>*)outline
{
    if (self.parser.outline == nil) return @[];
    else return self.parser.outline.copy;
}


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


#pragma mark - Preview creation
/// - note: The base class has no knowledge of OS-specific implementation of the preview controller.

- (void)createPreviewAt:(NSRange)range
{
    [self.previewController createPreviewWithChangedRange:range sync:false];
}

- (void)createPreviewAt:(NSRange)range sync:(BOOL)sync
{
    [self.previewController createPreviewWithChangedRange:range sync:sync];
}

- (void)invalidatePreview
{
    [self.previewController resetPreview];
}

- (void)invalidatePreviewAt:(NSInteger)index
{
    [self.previewController invalidatePreviewAt:NSMakeRange(index, 0)];
}

- (void)resetPreview
{
    [self.previewController resetPreview];
}


#pragma mark - Pagination

/// Returns the current pagination in preview controller
/// - note: Required to conform to plugin API.
- (BeatPaginationManager*)pagination { return self.previewController.getPagination; }
- (BeatPaginationManager*)paginator { return self.previewController.getPagination; }

/// Paginates this document from scratch
- (void)paginate
{
    [self paginateAt:(NSRange){0,0} sync:NO];
}

- (void)paginateAt:(NSRange)range sync:(bool)sync
{
    // Don't paginate while loading
    if (!self.documentIsLoading) [self.previewController createPreviewWithChangedRange:range sync:sync];
}

/// Pagination finished — called when preview controller has finished creating pagination
- (void)paginationFinished:(BeatPagination * _Nonnull)operation indices:(NSIndexSet * _Nonnull)indices pageBreaks:(NSDictionary<NSValue *,NSArray<NSNumber *> *> * _Nonnull)pageBreaks
{
    __block NSIndexSet* changedIndices = indices.copy;
    
    // We might be in a background thread, so make sure to dispach this call to main thread
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        // Update pagination in text view
        BeatLayoutManager* lm = (BeatLayoutManager*)self.getTextView.layoutManager;
        //lm.pageBreaks = pageBreaks;
        [lm updatePageBreaks:pageBreaks];

        [self.textView textViewNeedsDisplay];
        
        // Tell plugins the preview has been finished
        for (id<BeatPluginInstance> plugin in self.runningPlugins.allValues) {
            [plugin previewDidFinish:operation indices:changedIndices];
        }
    });
}


#pragma mark - Text view components

- (BXTextView*)getTextView {
    return self.textView;
}

- (NSTextStorage*)textStorage {
    return self.textView.textStorage;
}

- (NSLayoutManager*)layoutManager {
    return self.textView.layoutManager;
}

- (void)refreshTextView
{
    [self.textView textViewNeedsDisplay];
}

/// Focuses the editor window
- (void)focusEditor
{
#if TARGET_OS_IOS
    [self.textView becomeFirstResponder];
#else
    [self.textView.window makeKeyWindow];
    [self.textView.window makeFirstResponder:self.textView];
#endif
}


#pragma mark - Misc stuff

-(NSString *)displayName
{
    NSLog(@"Override displayName in OS-specific implementation");
    return nil;
}


#pragma mark - Selection

- (NSRange)selectedRange {
    return self.textView.selectedRange;
}
- (void)setSelectedRange:(NSRange)range {
    [self setSelectedRange:range withoutTriggeringChangedEvent:NO];
}
/// Set selected range but DO NOT trigger the didChangeSelection: event
- (void)setSelectedRange:(NSRange)range withoutTriggeringChangedEvent:(bool)triggerChangedEvent {
    _skipSelectionChangeEvent = triggerChangedEvent;
    
    @try {
        [self.textView setSelectedRange:range];
    }
    @catch (NSException *e) {
        NSLog(@"Selection out of range");
    }
}

- (bool)caretAtEnd {
#if TARGET_OS_OSX
    return (self.textView.selectedRange.location == self.textView.string.length);
#else
    return (self.textView.selectedRange.location == self.textView.text.length);
#endif
}



#pragma mark - Text getter/setter

- (NSString *)text {
    if (!NSThread.isMainThread) return self.attrTextCache.string;
    return self.textView.text;
}

- (void)setText:(NSString *)text
{
    // If view is not ready yet, set text to buffer
    if (self.textView == nil) self.contentBuffer = text;
    else [self.textView setText:text];
}

#pragma mark - Text cache

- (NSAttributedString *)getAttributedText
{
    NSAttributedString* attrStr;
    if (!NSThread.isMainThread) attrStr = self.attrTextCache;
    else attrStr = self.textView.textStorage;
    
    return (attrStr != nil) ? attrStr : NSAttributedString.new;
}

- (NSAttributedString*)attributedString
{
    return [self getAttributedText];
}


#pragma mark - Text actions

// Because of some legacy stuff, text I/O methods are forwarded from this class to BeatTextIO.

FORWARD_TO(self.textActions, void, replaceCharactersInRange:(NSRange)range withString:(NSString*)string);
FORWARD_TO(self.textActions, void, addString:(NSString*)string atIndex:(NSUInteger)index);
FORWARD_TO(self.textActions, void, addString:(NSString*)string atIndex:(NSUInteger)index skipAutomaticLineBreaks:(bool)skipLineBreaks);
FORWARD_TO(self.textActions, void, replaceRange:(NSRange)range withString:(NSString*)newString);
FORWARD_TO(self.textActions, void, replaceString:(NSString*)string withString:(NSString*)newString atIndex:(NSUInteger)index);
FORWARD_TO(self.textActions, void, removeRange:(NSRange)range);
FORWARD_TO(self.textActions, void, moveStringFrom:(NSRange)range to:(NSInteger)position actualString:(NSString*)string);
FORWARD_TO(self.textActions, void, moveStringFrom:(NSRange)range to:(NSInteger)position);
FORWARD_TO(self.textActions, void, moveScene:(OutlineScene*)sceneToMove from:(NSInteger)from to:(NSInteger)to);
FORWARD_TO(self.textActions, void, removeTextOnLine:(Line*)line inLocalIndexSet:(NSIndexSet*)indexSet);

/// Removes an attribute from the text storage
- (void)removeAttribute:(NSString*)key range:(NSRange)range
{
    if (key == nil) return;
    [self.textView.textStorage removeAttribute:key range:range];
}
/// Adds an attribute to the text storage
- (void)addAttribute:(NSString*)key value:(id)value range:(NSRange)range
{
    if (value == nil) return;
    [self.textView.textStorage addAttribute:key value:value range:range];
}
/// Adds attributes to the text storage
- (void)addAttributes:(NSDictionary*)attributes range:(NSRange)range
{
    if (attributes == nil) return;
    [self.textView.textStorage addAttributes:attributes range:range];
}


#pragma mark - Creating the actual document file

- (NSString*)createDocumentFile
{
    return [self createDocumentFileWithAdditionalSettings:nil];
}

/// Returns the string to be stored as the document. After merging together content and settings, the string is returned to `dataOfType:`. If you want to add additional settings at save-time, you can provide them in a dictionary.
- (NSString*)createDocumentFileWithAdditionalSettings:(NSDictionary*)additionalSettings
{
    // For async saving & thread safety, make a copy of the lines array
    NSAttributedString *attrStr = self.getAttributedText;
    NSString* content = self.parser.screenplayForSaving;
    NSString* actualText = self.text;
    
    // Make sure data is intact
    if (actualText.length != content.length) {
        NSLog(@"🆘 Editor and parser are out of sync. We'll use the editor text.");
        content = actualText;
    }
    
    if (content == nil) {
        NSLog(@"ERROR: Something went horribly wrong, trying to crash the app to avoid data loss.");
        @throw NSInternalInconsistencyException;
    }
    
    // Resort to content buffer if needed
    if (content == nil) content = self.attrTextCache.string;
    
    // Save added/removed ranges
    // This saves the revised ranges into Document Settings
    NSDictionary *revisions = [BeatRevisions rangesForSaving:attrStr];
    [self.documentSettings set:DocSettingRevisions as:revisions];
    
    // Save current revision color
    [self.documentSettings setInt:DocSettingRevisionLevel as:self.revisionLevel];
        
    // Store currently running plugins (which should be saved)
    [self.documentSettings set:DocSettingActivePlugins as:[self runningPluginsForSaving]];
        
    // Save reviewed ranges
    NSArray *reviews = [_review rangesForSavingWithString:attrStr];
    [self.documentSettings set:DocSettingReviews as:reviews];
    
    // Save heading/section info
    [self.documentSettings set:DocSettingHeadingUUIDs as:self.parser.outlineUUIDs];
    
    // Save caret position
    [self.documentSettings setInt:DocSettingCaretPosition as:self.textView.selectedRange.location];
    
    #if TARGET_OS_OSX
        [self unblockUserInteraction];
    #endif
    
    NSString * settingsString = [self.documentSettings getSettingsStringWithAdditionalSettings:additionalSettings];
    NSString * result = [NSString stringWithFormat:@"%@%@", content, (settingsString) ? settingsString : @""];
    
    [self documentWasSaved];
    
    return result;
}


#pragma mark - Revisions

- (void)setRevisionLevel:(NSInteger)revisionLevel
{
    [self.documentSettings setInt:DocSettingRevisionLevel as:revisionLevel];
}

- (NSInteger)revisionLevel
{
    return [self.documentSettings getInt:DocSettingRevisionLevel];
}

- (void)bakeRevisions
{
    [BeatRevisions bakeRevisionsIntoLines:self.parser.lines.copy text:self.getAttributedText];
}

- (NSDictionary*)revisedRanges
{
    NSDictionary *revisions = [BeatRevisions rangesForSaving:self.getAttributedText];
    return revisions;
}

- (NSIndexSet*)shownRevisions
{
    NSMutableIndexSet* shownRevisions = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, BeatRevisions.revisionGenerations.count)];
    NSArray<NSNumber*>* hiddenRevisions = [self.documentSettings get:DocSettingHiddenRevisions];
    
    if (hiddenRevisions != nil && hiddenRevisions.count > 0) {
        for (NSNumber* n in hiddenRevisions) {
            if (n == nil) continue;
            [shownRevisions removeIndex:n.integerValue];
        }
    }
    
    return shownRevisions;
}


#pragma mark - Fonts

- (BeatFontSet*)fonts
{
    //if (_fonts == nil) return BeatFonts.sharedFonts;
    if (_fonts == nil) return BeatFontManager.shared.defaultFonts;
    else return _fonts;
}

- (bool)useSansSerif
{
    return [BeatUserDefaults.sharedDefaults getBool:BeatSettingUseSansSerif];
}
- (void)setUseSansSerif:(bool)useSansSerif
{
    [BeatUserDefaults.sharedDefaults saveBool:useSansSerif forKey:BeatSettingUseSansSerif];
}

- (void)fontDidLoad
{
    // Override in OS-specific implementation
}

/// Returns current default font point size
- (CGFloat)fontSize
{
    return BeatFontManager.shared.defaultFonts.regular.pointSize;
}

- (void)loadFonts
{
    bool variableSize = self.editorStyles.variableFont;
    bool sansSerif = self.useSansSerif;
    
    BeatFontType type;
    
    if (sansSerif) {
        if (variableSize) type = BeatFontTypeVariableSansSerif;
        else type = BeatFontTypeFixedSansSerif;
    } else {
        if (variableSize) type = BeatFontTypeVariableSerif;
        else type = BeatFontTypeFixed;
    }
    
    self.fonts = [BeatFontManager.shared fontsWith:type scale:1.0];
}

/// Reloads fonts and reformats whole document if needed.
/// @warning Can take a lot of time. Use with care.
- (void)reloadFonts
{
    NSString* oldFontName = self.fonts.name.copy;
    [self loadFonts];
    
    // If the font changed, let's reformat the whole document.
    if (![oldFontName isEqualToString:self.fonts.name]) [self.formatting formatAllLines];
}



#pragma mark - Register editor views and observers

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


#pragma mark - Plugin support

/// Returns every plugin that should be registered to be saved
- (NSArray*)runningPluginsForSaving
{
    NSMutableArray* plugins = NSMutableArray.new;
    for (NSString* pluginName in self.runningPlugins.allKeys) {
        id<BeatPluginInstance> plugin = (id<BeatPluginInstance>) self.runningPlugins[pluginName];
        if (!plugin.restorable) continue;
        
        [plugins addObject:pluginName];
    }
    
    return plugins;
}

- (id)getPropertyValue:(NSString *)key
{
    return [self valueForKey:key];
}

- (void)setPropertyValue:(NSString *)key value:(id)value
{
    [self setValue:value forKey:key];
}

- (void)documentWasSaved
{
    NSLog(@"documentWasSaved: Override in OS-specific implementation");
}


#pragma mark - Listeners

- (void)addChangeListener:(void(^)(NSRange))listener owner:(id)owner
{
    if (_changeListeners == nil) _changeListeners = NSMutableDictionary.new;
    
    NSValue* obj = [NSValue valueWithNonretainedObject:owner];
    _changeListeners[obj] = listener;
}

- (void)removeChangeListenersFor:(id)owner
{
    NSValue* obj = [NSValue valueWithNonretainedObject:owner];
    _changeListeners[obj] = nil;
}


#pragma mark - Theme manager

/// This is a hack to return the theme manager to plugins
- (id)themeManager {  return ThemeManager.sharedManager; }

@end
