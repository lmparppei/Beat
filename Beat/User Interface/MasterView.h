//
//  MasterView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 5.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MasterView : NSView
@property (nonatomic) NSTrackingArea *trackingArea;
@property (nonatomic, weak) NSWindow *parentWindow;
@property (nonatomic) NSTimer *mouseMoveTimer;
@property (nonatomic) NSWindowStyleMask styleMask;

@property (nonatomic) bool titleBarVisible;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *topContraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *outlineConstraint;

@end

NS_ASSUME_NONNULL_END
