//
//  BeatDocumentBaseController+Fonts.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 17.6.2026.
//

#import <BeatCore/BeatCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatDocumentBaseController (Fonts)

/// Loads the current fonts defined by stylesheet.
- (void)loadFonts;
/// Loads fonts with given scale
- (void)loadFontsWithScale:(CGFloat)scale;
/// Reloads fonts and performs reformatting if needed.
- (void)reloadFonts;

/// Returns current default font point size
- (CGFloat)fontSize;
/// Returns font scale (for mobile)
- (CGFloat)fontScale;


@end

NS_ASSUME_NONNULL_END
