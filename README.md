# Beat

A simple and elegant screenwriting app for macOS, using the plain-text Fountain screenplay format. It's pretty fast and lighteight and, above all, has a distraction free, minimalistic UI. Beat is also **free and open source**.

Read more on Beat website: https://kapitan.fi/beat/

Beat is originally a fork of **Writer** by Hendrik Noeller (https://github.com/HendrikNoeller/Writer/) and still leans on his work, especially with the magnificent continuous Fountain parser.

This started as a personal project as I needed a simple, multi-window and lightweight screenwriting application for my own films, preferrably using Fountain files. The ones that existed were expensive and/or cumbersome , weird or lacked some pretty important features  - such as automatic scene numbering.

I am an artist and a filmmaker, and my programming skills are somewhat limited, so I'm open to any suggestions, improvements, feedback and collaboration. I hope that Beat will make work easier and more enjoyable for everyone!

## Latest release: Beat 1.0.6

* Autocomplete characters and scene headings
* Automatic scene numbering in edit view –- this has some quirks, but works. Recognizes Fountain scene numbering.
* Set colors for scene headings, synopses and sections by typing `[[COLOR RED]]` (or any other common color) after the heading. This is an experimental feature for now.
* Small visual bug fixes

**Note:** This repository follows my development and does NOT match the released versions. Dread lightly, dear friend!

## Future

### State of development

Beat is now pretty stable and not too many new features have been added. Next release will have the biggest new thing: outline card view, which (for now) won't have the possibility to rearrange the scenes with drag & drop.

The biggest problem that still persist is zooming in/out. Out of legacy reasons, it is done by setting the width of the document and scaling the font accordingly. That's fine, when you have a short screenplay. With a 100-page document (like the one I'm working on right now) changing the zoom can take up to 30 seconds using this method.

There have been experiments with magnifying and scaling the NSScrollView, but all efforts have failed, for now at least. Help is needed with this.

### How can you help?

Well, I'm not sure, but please do. As stated above, the person behind this project is not a real programmer but a director, screenwriter and musician. Writing Objective-C has been a bit overwhelming, and because of that, Document.m has become a 2500-line monster that handles too many things.

Bug reports, some donations and feedback help, but I'd be happy if someone could help with zooming and rearranging the code.


Lauri-Matti Parppei  
KAPITAN!  
https://kapitan.fi/