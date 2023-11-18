//
//  BeatAnalysisPanel.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.1.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import "BeatStatisticsPanel.h"
#import "FountainAnalysis.h"
#import <BeatCore/BeatLocalization.h>

@interface BeatStatisticsPanel ()
@property (nonatomic) FountainAnalysis *analysis;
@property (nonatomic) ContinuousFountainParser *parser;
@property (weak) IBOutlet WKWebView *analysisView;
@end

@implementation BeatStatisticsPanel

- (instancetype)initWithParser:(ContinuousFountainParser*)parser delegate:(id<BeatEditorDelegate>)delegate {
	self = [super initWithWindowNibName:@"BeatStatisticsPanel" owner:self];
	
	self.delegate = delegate;
	self.analysis = [[FountainAnalysis alloc] initWithDelegate:self.delegate];
	
	return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
	
	NSString *analysisPath = [NSBundle.mainBundle pathForResource:@"BeatStatisticsPanel" ofType:@"html"];
	NSString *content = [NSString stringWithContentsOfFile:analysisPath encoding:NSUTF8StringEncoding error:nil];
	content = [BeatLocalization localizeString:content];
	
	[self.analysisView.configuration.userContentController addScriptMessageHandler:self name:@"setGender"];
	[self.analysisView loadHTMLString:content baseURL:nil];
}

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
	NSString *jsonString = [self.analysis getJSON];
	NSString *javascript = [NSString stringWithFormat:@"refresh(%@)", jsonString];
	[_analysisView evaluateJavaScript:javascript completionHandler:nil];
}

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message {
	if ([message.name isEqualToString:@"setGender"]) {
		if ([message.body rangeOfString:@":"].location != NSNotFound) {
			NSArray *nameAndGender = [message.body componentsSeparatedByString:@":"];
			NSString *name = [nameAndGender objectAtIndex:0];
			NSString *gender = [nameAndGender objectAtIndex:1];
			[self setGenderFor:name gender:gender];
		}
	}
}
- (void)setGenderFor:(NSString*)name gender:(NSString*)gender {
	NSMutableDictionary* genders = self.delegate.characterGenders.mutableCopy;
	[genders setValue:gender forKey:name];
	self.delegate.characterGenders = genders;
}

- (IBAction)close:(id)sender {
	[self.window.sheetParent endSheet:self.window];
	
	[_analysisView.configuration.userContentController removeScriptMessageHandlerForName:@"setGender"];
	
	self.analysis = nil;
	self.analysisView = nil;
}

@end
