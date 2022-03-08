# About Beat

Hello, stranger.

A lot of the code in this project was written with very limited skills in programming. You'll see unused methods, weird duct-tape solutions and unfinished stuff here and there. Dread lightly.

Originally, 99% of the code was put inside the massive Document class, and later, as I got a bit more experienced, I started modularizing the code. It's still a mess, but at least there is *some* structure to it now. I've tried explaining and commenting my most excentric practices, but I'm often baffled myself too.    

As I'm writing this, situation in Europe is becoming very tense and it's completely possible I won't be here when you read this. There are threats of an all-out nuclear war, and the country I'm currently living in is probably next in line to be attacked. I hope Beat will live on after I'm gone, in some for or another, so I've started documenting how the app actually works.


# Overview

At the heart of Beat is the `ContinunousFountainParser`. Every change made to `BeatTextView` is parsed, and the parser itself uses `Line` objects to store information about individual lines -- their position (index), string and formatted ranges.

Beat is **not** a WYSIWYG editor, and it would be very hard to convert it to one. PDF export and printing are actually HTML documents, which are preprocessed and paginated. Parser does the preprocesing, and *BeatPaginator* splits stuff across multiple pages and is the most complicated and messed-up code in the whole project.

If you are planning on developing Beat further, I'd suggest you write a completely new screenplay rendering engine using native Cocoa drawing. Do take a look at the exporting code, though, because it's really something to marvel. It's overly complicated, everything happens in multiple steps and overall makes no fucking sense.

Because of its legacy as a fork, the app is written in Objective C. Lately, I started to experiment with Swift. There are some classes that have been either written in Swift from scratch, or have been converted from objc. I still don't get Swift at all.

There are some parts that have been completely commented out. Sometimes I've written something like *"For generations to come"* or *"And die Nachgeborenen"* next to them to make it clear that it's a planned, new solution rather than something that has been deprecated.


# Document Model

## Document

`Document` is a massive class, and I'm sorry for that. It is that because of legacy reasons (meaning me being bad at Objective C) and I'm not proud of it.

Start from `windowControllerDidLoadNib` and work from there. Document loading is throttled using chained GCD dispatches, and might be a bit confusing at first.

From there, editing a document is this constant three-way ping-pong of `BeatTextView`, `Document` and `ContinuousFountainParser`. It's often unclear what happens in `BeatTextView`, and what happens in `Document`. 

Rendering and text view specific things (such as displaying autocorrect dropdowns) is done by the text view, while formatting is handled in `Document`. And in the future, hopefully in a separate class. The document also contains the majority of `IBAction` methods, mostly being just stubs forwarding them somewhere else.

`shouldChangeTextInRange` parses the possible change **before** it is actually displayed, which means the parser knows the change ahead of time. Formatting is applied (based on parser data) when the text view calls `textDidChange`.

It's a complicated mess, but the actual formatting (found under `#pragma mark`) should be relatively easy to figure out, so maybe start from there, and work your way up. 


## Parser

`ContinuousFountainParser` is based on the work of Hendrik Noeller, though I've rewritten large chunks of it. I figured out how to optimize quite a few things, and also streamlined some of the stuff. And made some of it more complicated.

Parser **does not** use regexes, but parses changes on byte level (using `unichar` arrays) and it might look a bit weird at times, but is super fast. I've tried commenting the more confusing parts, but probably haven't covered the particular thing that confuses you.

The parser is used both while editing (live/continuous parsing) and when exporting and loading documents (static parsing). It's important to ensure that everything gets parsed correctly in both situations, because, in theory, Fountain files should be parsed from bottom to top, and here we're parsing starting from the top. We also need to perform lookbacks and correct our parses based on other surrounding lines -- and in many cases, reparse all of those affected lines.

As the parser is the oldest part of Beat, originating from somebody else's work, there are also unused, weird methods lingering here and there. All apologies. 
    

## Line

`Line`s contain all the relevant parsed data. It's mostly used for storing the parsed formatting ranges, line type etc. but line object also has some methods for joining two lines and converting their contents for further formatting, such as returning an attributed string for exporting to both HTML and Final Draft XML. 

