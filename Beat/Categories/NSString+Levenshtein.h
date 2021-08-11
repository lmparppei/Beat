//
//  NSString+Levenshtein.h
//

#import <Foundation/Foundation.h>

@interface NSString (Levenshtein)
-(float)compareWithString:(NSString *)comparisonString;
@end
