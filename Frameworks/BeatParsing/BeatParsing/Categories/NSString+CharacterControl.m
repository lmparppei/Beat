//
//  NSString+Whitespace.m
//  Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//	Parts copyright © 2019-2021 Lauri-Matti Parppei. All rights reserved.
//

#import "NSString+CharacterControl.h"
#import <BeatParsing/NSCharacterSet+BadControlCharacters.h>
#import <NaturalLanguage/NaturalLanguage.h>

@implementation NSString (CharacterControl)

- (bool)containsOnlyWhitespace
{
    NSUInteger length = [self length];
    
    NSCharacterSet* whitespaceSet = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    for (int i = 0; i < length; i++) {
        unichar c = [self characterAtIndex:i];
        if (![whitespaceSet characterIsMember:c]) {
            return NO;
        }
    }
    return YES;
}

- (NSCharacterSet*)uppercaseLetters
{
    static dispatch_once_t once;
    static NSCharacterSet *characters;
    
    dispatch_once(&once, ^{
        // Add some symbols which are potentially not recognized out of the box.
        // List stolen from https://stackoverflow.com/questions/36897781/how-to-uppercase-lowercase-utf-8-characters-in-c
        NSMutableCharacterSet* chrs = NSCharacterSet.uppercaseLetterCharacterSet.mutableCopy;
        [chrs addCharactersInString:@"IÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞĀĂĄĆĈĊČĎĐĒĔĖĘĚĜĞĠĢĤĦĨĪĬĮİĲĴĶĹĻĽĿŁŃŅŇŊŌŎŐŒŔŖŘŚŜŞŠŢŤŦŨŪŬŮŰŲŴŶŸŹŻŽƁƂƄƆƇƊƋƎƏƐƑƓƔƖƗƘƜƝƠƢƤƧƩƬƮƯƱƲƳƵƷƸƼǄǅǇǈǊǋǍǏǑǓǕǗǙǛǞǠǢǤǦǨǪǬǮǱǲǴǶǷǸǺǼǾȀȂȄȆȈȊȌȎȐȒȔȖȘȚȜȞȠȢȤȦȨȪȬȮȰȲȺȻȽȾɁɃɄɅɆɈɊɌɎͰͲͶͿΆΈΉΊΌΎΏΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩΪΫϏϘϚϜϞϠϢϤϦϨϪϬϮϴϷϹϺϽϾϿЀЁЂЃЄЅІЇЈЉЊЋЌЍЎЏАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯѠѢѤѦѨѪѬѮѰѲѴѶѸѺѼѾҀҊҌҎҐҒҔҖҘҚҜҞҠҢҤҦҨҪҬҮҰҲҴҶҸҺҼҾӀӁӃӅӇӉӋӍӐӒӔӖӘӚӜӞӠӢӤӦӨӪӬӮӰӲӴӶӸӺӼӾԀԂԄԆԈԊԌԎԐԒԔԖԘԚԜԞԠԢԤԦԨԪԬԮԱԲԳԴԵԶԷԸԹԺԻԼԽԾԿՀՁՂՃՄՅՆՇՈՉՊՋՌՍՎՏՐՑՒՓՔՕՖႠႡႢႣႤႥႦႧႨႩႪႫႬႭႮႯႰႱႲႳႴႵႶႷႸႹႺႻႼႽႾႿჀჁჂჃჄჅჇჍᎠᎡᎢᎣᎤᎥᎦᎧᎨᎩᎪᎫᎬᎭᎮᎯᎰᎱᎲᎳᎴᎵᎶᎷᎸᎹᎺᎻᎼᎽᎾᎿᏀᏁᏂᏃᏄᏅᏆᏇᏈᏉᏊᏋᏌᏍᏎᏏᏐᏑᏒᏓᏔᏕᏖᏗᏘᏙᏚᏛᏜᏝᏞᏟᏠᏡᏢᏣᏤᏥᏦᏧᏨᏩᏪᏫᏬᏭᏮᏯᏰᏱᏲᏳᏴᏵᲐᲑᲒᲓᲔᲕᲖᲗᲘᲙᲚᲛᲜᲝᲞᲟᲠᲡᲢᲣᲤᲥᲦᲧᲨᲩᲪᲫᲬᲭᲮᲯᲰᲱᲲᲳᲴᲵᲶᲷᲸᲹᲺᲽᲾᲿḀḂḄḆḈḊḌḎḐḒḔḖḘḚḜḞḠḢḤḦḨḪḬḮḰḲḴḶḸḺḼḾṀṂṄṆṈṊṌṎṐṒṔṖṘṚṜṞṠṢṤṦṨṪṬṮṰṲṴṶṸṺṼṾẀẂẄẆẈẊẌẎẐẒẔẞẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼẾỀỂỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪỬỮỰỲỴỶỸỺỼỾἈἉἊἋἌἍἎἏἘἙἚἛἜἝἨἩἪἫἬἭἮἯἸἹἺἻἼἽἾἿὈὉὊὋὌὍὙὛὝὟὨὩὪὫὬὭὮὯᾈᾉᾊᾋᾌᾍᾎᾏᾘᾙᾚᾛᾜᾝᾞᾟᾨᾩᾪᾫᾬᾭᾮᾯᾸᾹᾺΆᾼῈΈῊΉῌῘῙῚΊῨῩῪΎῬῸΌῺΏῼⰀⰁⰂⰃⰄⰅⰆⰇⰈⰉⰊⰋⰌⰍⰎⰏⰐⰑⰒⰓⰔⰕⰖⰗⰘⰙⰚⰛⰜⰝⰞⰟⰠⰡⰢⰣⰤⰥⰦⰧⰨⰩⰪⰫⰬⰭⰮⱠⱢⱣⱤⱧⱩⱫⱭⱮⱯⱰⱲⱵⱾⱿⲀⲂⲄⲆⲈⲊⲌⲎⲐⲒⲔⲖⲘⲚⲜⲞⲠⲢⲤⲦⲨⲪⲬⲮⲰⲲⲴⲶⲸⲺⲼⲾⳀⳂⳄⳆⳈⳊⳌⳎⳐⳒⳔⳖⳘⳚⳜⳞⳠⳢⳫⳭⳲⴀⴁⴂⴃⴄⴅⴆⴇⴈⴉⴊⴋⴌⴍⴎⴏⴐⴑⴒⴓⴔⴕⴖⴗⴘⴙⴚⴛⴜⴝⴞⴟⴠⴡⴢⴣⴤⴥⴧⴭꙀꙂꙄꙆꙈꙊꙌꙎꙐꙒꙔꙖꙘꙚꙜꙞꙠꙢꙤꙦꙨꙪꙬꚀꚂꚄꚆꚈꚊꚌꚎꚐꚒꚔꚖꚘꚚꜢꜤꜦꜨꜪꜬꜮꜲꜴꜶꜸꜺꜼꜾꝀꝂꝄꝆꝈꝊꝌꝎꝐꝒꝔꝖꝘꝚꝜꝞꝠꝢꝤꝦꝨꝪꝬꝮꝹꝻꝽꝾꞀꞂꞄꞆꞋꞍꞐꞒꞖꞘꞚꞜꞞꞠꞢꞤꞦꞨꞪꞫꞬꞭꞮꞰꞱꞲꞳꞴꞶꞸꞺꞼꞾꟂꟄꟅꟆꟇꟉꟵＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ𐐀𐐁𐐂𐐃𐐄𐐅𐐆𐐇𐐈𐐉𐐊𐐋𐐌𐐍𐐎𐐏𐐐𐐑𐐒𐐓𐐔𐐕𐐖𐐗𐐘𐐙𐐚𐐛𐐜𐐝𐐞𐐟𐐠𐐡𐐢𐐣𐐤𐐥𐐦𐐧𐒰𐒱𐒲𐒳𐒴𐒵𐒶𐒷𐒸𐒹𐒺𐒻𐒼𐒽𐒾𐒿𐓀𐓁𐓂𐓃𐓄𐓅𐓆𐓇𐓈𐓉𐓊𐓋𐓌𐓍𐓎𐓏𐓐𐓑𐓒𐓓𐲀𐲁𐲂𐲃𐲄𐲅𐲆𐲇𐲈𐲉𐲊𐲋𐲌𐲍𐲎𐲏𐲐𐲑𐲒𐲓𐲔𐲕𐲖𐲗𐲘𐲙𐲚𐲛𐲜𐲝𐲞𐲟𐲠𐲡𐲢𐲣𐲤𐲥𐲦𐲧𐲨𐲩𐲪𐲫𐲬𐲭𐲮𐲯𐲰𐲱𐲲𑢠𑢡𑢢𑢣𑢤𑢥𑢦𑢧𑢨𑢩𑢪𑢫𑢬𑢭𑢮𑢯𑢰𑢱𑢲𑢳𑢴𑢵𑢶𑢷𑢸𑢹𑢺𑢻𑢼𑢽𑢾𑢿𖹀𖹁𖹂𖹃𖹄𖹅𖹆𖹇𖹈𖹉𖹊𖹋𖹌𖹍𖹎𖹏𖹐𖹑𖹒𖹓𖹔𖹕𖹖𖹗𖹘𖹙𖹚𖹛𖹜𖹝𖹞𖹟𞤀𞤁𞤂𞤃𞤄𞤅𞤆𞤇𞤈𞤉𞤊𞤋𞤌𞤍𞤎𞤏𞤐𞤑𞤒𞤓𞤔𞤕𞤖𞤗𞤘𞤙𞤚𞤛𞤜𞤝𞤞𞤟𞤠𞤡"];
        characters = chrs;
    });

    return characters;
}

