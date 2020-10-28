//
//  NSString+Whitespace.h
//  Writer / Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Whitespace)

- (bool)containsOnlyWhitespace;
- (bool)containsOnlyUppercase;
- (NSString *)stringByTrimmingTrailingCharactersInSet:(NSCharacterSet *)characterSet;

@end
