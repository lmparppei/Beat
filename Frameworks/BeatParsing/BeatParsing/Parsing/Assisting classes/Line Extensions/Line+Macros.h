//
//  Line+Macros.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 10.8.2026.
//

#import <BeatParsing/BeatParsing.h>

NS_ASSUME_NONNULL_BEGIN

@interface Line (Macros)
/// Parses and resolves macros on a line and stores the parsed content in  `resolvedMacros` dictionary, mapped to macro range key. The actual values are stored as attributes and only replaced when rendering to attributed string.
- (void)resolveMacrosWithParser:(BeatMacroParser*)macroParser;
@end

NS_ASSUME_NONNULL_END
