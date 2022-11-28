//
//  BeatAntilateralThoughts.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.9.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatAntilateralThoughts.h"
#import <Cocoa/Cocoa.h>

@interface BeatAntilateralThoughts ()
@property bool loaded;
@property (nonatomic) NSArray *thoughts;
@property (nonatomic) NSMutableArray *availableThoughts;
@property (weak) IBOutlet NSTextField *textField;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) NSString *textToAnimate;
@end
@implementation BeatAntilateralThoughts

-(instancetype)init {
	_thoughts = @[
		@"There are two ends to the line",
		@"Return back to where you were, take another path",
		@"Remember a night at home, alone",
		@"A night with people you care about the most, feeling lonely",
		@"Trees are the problem",
		@"They all are what they seem",
		@"Someone takes the honor for somebody else's work",
		@"They who live across the river don't understand us",
		@"They don't speak for themselves, somebody else does, badly",
		@"A conflict with god",
		@"Adultery and/or some horses on a foggy field",
		@"A chase",
		@"Sacrificing oneself for a meaningless cause",
		@"Dysfunctional family walks a paved road",
		@"Take a break",
		@"Looking at the rain falling on a sofa",
		@"Jealous of friends",
		@"Feeling envy for friends' success",
		@"Heartbreak is nothing to be ashamed of",
		@"Who is the one person you'd never imagine see crying?",
		@"Take off the mask of masculinity",
		@"Take away the violence (physical or psychological)",
		@"Make the most despicable person feel sympathetic",
		@"Take an idea from a documentary",
		@"How could this make the world a better place?",
		@"A change of mind for the good, for the wrong reasons",
		@"Don't get stuck in semantics",
		@"Keep on writing",
		@"List the best things, remove them",
		@"Remove every other scene",
		@"A radio is on",
		@"How did the plants feel about it?",
		@"Was the evening quiet?",
		@"Twist every ankle",
		@"Remove all meaning",
		@"Their words, not yours",
		@"Clean up your desk",
		@"How do you want it to be remembered?",
		@"Your computer is now the story",
		@"Don't use hands",
		@"Insignificant details grow big over time",
		@"Use less words",
		@"As fast as you can",
		@"As slowly & quiet as possible",
		@"Short circuit (example; peas help fertility, somebody shovels peas on their lap)",
		@"Endless patience while facing every possible obstacle",
		@"Too many pieces of furniture in a small space (like four tables)",
		@"Reckless act for a good reason",
		@"Well-thought plan for no good reason",
		@"Make it erotic",
		@"Over-ambitious ideas",
		@"Go where it's too uncomfortable",
		@"Pile up your worst trauma on a sunny meadow, burn it down",
		@"Wrongful judgement",
		@"Coup d'etat (at a small scale, say, a florists' association)",
		@"Justified act caused by false information",
		@"Computer error causes a real-life crisis",
		@"What is the last drop for the character?",
		@"They have to wait... wait... and wait. What happens?",
		@"Change their gender, what happens? *Why* couldn't you do it?",
		@"Forget success, embrace personality",
		@"Sacrificing oneself for love",
		@"Struggling against oneself",
		@"Jealousy without grounds (but is it ever OK?)",
		@"A brave and daring leap",
		@"Sudden, unexpected turn of events & tides",
		@"The sea is your worst enemy",
		@"Forget about gender",
		@"Talk & think about gender, baby",
		@"Make perfect structures feel more human",
		@"You are now lost in useless territory",
		@"Do things in a new order",
		@"Isolate yourself",
		@"Go into a dark room, enter another space",
		@"Turn a new page",
		@"What's missing?",
		@"Is there any wind?",
		@"Is it your memory? Make it theirs",
		@"Just go on",
		@"Is it finished already?",
		@"Ghosts or scratches behind the walls",
		@"What's the sound on the roof?",
		@"Think of a fantastic event, were there witnesses?",
		@"Go to an extreme, look back to where you came",
		@"Underline the flaws",
		@"Burn everything down",
		@"Don't avoid the easy choices",
		@"Make it more or less truthful",
		@"Did they lie?",
		@"Build a bridge, burn it down",
		@"Be outrageous",
		@"Be dirty",
		@"Be even weirder",
		@"A crooked tooth",
		@"COURAGE.",
		@"Ask somebody around you for advice",
		@"Take the first steps again",
		@"Abandon what you're comfortable with",
		@"Watch a video",
		@"Random characters, random words, look up meaning",
		@"Could they live in a forest?",
		@"Where did they come from? Is there a lighthouse?",
		@"Is the path clear?",
		@"Think of it as a caterpillar, moving",
		@"It is a machinery, producing an outcome",
		@"David never beats Goliath",
		@"Folk tales take a modern form",
		@"Abandon ambitions",
		@"Move away from someone who was central at first",
		@"Reconsider the first sentences",
		@"Consider a happy ending",
		@"Do nothing today, until you need to",
		@"Distort the time",
		@"Discard your best ideas for new ones",
		@"Decorate the room",
		@"Do something boring as long as possible",
		@"Impossible things happen",
		@"Shattering a belief",
		@"Question the hero's personality",
		@"Is anyone really innocent - no/maybe",
		@"Important voice messages",
		@"Does it have to be a man",
		@"Is it human? Put in imperfections.",
		@"Make it more sensual",
		@"Torn shoelaces",
		@"Ask somebody who knows more than you",
		@"Ask a person who knows nothing",
		@"Ask them what is important",
		@"A shore with familiar faces you've never met",
		@"Make them meet the author",
		@"Make somebody else tell the story",
		@"Use an old, discarded idea",
		@"How far can you go?",
		@"That plant did talk, you didn't imagine it",
		@"Talking animals",
		@"Turn a taste into images",
		@"Remove what you don't really know",
		@"Your home after the great flood",
		@"Something is emerging from the waves",
		@"Humans are made of bacteria. What's their story?",
		@"That door is locked. What do you do?",
		@"Tender obstacles guiding the way",
		@"Turn off the electricity. Total darkness. Proceed.",
		@"Change the circumstances",
		@"In a room full of noise, decide where to look",
		@"Parrots meeting a caged bird on windowsill",
		@"Use stray dogs or forks as an allegory",
		@"Steal a solution",
		@"Make everything old",
		@"Make things a little too easy",
		@"Voice everyone's suspicions",
		@"Forget about subtext, make it direct",
		@"It's spring. The air is filled with panic.",
		@"On top of their walls, security cameras are watching us",
		@"Allow the loss of control",
		@"Make up your own (non-evil) religion",
		@"Remembering somebody else's memories",
		@"Wise sisters who sleep next to each other",
		@"A character in a wrong film",
		@"Genius but unappreciated idea (like robotic animals in a zoo)",
		@"Take silence of libraries, put it somewhere else",
		@"Move the idea elsewhere",
		@"Abandon dreams, make space for new hope",
		@"Listen to other organs than the heart: kidney, lungs, arteries",
		@"Which part of your clothes is cursed?",
		@"Lift a curse",
		@"Take a sentence out of your favourite book",
		@"Steal a line from your favourite song",
		@"The messianic figure arrives without a warning",
		@"Constantly worrying if the stove is left on (Turns out it is)",
		@"Pre-apocalyptic events",
		@"Reorganize: alphabetical, chronological or biographical order?",
		@"Make everything backwards",
		@"Every mistake was intentional",
		@"Abandon structure",
		@"Put in everything you feel now",
		@"Put in everything you are thinking now",
		@"A childhood swing still keeps swinging",
		@"If water is black, what color is the sky?",
		@"How would that one person feel about the story?",
		@"Postcard from this world to you",
		@"A quiet evening alone (who?)",
		@"What is it without the mystery?",
		@"Do something you'd never do",
		@"The story is like a caterpillar",
		@"Make them pet an inanimate object",
		@"Make it *supra-natural*",
		@"Put yourself in the story",
		@"Sunbathers keep on bathing as the world ends",
		@"Good intentions but different approaches",
		@"Chain reactions from insignificant events",
		@"Every success is a failure",
		@"(as ominous music rises)",
		@"In walks a doppelgänger",
		@"Living in somebody else's body",
		@"Leave everything behind and follow",
		@"Floating above ground",
		@"Abrupt interruption",
		@"Cut every other scene, does it work?",
		@"The snow burned all night",
		@"Silly justifications for actions",
		@"Waiting for a better weather",
		@"Faking an amnesia",
		@"Empty streets",
		@"Awful sounds all around",
		@"A circular river",
		@"It is dark all the time, no use for clocks",
		@"Start your story after the end",
		@"How would the story unfold in medieval age?",
		@"Sitting at windows, waiting"
	];

	_availableThoughts = _thoughts.mutableCopy;
	
	return [super init];
}

-(void)awakeFromNib {
	[self refresh:self];
	
	_loaded = YES;
}

- (IBAction)refresh:(id)sender {
	int i = arc4random_uniform((uint32_t)self.availableThoughts.count - 1);
	NSString *text = _availableThoughts[i];
	[_availableThoughts removeObjectAtIndex:i];
	
	// We've run out of thoughts
	if (_availableThoughts.count == 0) _availableThoughts = _thoughts.mutableCopy;

	[self animateText:text];
}

- (void)animateText:(NSString*)string {
	[_timer invalidate];
	_textToAnimate = string;
	
	// Don't animate on load
	if (!_loaded) {
		[self.textField setStringValue:string];
		return;
	}
		
	[self.textField setStringValue:@""];
	_timer = [NSTimer scheduledTimerWithTimeInterval:0.025 repeats:YES block:^(NSTimer * _Nonnull timer) {
		if (self.textToAnimate.length != self.textField.stringValue.length) {
			[self.textField setStringValue:[self.textToAnimate substringToIndex:self.textField.stringValue.length + 1]];
		} else {
			[self.timer invalidate];
		}
	}];
}

@end
