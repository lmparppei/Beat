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
#import <BeatCore/BeatFontSet.h>
#import <BeatThemes/BeatThemes.h>

// Caregories
#import <BeatCore/BeatDocumentBaseController+RegisteredViewsAndObservers.h>

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
// TODO: Maybe toss these into a category?

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

- (void)setRevisionLevel:(NSInteger)revisionLevel
{
    [self.documentSettings setInt:DocSettingRevisionLevel as:revisionLevel];
}

- (NSInteger)revisionLevel
{
    return [self.documentSettings getInt:DocSettingRevisionLevel];
}


#pragma mark - Loading text

/// Loads the given Beat document string by reading the settings block and returning content. Also sets the content buffer.
- (NSString*)readBeatDocumentString:(NSString*)text
{
    self.documentIsLoading = true;
    // Sorry for this weird cast. The OS-specific implementations will implement this protocol.
    self.documentSettings = [BeatDocumentSettings.alloc initWithDelegate:(id<BeatDocumentSettingDelegate>)self];
    
    NSRange settingsRange = [self.documentSettings readSettingsAndReturnRange:text];
    NSString* content = [text stringByReplacingCharactersInRange:settingsRange withString:@""];
    
    NSInteger length = [self.documentSettings getInt:DocSettingTextLengthAtSave];
    if (length > 0 && length != content.length && length+1 != content.length) {
        [self showDataHealthWarningIfNeeded];
    }
    
    self.contentBuffer = content;
    
    return content;
}

- (void)revertToText:(NSString*)text
{
    NSLog(@"!!! You should probably override revertToText: in OS-specific implementation");
    self.documentIsLoading = true;
    [self readBeatDocumentString:text];
}


#pragma mark - Editor styles

- (BeatStylesheet *)editorStyles
{    
    BeatStylesheet* styles = [BeatStyles.shared stylesWithName:[self.documentSettings getString:DocSettingStylesheet] delegate:(id<BeatEditorDelegate>)self forEditor:true];
    return (styles != nil) ? styles : BeatStyles.shared.defaultEditorStyles;
}
- (BeatStylesheet *)styles
{
    BeatStylesheet* styles = [BeatStyles.shared stylesWithName:[self.documentSettings getString:DocSettingStylesheet] delegate:(id<BeatEditorDelegate>)self forEditor:false];
    return (styles != nil) ? styles : BeatStyles.shared.defaultStyles;
}

- (void)resetStyles
{
    [BeatStyles.shared reset];
    [self reloadStyles];
}

/// Reloads __current__ stylesheet. Does NOT reload all styles if the stylesheet has changed.
/// - note: This might need to be called in OS-specific implementation as well.
- (void)reloadStyles
{
    ((BeatLayoutManager*)self.layoutManager).pageBreaksMap = nil;
    
    [self.styles reloadWithDocumentSettings:self.documentSettings];
    [self.editorStyles reloadWithDocumentSettings:self.documentSettings];
    [self reloadFonts];
    [self resetPreview];
    
    // Let's reformat certain types of elements (and hope the user doesn't have like 9999999999 of each)
    [self.formatting formatAllLinesOfType:heading];
    [self.formatting formatAllLinesOfType:shot];
}

- (void)setStylesheet:(NSString*)name
{
    // Check that this sheet exists
    BeatStylesheet* styles = [BeatStyles.shared stylesWithName:[self.documentSettings getString:DocSettingStylesheet] delegate:(id<BeatEditorDelegate>)self forEditor:false];
    if (styles == nil) name = @"";
    
    // Store the new stylesheet
    [self.documentSettings setString:DocSettingStylesheet as:name];
}

- (void)setStylesheetAndReformat:(NSString*)name
{
    [self setStylesheet:name];
    
    // Re-read all styles, just in case
    [self reloadFonts];
    [self.styles reloadWithDocumentSettings:self.documentSettings];
    [self.editorStyles reloadWithDocumentSettings:self.documentSettings];
    
    // Format all lines
    [self.formatting formatAllLines];
        
    [self resetPreview];
}

/// Forgets local styles for this document
- (void)forgetStyles
{
    [BeatStyles.shared closeDocumentWithDelegate:(id<BeatEditorDelegate>)self];
}

/// Returns the __default__ line height for editor view as defined in styles. This value is used by the layout manager for some drawing operations, which is not that good.
/// We should rather use actual line heights from the attributed string.
- (CGFloat)editorLineHeight
{
    return self.editorStyles.page.lineHeight;
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
    if (self.textStorage.isEditing) [self.textStorage endEditing];
    
        // Begin from top if no last changed range was set
    if (self.lastChangedRange.location == NSNotFound) self.lastChangedRange = NSMakeRange(0, 0);

    // Update formatting
    [self.formatting applyFormatChanges];

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
    [self.formatting applyFormatChanges];
    [self.formatting formatAllLines];
}

