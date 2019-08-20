//
//  FlippedParentView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.5.2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#ifndef FlippedParentView_h
#define FlippedParentView_h

@interface FlippedParentView : NSView
@property (nonatomic) FlippedParentView *fullSizeView;
@property (nonatomic) double zoomFactor;
@end

#endif /* FlippedParentView_h */
