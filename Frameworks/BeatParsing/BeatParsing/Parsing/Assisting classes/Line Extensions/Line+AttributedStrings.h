//
//  Line+AttributedStrings.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 29.12.2024.
//

#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol LineAttributedStringExports <JSExport>

@end

@interface Line (AttributedStrings) <LineAttributedStringExports>

/// Transforms a Beat/FDX-style attributed string back to a Fountain string.
- (NSString*)attributedStringToFountain:(NSAttributedString*)attrStr;
/// An attributed string with Final Draft compatible attribute names.
- (NSAttributedString*)attributedStringForFDX;
/// An attributed string with Final Draft compatible attribute names.
- (NSAttributedString*)attributedString;
/// An attributed string with macros resolved and formatting ranges removed
- (NSAttributedString*)attributedStringForOutputWith:(BeatExportSettings*)settings;
/// Transforms a Beat/FDX-style attributed string back to a Fountain string.
+ (NSString*)attributedStringToFountain:(NSAttributedString*)attrStr;

/// Returns and caches the line with attributes.
/// @warning This string will be created ONCE. You can't update the line properties and expect this method to reflect those changes.
// @property (nonatomic) NSAttributedString *attrString;

@end