`Line` contents changed by the parser, so you can't change *editor* contents by changing *line object* string content, which is at times frustrating. However, I *did* experiment with having a parser delegate for each line, and the parser knowing its host document, so it could relay the change forward. This didn't really make too much sense, though, and led to circulal logic.

Line types are simple objc enums. 


## Outine

Parser also creates an outline, with all the structural elements: scene headings, synopsis lines and sections. The resulting objects, clumsily named `OutlineScene`s, are just a temporary, and don't *actually* refer to anything in the document. They know the line which represents the outline element in the screenplay, position and title, and can fetch their length and other stuff, such as associated storylines and beats.

Outline has to be rebuilt each time when a change is made, and often it's safe to rebuild it by force, as you can see here and there. It's relatively fast to do, basically one iteration through all of the lines. 

I recommend reading the plugin wiki (https://github.com/lmparppei/BeatPlugins/wiki) which has document model examples. Theyare in JavaScript, but basic logic still applies.


# Plugins

Plugins work through `JavaScriptCore`. It's a convoluted system, but the actual plugins relatively simple. They are run using a single class, `BeatPlugin`, and most relevant classes have `JSExports` protocols to make them compatible with the plugin API.

Plugin Library downloads stuff from a hard-coded GitHub repository (https://github.com/lmparppei/BeatPlugins/ - see exact URL in the class). There is a chance that the plugins could do nefarious things, so all of those plugins are reviewed and approved by me, but Beat can run whatever you feed it.

To be able to provide plugins to end users in the future, you need access to that repository. There is a script called `create_json.sh` in the repository, which packages all plugins and creates the external JSON file used by Plugin Library to serve the data.   

Most plugin API methods are documented in the wiki.


# Beat File Format

## Fountain

Beat document conforms to the Fountain markup specification: http://fountain.io/

The files are saved using `.fountain` extension to maintain compatibility with other Fountain editors, such as Slugline, Logline and Highland. Everything should be readable in any other app, save for ranges marked for removal. They appear as plain text. Beat-specific stuff, such as revisions and tagging, are also unavailable in other apps. 

Beat is a bit more forgiving with some elements, such as scene headings. The parser accepts lowercase scene headings (ie. *int. home*), although they are converted to uppercase when saving, except for forced headings.


## Document Settings

At the end of file, there is a special data block, which contains document settings, things like caret position and character genders, but also all of the revision and tagging ranges.

````
/* If you're seeing this, you can remove the following stuff - BEAT:
{ json data }
END_BEAT*/
````

`BeatDocumentSettings` parses this JSON block back into an `NSMutableDictionary`, which contains the document settings. Upon saving, Beat calls a method which creates a JSON string out of the dictionary.

If encoded correctly, document settings can contain almost any sort of information, but I recommend using it only for text and numerical data. Note that many Objective C structures are not directly convertable to JSON, so `NSDictionary` serializes them as arrays. For example, `NSRange` becomes something like `[0, 12]`.

There are standard keywords for certain settings, which you can see in the class itself, but the block can contain other settings too. For example, plugins can write their own settings into the file, usually prefixed by plugin name, ie. `"PluginName: setting"`.



# Post-mortem

Beat began as a personal project, and became something else. I hope I'm still here and keep on developing the app on my spare time. There are many things I could have done with the hundreds or thousands of hours I put into this app -- spend time with my loved ones, take long walks or plant flowers and trees -- but I'm glad I did what I did.

The app has made it possible to interact with great people, provide the best screenwriting experience I've had, and also write stuff of my own. I've enjoyed most of the time I've spent with Beat. I began working on it when I was recovering from an abusive relationship, and learning to code got my thoughts away from the fear and post-traumatic stress I was experiencing.

I hope that, you who found this file, will take on Beat as a passion project of your own. I'll keep on expanding this "documentation" and commenting the code to clarify my esoteric practices. 

   *"Remember the flight
    the bird will die"*
	Forough Farrokhzad 


All the best,
Lauri-Matti

Helsinki, Finland
March 2022  

