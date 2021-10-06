//
//  BeatTextStorage.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 4.10.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatTextStorage.h"

@interface BeatTextStorage ()
@property (nonatomic, readonly) NSString* string;
@end

@implementation BeatTextStorage
@synthesize delegate;

- (id) init {
	self = [super init];

 if (self != nil) {
	 storage = [[NSMutableAttributedString alloc] init];
 }

 return self;
}

- (NSString *) string {
	return [storage string];
}

- (void) replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
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

-(void)endEditing {
	[super endEditing];
	[self.delegate didPerformEdit:self.editedRange];
}

-(NSDictionary<NSAttributedStringKey,id> *)beatAttributesAtIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit {
	NSDictionary<NSAttributedStringKey,id> * attributes = [storage attributesAtIndex:location longestEffectiveRange:range inRange:rangeLimit];
	if (attributes[@"Revision"] || attributes[@"Tag"]) {
		NSMutableDictionary *beatAttrs = [NSMutableDictionary dictionary];
		
		if (attributes[@"Revision"] != nil) beatAttrs[@"Revision"] = attributes[@"Revision"];
		if (attributes[@"BeatTag"] != nil) beatAttrs[@"BeatTag"] = attributes[@"BeatTag"];
		
		return beatAttrs;
	} else {
		return attributes;
	}
}

-(NSDictionary<NSAttributedStringKey,id> *)beatAttributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range {
	NSDictionary<NSAttributedStringKey,id> * attributes = [storage attributesAtIndex:location effectiveRange:range];
	
	if (attributes[@"Revision"] || attributes[@"Tag"]) {
		NSMutableDictionary *beatAttrs = [NSMutableDictionary dictionary];
		
		if (attributes[@"Revision"] != nil) beatAttrs[@"Revision"] = attributes[@"Revision"];
		if (attributes[@"BeatTag"] != nil) beatAttrs[@"BeatTag"] = attributes[@"BeatTag"];
		
		return beatAttrs;
	} else {
		return attributes;
	}
	
	return [storage attributesAtIndex:location effectiveRange:range];
}


-(NSDictionary<NSAttributedStringKey,id> *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range {
	return [storage attributesAtIndex:location effectiveRange:range];
}

-(NSAttributedString *)attributedSubstringFromRange:(NSRange)range {
	return [super attributedSubstringFromRange:range];
}

@end
