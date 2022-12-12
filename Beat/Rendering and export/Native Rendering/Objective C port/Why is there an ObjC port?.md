
#  Why is there an Objective C port here?

*(... or later, why was the Swift code abandoned?)

Swift is not very good with `NSAttributedString`. Like, not good at all. You could say it *sucks*.

Creating attributed strings takes up to 5-10 times longer on Swift than using Objective C. The reason is probably the difference in interoperability logic: Swift is constantly turning `String`s into `NSString` objects when dealing with attributed strings. 

I'm now turning thousands and thousands of lines of code, which was originally converted from Swift, back to Objective C to gain some performance. I know this is silly.

This iteration skips `BeatPageElement` altogether for the sake of simplicity.
