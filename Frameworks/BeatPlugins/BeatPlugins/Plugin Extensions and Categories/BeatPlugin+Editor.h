//
//  BeatPlugin+Editor.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 27.11.2024.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol BeatPluginEditorExports <JSExport>

/// Focuses the editor text view
- (void)focusEditor;

/// Returns the full raw text in editor view
- (NSString*)getText;

/// Move to next tab in document window
- (void)nextTab;
/// Move to previoustab in document window
- (void)previousTab;


#pragma mark - Scrolling

/// Scrolls to given position in document
- (void)scrollTo:(NSInteger)location;
/// Scrolls to given line index
- (void)scrollToLineIndex:(NSInteger)index;
/// Scrolls to given line
- (void)scrollToLine:(Line*)line;
/// Scrolls to given scene heading
- (void)scrollToScene:(OutlineScene*)scene;
/// Scrolls to the scene heading at given outline index
- (void)scrollToSceneIndex:(NSInteger)index;
/// Returns the selected range in editor
- (NSRange)selectedRange;


#pragma mark - Text I/O

JSExportAs(setSelectedRange, - (void)setSelectedRange:(NSInteger)start to:(NSInteger)length);
JSExportAs(addString, - (void)addString:(NSString*)string toIndex:(NSUInteger)index);
JSExportAs(replaceRange, - (void)replaceRange:(NSInteger)from length:(NSInteger)length withString:(NSString*)string);
JSExportAs(setColorForScene, -(void)setColor:(NSString *)color forScene:(id)scene);

@end

@interface BeatPlugin (Editor) <BeatPluginEditorExports>


@end

