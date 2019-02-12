//
//  ApplicationDelegate.m
//  Writer
//
//  Created by Hendrik Noeller on 18.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import "ApplicationDelegate.h"

@implementation ApplicationDelegate

#pragma mark - Help

- (IBAction)showReference:(id)sender
{
    NSURL* referenceFile = [[NSBundle mainBundle] URLForResource:@"Reference"
                                                   withExtension:@"fountain"];
    void (^completionHander)(NSDocument * _Nullable, BOOL, NSError * _Nullable) = ^void(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
        [document setFileURL:[[NSURL alloc] init]];
    };
    [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:referenceFile
                                                                           display:YES
                                                                 completionHandler:completionHander];
}

- (IBAction)showFountainSyntax:(id)sender
{
    [self openURLInWebBrowser:@"http://www.fountain.io/syntax#section-overview"];
}

- (IBAction)showFountainWebsite:(id)sender
{
    [self openURLInWebBrowser:@"http://www.fountain.io"];
}

- (IBAction)showWriterOnGitHub:(id)sender
{
    [self openURLInWebBrowser:@"https://github.com/HendrikNoeller/Writer-Mac"];
}

- (void)openURLInWebBrowser:(NSString*)urlString
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}
@end