/// When something was changed, this method takes care of reformatting every line. Actually done in `BeatEditorFormatting`.
- (void)applyFormatChanges
{
    [self.formatting applyFormatChanges];
}

- (void)reformatAllLines
{
    [self.formatting reformatLinesAtIndices:[NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.lines.count)]];
}

- (void)reformatLinesAtIndices:(NSMutableIndexSet *)indices
{
    [self.formatting reformatLinesAtIndices:indices];
}


/// Forces a type on a line and formats it accordingly. Can be abused to do strange and esoteric stuff.
- (void)setTypeAndFormat:(Line*)line type:(LineType)type
{
    line.type = type;
    [self.formatting formatLine:line];
}

- (void)updateTheme
{
    NSLog(@"WARNING: Override updateTheme in OS-specific implementation");
}

- (void)updateThemeAndReformat:(NSArray*)types
{
    bool formatText = false;
    
    // First update all basic elements
    [self updateTheme];
    
    // Now, let's reformat the needed types
    for (Line* line in self.parser.lines)
    {
        if (formatText) {
            [self.formatting refreshRevisionTextColorsInRange:line.range];
        }
        
        bool reformat = false;
        
        if ([types containsObject:@"text"] ||
            [types containsObject:line.typeName] ||
            ([types containsObject:@"omit"] && line.omittedRanges.count > 0) ||
            ([types containsObject:@"note"] && line.noteRanges.count) ||
            ([types containsObject:@"macro"] && line.macroRanges.count)
            ) {
            reformat = true;
        }
        
        if (reformat) [self.formatting setTextColorFor:line];
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
/// - note: The weird `<BeatPluginInstance>` here exists, because plugins are still not part of the core framework... for reason or another.
- (void)paginationFinished:(BeatPagination * _Nonnull)operation indices:(NSIndexSet * _Nonnull)indices pageBreaks:(NSDictionary<NSValue *,NSArray<NSNumber *> *> * _Nonnull)pageBreaks
{
    __block NSIndexSet* changedIndices = indices.copy;
    
    // We might be in a background thread, so make sure to dispach this call to main thread
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        // Update pagination in text view
        BeatLayoutManager* lm = (BeatLayoutManager*)self.getTextView.layoutManager;
        [lm updatePageBreaks:pageBreaks];

        [self.textView textViewNeedsDisplay];
        
        // Tell plugins the preview has been finished
        for (id<BeatPluginInstance> plugin in self.runningPlugins.allValues) {
            [plugin previewDidFinish:operation indices:changedIndices];
        }
    });
}


#pragma mark - Text view components

- (BXTextView*)getTextView { return self.textView; }

- (NSTextStorage*)textStorage { return self.textView.textStorage; }

- (NSLayoutManager*)layoutManager { return self.textView.layoutManager; }

- (void)refreshTextView { [self.textView textViewNeedsDisplay]; }

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

- (NSRange)selectedRange
{
    return self.textView.selectedRange;
}
- (void)setSelectedRange:(NSRange)range
{
    [self setSelectedRange:range withoutTriggeringChangedEvent:NO];
}

/// Sets selected range without triggering `didChangeSelection:` event when needed
- (void)setSelectedRange:(NSRange)range withoutTriggeringChangedEvent:(bool)triggerChangedEvent
{
    _skipSelectionChangeEvent = triggerChangedEvent;
    
    @try {
        [self.textView setSelectedRange:range];
    }
    @catch (NSException *e) {
        NSLog(@"Selection out of range");
    }
}


#pragma mark - Text getter/setter

- (NSString *)text
{
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
    return [self createDocumentFileWithAdditionalSettings:nil excludingSettings:nil];
}

- (NSString*)createDocumentFileWithAdditionalSettings:(NSDictionary *)additionalSettings
{
    return [self createDocumentFileWithAdditionalSettings:additionalSettings excludingSettings:nil];
}

/// Returns the string to be stored as the document. After merging together content and settings, the string is returned to `dataOfType:`. If you want to add additional settings at save-time, you can provide them in a dictionary. You can also provide an array for excluded setting keys. This is used especially for version control.
- (NSString*)createDocumentFileWithAdditionalSettings:(NSDictionary*)additionalSettings excludingSettings:(NSArray<NSString*>*)excludedKeys
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

    // Store the text length. This is used for health checks.
    [self.documentSettings setInt:DocSettingTextLengthAtSave as:content.length];
    
    // Save added/removed ranges
    // This saves the revised ranges into Document Settings
    NSDictionary *revisions = [BeatRevisions rangesForSaving:attrStr];
    [self.documentSettings set:DocSettingRevisions as:revisions];
    
    // Save tag definitions and ranges
    [self.tagging saveTags];
    
    // Save current revision color
    [self.documentSettings setInt:DocSettingRevisionLevel as:self.revisionLevel];
    
    // Store currently running plugins (the ones which support restoration)
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
    
    NSString * settingsString = [self.documentSettings getSettingsStringWithAdditionalSettings:additionalSettings excluding:excludedKeys];

    // Add line break if needed
    if (content.length > 0 && ![[content substringFromIndex:content.length-1] isEqualToString:@"\n"])
        settingsString = [NSString stringWithFormat:@"\n%@", settingsString];

    // Create final result string
    NSString * result = [NSString stringWithFormat:@"%@%@", content, (settingsString) ? settingsString : @""];
    
    [self documentWasSaved];
    
    return result;
}