- (bool)containsUppercaseLetters
{
    NSCharacterSet* characters = self.uppercaseLetters;
    bool uppercase = false;
    
    for (int i = 0; i < self.length; i++) {
        unichar c = [self characterAtIndex:i];
        if ([characters characterIsMember:c]) {
            uppercase = true; break;
        }
    }
    
    return uppercase;
}

- (NSInteger)numberOfOccurencesOfCharacter:(unichar)symbol {
	NSInteger occurences = 0;
	
	for (NSInteger i=0; i<self.length; i++) {
		if ([self characterAtIndex:i] == symbol) occurences += 1;
	}
	
	return occurences;
}

- (bool)containsOnlyUppercase
{
	return [self.uppercaseString isEqualToString:self] && [self containsUppercaseLetters];
}

- (NSString *)stringByTrimmingTrailingCharactersInSet:(NSCharacterSet *)characterSet {
	NSRange rangeOfLastWantedCharacter = [self rangeOfCharacterFromSet:characterSet.invertedSet options:NSBackwardsSearch];
	if (rangeOfLastWantedCharacter.location == NSNotFound) {
		return @"";
	}
    if (rangeOfLastWantedCharacter.location + 1 <= self.length) {
        return [self substringToIndex:rangeOfLastWantedCharacter.location+1]; // non-inclusive
    } else {
        return self;
    }
}

