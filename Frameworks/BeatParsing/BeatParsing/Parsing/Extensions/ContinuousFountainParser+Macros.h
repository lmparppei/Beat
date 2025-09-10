//
//  ContinuousFountainParser+Macros.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 2.9.2025.
//

#import <BeatParsing/BeatParsing.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContinuousFountainParser (Macros)

- (void)updateMacros;
- (void)resolveMacrosOn:(Line*)line parser:(BeatMacroParser*)macroParser;

@end

NS_ASSUME_NONNULL_END
