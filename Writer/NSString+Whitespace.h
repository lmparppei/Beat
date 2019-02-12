//
//  NSString+Whitespace.h
//  Writer
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Whitespace)

- (bool)containsOnlyWhitespace;
- (bool)containsOnlyUppercase;
@end
