//
//  BeatAnalysisPanel.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.1.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatAnalysisPanel.h"
#import "FountainAnalysis.h"
#import "ContinuousFountainParser.h"

@interface BeatAnalysisPanel ()
@property (nonatomic) FountainAnalysis *analysis;
@property (nonatomic) ContinuousFountainParser *parser;
@property (weak) IBOutlet WKWebView *analysisView;
@end

@implementation BeatAnalysisPanel

- (instancetype)initWithParser:(ContinuousFountainParser*)parser delegate:(id<BeatAnalysisDelegate>)delegate {
	self = [super initWithWindowNibName:@"BeatAnalysisPanel" owner:self];
	
	self.delegate = delegate;
	
	[parser createOutline];
	self.analysis = [[FountainAnalysis alloc] init];
	
	[self.analysis setupScript:parser.lines scenes:parser.outline characterGenders:self.delegate.characterGenders];
	
	return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
	NSString *analysisPath = [[NSBundle mainBundle] pathForResource:@"analysis.html" ofType:@""];
	NSString *content = [NSString stringWithContentsOfFile:analysisPath encoding:NSUTF8StringEncoding error:nil];
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
	[self.delegate.characterGenders setObject:gender forKey:name];
}

- (IBAction)close:(id)sender {
	[self.window.sheetParent endSheet:self.window];
	[_analysisView.configuration.userContentController removeScriptMessageHandlerForName:@"setGender"];
	self.analysis = nil;
	self.analysisView = nil;
}

@end
