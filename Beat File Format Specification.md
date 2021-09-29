#  Beat File Format

## Fountain

Beat document (almost) fully conforms to the Fountain markup specification: http://fountain.io/
The only thing missing are notes spanning over multiple lines. That is being worked on.

The files are saved using `.fountain` extension to maintain compatibility with other Fountain editors, such as Slugline, Logline and Highland. Basically everything should be readable in any other app, save for ranges marked for removal. They appear as plain text. 

Beat parses lowercase scene headings as scenes (ie. *int. home*), but once the file is saved, they are converted to uppercase, except for forced headings. They are still rendered as uppercase in Beat.

## Document Settings

At the end of file, there is a special data block, which contains Review, Revision and Tagging data.

````
/* If you're seeing this, you can remove the following stuff - BEAT:
{ json data }
END_BEAT*/
````

`BeatDocumentSettings` object parser JSON block is back into an `NSMutableDictionary`, which contains the document settings. Upon saving, Beat calls a method which creates a JSON string out of the dictionary.

Document settings can contain almost anything, if encoded correctly, but I recommend using it only for text and numerical data. Note that many Objective C structures are not directly convertable to JSON. For example, `NSRange` variables should probably be stored as arrays, such as `[0, 12]`.




