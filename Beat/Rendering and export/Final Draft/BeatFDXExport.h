//
//  BeatFDXExport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.2.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatFDXExport : NSObject
- (instancetype)initWithString:(NSString*)string attributedString:(NSAttributedString*)attrString includeTags:(bool)includeTags includeRevisions:(bool)includeRevisions paperSize:(BeatPaperSize)paperSize;
- (NSString*)fdxString;
@end

NS_ASSUME_NONNULL_END
