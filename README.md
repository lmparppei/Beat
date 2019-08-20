# Beat

A simple and elegant screenwriting app for macOS, using the plain-text Fountain screenplay format. It's pretty fast and lighteight and, above all, has a distraction free, minimalistic UI. Beat is also **free and open source** and will remain so.

Read more on Beat website: https://kapitan.fi/beat/

Beat is originally a fork of **Writer** by Hendrik Noeller (https://github.com/HendrikNoeller/Writer/) and still leans on his work, especially with the magnificent continuous Fountain parser.

This started as a personal project as I needed a simple, multi-window and lightweight screenwriting application for my own films, preferrably using Fountain files. The ones that existed were weird, expensive and/or cumbersome or even lacked some pretty important features - such as automatic and visible scene numbering while writing.

I am an artist and a filmmaker, and my programming skills are somewhat limited. I'm open to any suggestions, improvements, feedback and collaboration.

## Latest release: Beat 1.0.7b

* Outline card view (implemented in a separate WebView)
* Autocomplete characters and scene headings
* Automatic scene numbering in edit view. Recognizes Fountain forced scene numbers.
* Set colors for scene headings, synopses and sections by typing `[[COLOR RED]]` (or any other common color) after the heading. This is an experimental feature for now, and has some unfortunate bugs with undoing.
* Small visual bug fixes

**Note:** This repository follows my development and usually DOES NOT match the released versions. Dread lightly, dear friend!

## Future

### State of development

Beat is under active development when I have the time or desperately need a new feature myself. Worst bugs will usually be fixed ASAP.

The app is now pretty stable and has remained very minimalistic since its inception. Outline card view was be the biggest new feature since version 1.0.3.

Some future considerations:

* Visual margins in edit view 
* Timeline view (with chronometry) 
* Drag & drop scenes in the card view 
* Fix problems with copying and pasting text 
* Have Beat only allow happy endings
* Making the world a better place 
* Planting some trees to fight climate change 

### How can you help?

Well, I'm not sure, but please do. As stated above, the person behind this project is not a real programmer but a director, screenwriter and musician. Writing Objective-C has been a bit overwhelming, and because of that, Document.m has become a 2500-line monster that handles too many things.

Bug reports, some donations and feedback help, but I'd be happy if someone could help with zooming and rearranging the code.


Lauri-Matti Parppei  
KAPITAN!  
https://kapitan.fi/