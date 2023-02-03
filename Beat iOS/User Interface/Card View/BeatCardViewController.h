//
//  BeatCardViewController.h
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 31.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <BeatCore/BeatEditorDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatCardViewController : UIViewController
@property (weak) id<BeatEditorDelegate> editorDelegate;
@end

NS_ASSUME_NONNULL_END
