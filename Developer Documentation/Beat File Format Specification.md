#  Beat File Format

## Fountain

Beat document (almost) fully conforms to the Fountain markup specification: http://fountain.io/
The only thing missing are notes spanning over multiple lines. That is being worked on.

The files are saved using `.fountain` extension to maintain compatibility with other Fountain editors, such as Slugline, Logline and Highland. Basically everything should be readable in any other app, save for ranges marked for removal. They appear as plain text. 

Beat parses lowercase scene headings as scenes (ie. *int. home*), but once the file is saved, they are converted to uppercase, except for forced headings. They are still rendered as uppercase in Beat.


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





