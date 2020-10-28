//
//  NSString+Regex.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 28/08/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableString (Regex)
-(void)replaceByRegex:(NSString*)regex withString:(NSString*)replaceString; //options:(NSRegularExpressionOptions)regexOptions range:(NSRange)range;
@end
