//
//  NSString+CharacterControl.h
//  Writer / Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (CharacterControl)

- (bool)containsOnlyWhitespace;
- (bool)containsOnlyUppercase;
- (bool)onlyUppercaseUntilParenthesis;
- (NSString *)stringByTrimmingTrailingCharactersInSet:(NSCharacterSet *)characterSet;
- (NSInteger)numberOfOccurencesOfCharacter:(unichar)symbol;

@end
