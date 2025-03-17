//
//  BeatPlugin+TextHighlighting.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 9.3.2025.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol BeatPluginTextHighlightingExports <JSExport>
JSExportAs(textHighlight, - (void)textHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len);
JSExportAs(textBackgroundHighlight, - (void)textBackgroundHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len);
JSExportAs(removeTextHighlight, - (void)removeTextHighlight:(NSInteger)loc len:(NSInteger)len);
JSExportAs(removeBackgroundHighlight, - (void)removeBackgroundHighlight:(NSInteger)loc len:(NSInteger)len);
@end

@interface BeatPlugin (TextHighlighting) <BeatPluginTextHighlightingExports>

- (void)textHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len;
- (void)removeTextHighlight:(NSInteger)loc len:(NSInteger)len;
- (void)textBackgroundHighlight:(NSString*)hexColor loc:(NSInteger)loc len:(NSInteger)len;
- (void)removeBackgroundHighlight:(NSInteger)loc len:(NSInteger)len;

@end
