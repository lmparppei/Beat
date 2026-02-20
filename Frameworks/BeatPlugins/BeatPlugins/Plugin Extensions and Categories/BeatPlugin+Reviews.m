//
//  BeatPlugin+Reviews.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 12.2.2026.
//

#import "BeatPlugin+Reviews.h"
#import <BeatCore/BeatCore-Swift.h>

@implementation BeatPlugin (Reviews)

#pragma mark - Reviews

- (BeatReview*)reviews
{
    return self.delegate.review;
}

@end
