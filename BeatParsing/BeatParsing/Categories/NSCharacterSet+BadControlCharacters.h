//
//  NSCharacterSet+BadControlCharacters.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 29.5.2023.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSCharacterSet (BadControlCharacters)
+ (NSCharacterSet*)badControlCharacters;
@end

NS_ASSUME_NONNULL_END
