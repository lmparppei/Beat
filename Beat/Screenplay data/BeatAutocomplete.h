//
//  BeatAutocomplete.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatCore/BeatEditorDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatAutocomplete : NSObject {
	NSMutableArray *characterNames;
	NSMutableArray *sceneHeadings;
}

@property (nonatomic, weak) IBOutlet id<BeatEditorDelegate> delegate;
- (void)autocompleteOnCurrentLine;
- (void)collectHeadings;
- (void)collectCharacterNames;
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
@end

NS_ASSUME_NONNULL_END
