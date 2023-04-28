//
//  BeatAutocomplete.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

//#import <Cocoa/Cocoa.h>
#import <BeatCore/BeatEditorDelegate.h>
#import <TargetConditionals.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatAutocompletionProvider
- (NSArray*)completionsForCharacters;
- (NSArray*)completionsForSceneHeadings;
@end

@interface BeatAutocomplete : NSObject

@property (nonatomic) NSMutableArray *characterNames;
@property (nonatomic) NSMutableArray *sceneHeadings;

@property (nonatomic, weak) IBOutlet id<BeatEditorDelegate> delegate;
- (void)autocompleteOnCurrentLine;
- (void)collectHeadings;
- (void)collectCharacterNames;
- (NSArray *)completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
- (NSArray<NSString*>*)completionsForPartialWordRange:(NSRange)charRange;
@end

NS_ASSUME_NONNULL_END
