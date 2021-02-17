//
//  BeatFDXExport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.2.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatFDXExport : NSObject
- (instancetype)initWithString:(NSString*)string tags:(NSArray*)tags attributedString:(NSAttributedString*)attrString;
- (NSString*)fdxString;
@end

NS_ASSUME_NONNULL_END
