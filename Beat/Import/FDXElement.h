//
//  FDXElement.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FDXElement : NSObject
@property (nonatomic) NSMutableAttributedString *text;
+ (FDXElement*)lineBreak;
+ (FDXElement*)withText:(NSString*)string;
+ (FDXElement*)withAttributedText:(NSAttributedString*)string;
- (void)addAttribute:(nonnull NSAttributedStringKey)name value:(nonnull id)value range:(NSRange)range;
- (void)addStyle:(NSString*)style to:(NSRange)range;
- (NSInteger)length;
- (void)append:(NSString*)string;
- (NSString*)fountainString;
- (NSAttributedString*)attributedFountainString;
- (NSString*)string;
- (void)setString:(NSString*)string;
- (void)insertAtBeginning:(NSString*)string;
- (void)insertAtEnd:(NSString*)string;
- (void)makeUppercase;
@end

NS_ASSUME_NONNULL_END
