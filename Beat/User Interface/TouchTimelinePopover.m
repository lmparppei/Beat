//
//  TouchTimelinePopover.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 28.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "TouchTimelinePopover.h"

@implementation TouchTimelinePopover
-(void)showPopover:(id)sender {
	[super showPopover:sender];
	[self.delegate touchPopoverDidShow];
}
-(void)dismissPopover:(id)sender {
	[super dismissPopover:sender];
}
@end
/*
 
 voi pientä juhlijaa
 aamu alkaa jo sarastaa
 kello viisi on
 
 vaellat yössä yksinään
 väsymys käy jo käpälään
 et löydä tietä kotiin
 
 */