- (bool)onlyUppercaseUntilParenthesis
{
	NSInteger parenthesisLoc = [self rangeOfString:@"("].location;
	NSInteger noteLoc = [self rangeOfString:@"[["].location;
	
	if (noteLoc == 0 || parenthesisLoc == 0) return NO;

	if (parenthesisLoc == NSNotFound) {
		// No parenthesis
		return self.containsOnlyUppercase;
	}
    
    // We need to check past parentheses, too, in case the user started the line with something like:
    // MIA (30) does something...
    bool parenthesisOpen = false;
    bool actualCharacterFound = false;
    NSMutableIndexSet *indexSet = NSMutableIndexSet.new;
    
    for (NSInteger i=0; i<self.length; i++) {
        unichar c = [self characterAtIndex:i];
        
        if (c == ')') parenthesisOpen = false;
        else if (c == '(') parenthesisOpen = true;
        else if (!parenthesisOpen) {
            if (c != ' ') actualCharacterFound = true;
            [indexSet addIndex:i];
        }
    }
    
    __block bool containsLowerCase = false;
    [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        NSString *substr = [self substringWithRange:range];
        if (substr.containsOnlyWhitespace) return;
        else if (!substr.containsOnlyUppercase) {
            containsLowerCase = true;
            *stop = true;
        }
    }];
    
    return (!containsLowerCase && actualCharacterFound);
}

