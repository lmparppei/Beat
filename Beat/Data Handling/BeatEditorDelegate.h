//
//  BeatEditorDelegate.h
//  
//
//  Created by Lauri-Matti Parppei on 8.4.2021.
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if TARGET_OS_IOS
    #import <UIKit/UIKit.h>
#endif

@class OutlineScene;

@protocol BeatEditorDelegate <NSObject>

@property (nonatomic) OutlineScene *currentScene;
@property (nonatomic, readonly) bool printSceneNumbers;
@property (nonatomic, readonly) bool showSceneNumberLabels;

@property (nonatomic, readonly) CGFloat magnification;
@property (nonatomic) CGFloat inset;
@property (nonatomic, readonly) NSUInteger documentWidth;

- (NSMutableArray*)scenes;
- (NSMutableArray*)getOutlineItems;
- (NSMutableArray*)lines;
- (NSString*)getText;

- (NSRange)selectedRange;
- (NSArray*)getOutline; // ???
- (OutlineScene*)getCurrentScene;

- (void)addStoryline:(NSString*)storyline to:(OutlineScene*)scene;
- (void)removeStoryline:(NSString*)storyline from:(OutlineScene*)scene;
- (void)setColor:(NSString *) color forScene:(OutlineScene *) scene;
- (bool)caretAtEnd;

- (bool)isDark;

- (void)showLockStatus;
- (bool)contentLocked;

#if TARGET_OS_IOS
    - (CGFloat)fontSize;
#endif

@end


