//
//  BeatDocumentBaseController+Fonts.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 17.6.2026.
//

#import "BeatDocumentBaseController+Fonts.h"
#import <BeatCore/BeatCore-Swift.h>
#import <BeatCore/BeatFontSet.h>

@implementation BeatDocumentBaseController (Fonts)

#pragma mark - Fonts

/// Returns fonts for this document window. Make sure that fonts are loaded before styles.
- (BeatFontSet*)fonts
{
    if (self.__fonts == nil) return BeatFontManager.shared.defaultFonts;
    else return self.__fonts;
}

- (void)setFonts:(BeatFontSet *)fonts
{
    self.__fonts = fonts;
}

- (NSInteger)fontStyle
{
    return [BeatUserDefaults.sharedDefaults getInteger:BeatSettingFontStyle];
}

/// Returns current default font point size
- (CGFloat)fontSize
{
    return BeatFontManager.shared.defaultFonts.regular.pointSize;
}

- (BeatFontType)fontType
{
    return [BeatFontSet fontTypeWithStyle:self.fontStyle variableWidth:self.editorStyles.variableFont];
}

- (void)loadFonts
{
    [self loadFontsWithScale:1.0];
}

- (void)loadFontsWithScale:(CGFloat)scale
{
    bool variableFont = self.editorStyles.variableFont;
    NSString* customFontKey = (variableFont) ? BeatSettingCustomNovelFont : BeatSettingCustomScreenplayFont;
    NSString* customFont = [BeatUserDefaults.sharedDefaults get:customFontKey];
    if (customFont.length == 0) customFont = [BeatUserDefaults.sharedDefaults get:(variableFont) ? BeatSettingCustomNovelEditorFont : BeatSettingCustomScreenplayEditorFont];
    if (customFont.length == 0) customFont = [BeatUserDefaults.sharedDefaults get:(variableFont) ? BeatSettingCustomNovelExportFont : BeatSettingCustomScreenplayExportFont];
    if (customFont.length == 0) customFont = [BeatUserDefaults.sharedDefaults get:BeatSettingCustomEditorFont];
    if (customFont.length == 0) customFont = [BeatUserDefaults.sharedDefaults get:BeatSettingCustomExportFont];

    if (customFont.length > 0) {
        BeatFontSet* customFonts = [BeatFontManager.shared customFontsWithFontName:customFont scale:scale];
        if (customFonts != nil) {
            self.fonts = customFonts;
            return;
        }
    }

    self.fonts = [BeatFontManager.shared fontsWith:self.fontType scale:scale];
}

/// Reloads fonts and reformats whole document if needed.
/// @warning Can take a lot of time. Use with care.
- (void)reloadFonts
{
    NSString* oldFontName = self.fonts.name.copy;
    [self loadFonts];

    // If the font changed, let's reformat the whole document.
    if (![oldFontName isEqualToString:self.fonts.name]) {
        [self.formatting formatAllLines];
        [self refreshEditorFont];
    }
}

/// Refreshes typing attributes after a font change.
- (void)refreshEditorFont
{
    BXTextView* textView = self.getTextView;
    if (textView == nil) return;

    BXFont* font = self.fonts.regular;
    textView.font = font;

    CGFloat lineHeight = self.editorStyles.page.lineHeight;
    if (self.fonts.custom) {
        lineHeight = MAX(lineHeight, ceil(font.ascender - font.descender + font.leading));
    }

    NSMutableParagraphStyle *paragraphStyle = NSMutableParagraphStyle.new;
    paragraphStyle.maximumLineHeight = lineHeight;
    paragraphStyle.minimumLineHeight = lineHeight;
    paragraphStyle.lineSpacing = 1.0;
    #if TARGET_OS_OSX
    textView.defaultParagraphStyle = paragraphStyle;
    #endif

    NSMutableDictionary* typingAttributes = textView.typingAttributes.mutableCopy;
    typingAttributes[NSFontAttributeName] = font;
    typingAttributes[NSParagraphStyleAttributeName] = paragraphStyle;
    textView.typingAttributes = typingAttributes;
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

@end
