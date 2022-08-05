//
//  RenderStyleReader.m
//  PrintLayoutTests
//
//  Created by Lauri-Matti Parppei on 7.7.2021.
//
/*
 
 Reads a faux-CSS file into an NSDictionary
 
 */

#import "RenderStyles.h"
#import "RegExCategories.h"
#import "Beat-Swift.h"

@implementation RenderStyles

+ (RenderStyles*)shared {
	static RenderStyles* reader;
	if (reader == nil) reader = RenderStyles.new;
	
	return reader;
}

- (NSDictionary<NSString*, RenderStyle*>*)styles {
	if (_styles != nil) return _styles;
	
	NSURL *url = [NSBundle.mainBundle URLForResource:@"Export Styles" withExtension:@"beatCSS"];
	NSString *stylesheet = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
	_styles = [self readStyle:stylesheet];
	
	return _styles;
}

- (RenderStyle*)forElement:(NSString*)name {
	return _styles[name];
}
- (RenderStyle*)page {
	return _styles[@"Page"];
}

- (NSDictionary<NSString*, RenderStyle*>*)readStyle:(NSString*)stylesheet {
	NSMutableDictionary <NSString*, RenderStyle*>*styles = NSMutableDictionary.new;

    // Remove comments
    Rx* commentEx = [Rx rx:@"/\\*(.+?)\\*/" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators];
    stylesheet = [stylesheet replace:commentEx with:@""];
    
    // Regular expressions for styles
    Rx* styleEx = [Rx rx:@"(.+?)\\{(.+?)\\}" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators];
    Rx* ruleEx = RX(@"(.*):(.*);\\n");
    
    
    NSArray* styleMatches = [stylesheet matchesWithDetails:styleEx];
    
    for (RxMatch *match in styleMatches) {
    
        NSString *styleName = [(RxMatchGroup*)match.groups[1] value];
        NSString *ruleContent = [(RxMatchGroup*)match.groups[2] value];
        
        styleName = [styleName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        
        RenderStyle *rStyle;
        if (styles[styleName]) rStyle = styles[styleName];
		else rStyle = RenderStyle.new;
        
        // for allowing style definitions like "Action, Dialogue"
        //NSMutableArray *styleNames = [NSMutableArray array];
        //NSMutableDictionary *rules = [NSMutableDictionary dictionary];
        
        /*
        if ([styleName rangeOfString:@","].location != NSNotFound) {
            NSArray *allStyles = [styleName componentsSeparatedByString:@","];
            for (NSString *substyle in allStyles) {
                [styleNames addObject:[substyle stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
            }
        }
         */
        
        NSArray *ruleMatches = [ruleContent matchesWithDetails:ruleEx];
    
        for (RxMatch *ruleMatch in ruleMatches) {
            NSString *rule = [[(RxMatchGroup*)ruleMatch.groups[1] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            NSString *value = [[(RxMatchGroup*)ruleMatch.groups[2] value] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            //[rules setValue:value forKey:rule];
            
            id writtenValue = value;
            if ([value isEqualToString:@"true"]) writtenValue = @(true);
            if ([value isEqualToString:@"false"]) writtenValue = @(false);
            
            [rStyle setValue:writtenValue forKey:rule];
        }
        
        /*
        if (styleNames.count == 0) {
            [styles setValue:rules forKey:styleName];
        } else {
            for (NSString *styleName in styleNames) {
                if (styles[styleName]) {
                    NSMutableDictionary *existingRules = [NSMutableDictionary dictionaryWithDictionary:styles[styleName]];
                    [existingRules addEntriesFromDictionary:rules];
                    [styles setValue:existingRules forKey:styleName];
                } else {
                    [styles setValue:rules forKey:styleName];
                }
            }
        }
         */
        
        [styles setValue:rStyle forKey:styleName];
    }
    
    return styles;
}

@end
