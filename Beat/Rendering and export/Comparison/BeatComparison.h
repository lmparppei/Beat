//
//  BeatComparison.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.10.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BeatComparison : NSObject
- (NSDictionary*)changeListFrom:(NSString*)oldScript to:(NSString*)newScript;
- (NSAttributedString*)getRevisionsComparing:(NSArray*)script with:(NSString*)oldScript;
- (NSAttributedString*)getRevisionsComparing:(NSArray*)script with:(NSString*)oldScript fromIndex:(NSInteger)startIndex;
@end
