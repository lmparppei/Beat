//
//  BeatTextStorage.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 4.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 Some ideas and tests. Unused for now.
 
 */

#import "BeatTextStorage.h"

@interface BeatTextStorage ()
@property (nonatomic) bool processing;
@property (nonatomic) NSTimer* timer;
@end

@implementation BeatTextStorage
@synthesize delegate;

- (id) init {
	self = [super init];

 if (self != nil) {
	 storage = NSMutableAttributedString.new;
 }

 return self;
}

- (NSString *)string {
	return [storage string];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
	[storage replaceCharactersInRange:range withString:str];
	[self edited:NSTextStorageEditedCharacters range:range changeInLength:[str length] - range.length];
}

- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range {
	[storage setAttributes:attrs range:range];
	[self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

-(NSDictionary<NSAttributedStringKey,id> *)attributesAtIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit {
	return [storage attributesAtIndex:location longestEffectiveRange:range inRange:rangeLimit];
}

-(void)edited:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta {
	[super edited:editedMask range:editedRange changeInLength:delta];
}

-(void)endEditing {
	[super endEditing];
}

-(NSDictionary<NSAttributedStringKey,id> *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range {
	return [storage attributesAtIndex:location effectiveRange:range];
}

-(NSAttributedString *)attributedSubstringFromRange:(NSRange)range {
	return [super attributedSubstringFromRange:range];
}


@end
