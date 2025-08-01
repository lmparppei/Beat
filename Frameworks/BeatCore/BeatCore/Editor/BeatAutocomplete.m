//
//  BeatAutocomplete.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatUserDefaults.h>
#import <BeatCore/BeatAutocomplete.h>

@interface BeatAutocomplete ()
@end

@implementation BeatAutocomplete 

- (void)collectCharacterNames {
	/*
	 
	 So let me elaborate a bit. This is currently two systems upon each
	 other and two separate lists of character names are stored.
	 
	 Other use is to collect character cues for autocompletion.
	 There, it doesn't really matter if we have strange stuff after names,
	 because different languages can use their own abbreviations.
	 
	 Characters are also collected for the filtering feature, so we will
	 just strip away everything after the name (such as V.O. or O.S.), and
	 hope for the best.
		  
	 */
	
	[_characterNames removeAllObjects];
    if (_characterNames == nil) _characterNames = NSMutableArray.new;
    
    NSMutableArray *characterList = NSMutableArray.new;
    NSMutableDictionary <NSString*, NSNumber*>* charactersAndLines = NSMutableDictionary.new;
    
	Line* currentLine = self.delegate.currentLine;
	
	for (Line *line in self.delegate.parser.lines) {
		if ((line.isAnyCharacter) && line != currentLine
			) {
			// Character name, EXCLUDING any suffixes, such as (CONT'D), (V.O.') etc.
			NSString *character = line.characterName;
			// For some reason there are random misinterpretations of character cues, so skip empty lines
			if (character.length == 0) continue;
			
			// Add the character + suffix into dict and calculate number of appearances
			if (charactersAndLines[character] != nil) {
				NSInteger lines = charactersAndLines[character].integerValue + 1;
				charactersAndLines[character] = [NSNumber numberWithInteger:lines];
			} else {
				charactersAndLines[character] = [NSNumber numberWithInteger:1];
			}
			
			// Add character to list
			if (character && ![characterList containsObject:character]) {
				[characterList addObject:character];
			}
		}
	}
	
	// Collect character name suggestions from running plugins
#if !TARGET_OS_IOS
	for (NSString* pluginName in _delegate.runningPlugins.allKeys) {
		id<BeatAutocompletionProvider> plugin = (id<BeatAutocompletionProvider>)_delegate.runningPlugins[pluginName];
		[_characterNames addObjectsFromArray:[plugin completionsForCharacters]];
	}
#endif
	
	// Create an ordered list with all the character names.
	// The one with the most lines will be the first suggestion.
	// Btw, I don't think this works :-)
	NSArray *characters = [charactersAndLines keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2){
		// These keys are always integers
		NSInteger val1 = ((NSString*)obj1).integerValue;
		NSInteger val2 = ((NSString*)obj2).integerValue;
		return val2 > val1;
	}];
	[_characterNames addObjectsFromArray:characters];

}

- (void)collectHeadings {
    if (_sceneHeadings == nil) _sceneHeadings = NSMutableArray.new;
    [_sceneHeadings removeAllObjects];
    
	Line *currentLine = self.delegate.currentLine;
	
	for (Line *line in self.delegate.parser.lines) {
		NSString *sceneHeading = line.stripFormatting;
		
		if (line.type == heading &&
			line != currentLine &&
			![_sceneHeadings containsObject:sceneHeading]) {
			[_sceneHeadings addObject:sceneHeading];
		}
	}
	
	for (NSString* pluginName in _delegate.runningPlugins.allKeys) {
        // Force cast required for conformance here.
		id<BeatAutocompletionProvider> plugin = (id<BeatAutocompletionProvider>)_delegate.runningPlugins[pluginName];
		[_sceneHeadings addObjectsFromArray:[plugin completionsForSceneHeadings]];
	}

    [_sceneHeadings sortUsingSelector:@selector(compare:)];
}