- (NSRange)rangeBetweenFirstAndLastOccurrenceOf:(unichar)chr {
    NSInteger first = NSNotFound;
    NSInteger last = 0;
    
    for (NSInteger i=0; i<self.length; i++) {
        unichar c = [self characterAtIndex:i];
        if (c == chr && first == NSNotFound) {
            first = i;
        }
        else if (c == chr) {
            last = i;
        }
    }
    
    if (first == NSNotFound) return NSMakeRange(first, 0);
    else return NSMakeRange(first, last - first);
}

- (NSString*)stringByRemovingRange:(NSRange)range {
    NSString* head = [self substringToIndex:range.location];
    NSString* tail = (NSMaxRange(range) < self.length) ? [self substringFromIndex:NSMaxRange(range)] : @"";
    
    return [NSString stringWithFormat:@"%@%@", head, tail];
}

- (NSString*)trim
{
    return [self stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

- (NSInteger)locationOfLastOccurenceOf:(unichar)chr
{
    for (NSInteger i=self.length-1; i>=0; i--) {
        unichar c = [self characterAtIndex:i];
        if (c == chr) return i;
    }
    
    return NSNotFound;
}

- (bool)hasRightToLeftText
{
    bool rightToLeft = false;
    
    /*
    // This actual language recognizer code is BRUTALLY expensive, and can spend up to 0.05 seconds detecting language for a simple string.
    // CGStringTokenizer only recognizes Arabic and Hebrew, so ... oh well.
     
    if (@available(macOS 10.14, *)) {
        NLLanguage lang = [NLLanguageRecognizer dominantLanguageForString:self];
        if (lang == NLLanguageArabic || lang == NLLanguageUrdu || lang == NLLanguagePersian || lang == NLLanguageHebrew) {
            rightToLeft = true;
        }
    }
    */
    
    if (self.length > 0) {
        NSArray *rightLeftLanguages = @[@"ar", @"he"];
        NSString *lang = CFBridgingRelease(CFStringTokenizerCopyBestStringLanguage((CFStringRef)self, CFRangeMake(0, self.length)));
        rightToLeft = [rightLeftLanguages containsObject:lang];
    }
    
    return rightToLeft;
}

- (unichar)firstNonWhiteSpaceCharacter
{
    NSInteger i = self.indexOfFirstNonWhiteSpaceCharacter;
    if (i == NSNotFound) return -1;
    else return [self characterAtIndex:i];
}

- (unichar)lastNonWhiteSpaceCharacter
{
    NSInteger i = self.indexOfLastNonWhiteSpaceCharacter;
    if (i == NSNotFound) return -1;
    else return [self characterAtIndex:i];
}

- (NSInteger)indexOfLastNonWhiteSpaceCharacter
{
    if (self.length == 0) return NSNotFound;
    
    NSInteger i = self.length - 1;
    while (i >= 0) {
        unichar c = [self characterAtIndex:i];
        
        if  (c != '\t' && c != ' ') return i;
        i--;
    }
    
    return NSNotFound;
}

- (NSInteger)indexOfFirstNonWhiteSpaceCharacter
{
    if (self.length == 0) return NSNotFound;
    
    for (NSInteger i=0; i<self.length; i++) {
        unichar c = [self characterAtIndex:i];
        
        if  (c != '\t' && c != ' ') return i;
    }
    
    return NSNotFound;
}

- (bool)inRange:(NSRange)range {
    return (NSMaxRange(range) <= self.length);
}

- (NSMutableIndexSet*)rangesBetween:(NSString*)open and:(NSString*)close excludingIndices:(NSMutableIndexSet*)excludes escapedIndices:(NSMutableIndexSet*)escapes
{
    // Let's not read ridiculously big strings into unichar arrays.
    if (self.length > 30000) return NSMutableIndexSet.new;
    
    // Read the whole string into an unichar array
    NSUInteger length = self.length;
    unichar charArray[length];
    [self getCharacters:charArray];
    
    // Create unichar arrays for open and closing delimiters
    NSUInteger openLength = open.length;
    unichar openChars[openLength];
    [open getCharacters:openChars];
    
    NSUInteger closeLength = close.length;
    unichar closeChars[closeLength];
    [close getCharacters:closeChars];
    
    return [self rangesInChars:charArray ofLength:length between:openChars and:closeChars startLength:openLength endLength:closeLength excludingIndices:excludes escapeRanges:escapes];
}

/**
 Returns all ranges between two `unichar` delimiters. Use `excludingIndices` and `escapeRanges` index sets to add and store escaped and excluded indices, ie. asterisks which were already read as part of some other set.
 */
- (NSMutableIndexSet*)rangesInChars:(unichar*)string ofLength:(NSUInteger)length between:(unichar*)startString and:(unichar*)endString startLength:(NSUInteger)startLength endLength:(NSUInteger)delimLength excludingIndices:(NSMutableIndexSet*)excludes escapeRanges:(NSMutableIndexSet*)escapeRanges
{
    NSMutableIndexSet* indexSet = NSMutableIndexSet.new;
    if (length < startLength + delimLength) return indexSet;
    
    NSRange range = NSMakeRange(-1, 0);
    
    for (NSInteger i=0; i <= length - delimLength; i++) {
        // If this index is contained in the omit character indexes, skip
        if ([excludes containsIndex:i]) continue;
        
        // First check for escape character
        if (i > 0) {
            unichar prevChar = string[i-1];
            if (prevChar == '\\') {
                [escapeRanges addIndex:i - 1];
                continue;
            }
        }
        
        if (range.location == -1) {
            // Next, see if we can find the whole start string
            bool found = true;
            for (NSInteger k=0; k<startLength; k++) {
                if (i+k >= length) {
                    break;
                } else if (startString[k] != string[i+k]) {
                    found = false;
                    break;
                }
            }
            
            if (!found) continue;
            
            // Success! We found a matching string
            range.location = i;
            
            // Pass the starting string
            i += startLength-1;
            
        } else {
            // We have found a range, let's see if we find a closing string.
            bool found = true;
            for (NSInteger k=0; k<delimLength; k++) {
                if (endString[k] != string[i+k]) {
                    found = false;
                    break;
                }
            }
            
            if (!found) continue;
            
            // Success, we found a closing string.
            range.length = i + delimLength - range.location;
            [indexSet addIndexesInRange:range];
            
            // Add the current formatting ranges to future excludes
            [excludes addIndexesInRange:(NSRange){ range.location, startLength }];
            [excludes addIndexesInRange:(NSRange){ i, delimLength }];
            
            range.location = -1;
            
            // Move past the ending string
            i += delimLength - 1;
        }
    }
    
    return indexSet;
}

/// Removes unwated Windows line breaks
- (NSString*)stringByCleaningUpWindowsLineBreaks
{
    return [self stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
}

/// Removes unwanted control characters
- (NSString*)stringByCleaningUpBadControlCharacters
{
    NSArray* items = [self componentsSeparatedByCharactersInSet:NSCharacterSet.badControlCharacters];
    return [items componentsJoinedByString:@""];
}

/// Check for Devanagari text. This is used by FDX export.
- (BOOL)containsHindi
{
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\p{InDevanagari}" options:0 error:&error];
    
    if (error) return NO;
    
    NSRange range = [regex rangeOfFirstMatchInString:self options:0 range:NSMakeRange(0, self.length)];
    return range.location != NSNotFound;
}

@end
