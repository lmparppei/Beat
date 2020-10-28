//
//  FDXInterface.h
//  Writer / Beat
//
//  Created by Hendrik Noeller on 07.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDXInterface : NSObject

+ (NSString*)fdxFromString:(NSString*)string;
+ (void)escapeString:(NSMutableString*)string;

@end