- (void)autocompleteOnCurrentLine {
	Line *currentLine = self.delegate.currentLine;
	
	// We'll only autocomplete when cursor is at the end of line.
	if (_delegate.selectedRange.location != NSMaxRange(currentLine.textRange)) {
		[_delegate setAutomaticTextCompletionEnabled:NO];
		return;
	}

	if (currentLine.isAnyCharacter || currentLine.forcedCharacterCue) {
		if (_characterNames.count == 0) [self collectCharacterNames];
		[_delegate setAutomaticTextCompletionEnabled:YES];
	} else if (currentLine.type == heading) {
		if (_sceneHeadings.count == 0) [self collectHeadings];
		[_delegate setAutomaticTextCompletionEnabled:YES];
	} else {
		[_characterNames removeAllObjects];
		[_sceneHeadings removeAllObjects];
		[_delegate setAutomaticTextCompletionEnabled:NO];
	}
}

#pragma mark - Autocomplete delegate method (forwarded from document)

- (NSArray<NSString*>*)completionsForPartialWordRange:(NSRange)charRange {
    NSMutableArray *matches = NSMutableArray.new;
    NSMutableArray *allSuggestions = NSMutableArray.new;
    
    Line *currentLine = self.delegate.currentLine;
    NSString* stringToSearch = [_delegate.text substringWithRange:charRange].uppercaseString;
    NSString* prefix = @"";
    
    // Scene headings will ignore the prefix
    if (currentLine.type == heading) {
        prefix = sceneHeadingPrefix(stringToSearch);
        stringToSearch = [stringToSearch stringByReplacingOccurrencesOfString:prefix withString:@""].trim;
        
        if (prefix.length > 0) {
            if (![prefix containsString:@"."]) prefix = [prefix stringByAppendingString:@"."];
            prefix = [NSString stringWithFormat:@"%@ ", prefix];
        }
    }
    
    // Choose which array to search
    if (currentLine.type == character) allSuggestions = _characterNames;
    else if (currentLine.type == heading) allSuggestions = _sceneHeadings;
    
    // Find matching lines for the partially typed line
    for (NSString *string in allSuggestions) {
        NSString* suggestion = string.uppercaseString;
        
        if (currentLine.type == heading) {
            NSString* suggestionPrefix = sceneHeadingPrefix(suggestion);
            suggestion = [suggestion stringByReplacingOccurrencesOfString:suggestionPrefix withString:@""].trim;
        }
        
        bool found = false;
        if (stringToSearch.length == 0) {
            // anything goes
            found = true;
        } else if ([suggestion rangeOfString:stringToSearch options:NSAnchoredSearch range:NSMakeRange(0, suggestion.length)].location != NSNotFound) {
            found = true;
        }
        
        NSString* fullSuggestion = [NSString stringWithFormat:@"%@%@", prefix, suggestion];
        if (found && ![matches containsObject:fullSuggestion] && fullSuggestion.length > 0) [matches addObject:fullSuggestion];
    }
    
    // If no matches were found and the line is a character cue, provide a list of extensions
    if (matches.count == 0 && currentLine.isAnyCharacter && ![currentLine.string containsString:@"("] &&
        currentLine.length > 0 && currentLine.lastCharacter == ' ') {
        NSString* name = [currentLine.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSArray* extensions = @[[NSString stringWithFormat:@"(%@)", [BeatUserDefaults.sharedDefaults get:BeatSettingScreenplayItemContd]], @"(V.O.)", @"(O.S.)"];
        
        NSMutableArray* cueExtensions = NSMutableArray.new;
        [cueExtensions addObject:name]; // Add the plain name as first option
        
        for (NSString* extension in extensions) {
            [cueExtensions addObject:[NSString stringWithFormat:@"%@ %@", name, extension]];
        }
        
        return cueExtensions;
    }
    
    return matches;
}

- (NSArray *)completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
{
    return [self completionsForPartialWordRange:charRange];
}


NSString *sceneHeadingPrefix(NSString *originalString) {
    // Forced scene heading
    if (originalString.length > 0 && [originalString characterAtIndex:0] == '.') {
        return [originalString substringFromIndex:1];
    }
    
    if ([originalString containsString:@" "]) {
        return [originalString substringToIndex:[originalString rangeOfString:@" "].location];
    } else {
        return originalString;
    }
}

@end