#pragma mark - Revisions

- (void)bakeRevisions
{
    [BeatRevisions bakeRevisionsIntoLines:self.parser.lines.copy text:self.getAttributedText];
}

- (NSIndexSet*)shownRevisions
{
    NSMutableIndexSet* shownRevisions = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, BeatRevisions.revisionGenerations.count)];
    NSArray<NSNumber*>* hiddenRevisions = [self.documentSettings get:DocSettingHiddenRevisions];
    
    if ([hiddenRevisions isKindOfClass:NSArray.class] && hiddenRevisions != nil && hiddenRevisions.count > 0) {
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

- (BeatFontType)fontType
{
    bool variableWidth = self.editorStyles.variableFont;
    bool sansSerif = self.useSansSerif;
    BeatFontType type = BeatFontTypeFixed;
    
    if (variableWidth) {
        type = (sansSerif) ? BeatFontTypeVariableSansSerif : BeatFontTypeVariableSerif;
    } else {
        type = (sansSerif) ? BeatFontTypeFixedSansSerif : BeatFontTypeFixed;
    }
    
    return type;
}

- (void)loadFonts
{
    self.fonts = [BeatFontManager.shared fontsWith:self.fontType scale:1.0];
}

- (void)loadFontsWithScale:(CGFloat)scale
{
    self.fonts = [BeatFontManager.shared fontsWith:self.fontType scale:scale];
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

- (CGFloat)fontScale
{
#if TARGET_OS_IOS
    if (is_Mobile) {
        CGFloat zoom = (CGFloat)[BeatUserDefaults.sharedDefaults getInteger:BeatSettingPhoneFontSize];
        return ((zoom + 4) / 10 ) + 1.0;
    }
#endif
    return 1.0;
}


#pragma mark - Handoff

#if TARGET_OS_OSX
/*
- (void)updateUserActivityState:(NSUserActivity *)activity
{
    [super updateUserActivityState:activity];
    [activity addUserInfoEntriesFromDictionary:@{
        @"url": (self.fileURL!= nil) ? self.fileURL.absoluteString : @""
    }];
}

- (void)setupHandoff
{
    NSUserActivity* activity = [NSUserActivity.alloc initWithActivityType:@"fi.KAPITAN.Beat.editing"];
    activity.title = @"Editing Document";
    activity.eligibleForHandoff = true;
    activity.eligibleForSearch = false;
    activity.eligibleForPublicIndexing = false;
    
    activity.userInfo = @{
        @"url": (self.fileURL!= nil) ? self.fileURL.absoluteString : @""
    };
    
    self.userActivity = activity;
    [self.userActivity becomeCurrent];
}
*/
#endif


#pragma mark - Plugin support

/// Returns every plugin that should be registered to be saved
- (NSArray<NSString*>*)runningPluginsForSaving
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

#pragma mark - Warnings

- (void)showDataHealthWarningIfNeeded
{
    // First, we'll need to check that there is something we need to warn about.
    
    NSDictionary* revisions = [self.documentSettings get:DocSettingRevisions];
    NSDictionary* tags = [self.documentSettings get:DocSettingTags];
    NSDictionary* reviews = [self.documentSettings get:DocSettingReviews];
    
    bool noRanges = true;
    
    // Revisions might have empty arrays inside it
    for (NSString* key in revisions.allKeys) {
        NSArray* ranges = revisions[key];
        if (ranges.count > 0) {
            noRanges = false;
            break;
        }
    }
    // Other ranges are just plain arrays
    if (reviews.count > 0 || tags.count > 0) noRanges = false;
    
    // Nothing to check, ignore warnings
    if (noRanges) return;
    
    // This method should return true if we want to remove the expired ranges. Override in OS-specific implementation.
    if ([self showDataHealthWarning]) {
        [self removeExpiredRanges];
    }
}

- (BOOL)showDataHealthWarning
{
    NSLog(@"⚠️ Override showDataHealthWarning in OS-specific implementation. Return true to remove all ranges.");
    return false;
}

- (void)removeExpiredRanges
{
    [self.documentSettings remove:DocSettingRevisions];
    [self.documentSettings remove:DocSettingTags];
    [self.documentSettings remove:DocSettingReviews];
}


#pragma mark - Theme manager

/// This is a hack to return the theme manager to plugins
- (id)themeManager {  return ThemeManager.sharedManager; }

@end
