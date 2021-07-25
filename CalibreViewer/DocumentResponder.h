//  Created by David Phillip Oster on 9/29/20.
// Apache 2 license
#import <Cocoa/Cocoa.h>

@class Document;

// A separate class since Service menu support must be in a subclass of NSResponder, and NSDocument isn't.
@interface DocumentResponder : NSResponder

// This uses the Document to get to the filteredModel: the data backing the outlineView.
@property(weak) Document *document;

// This uses the outlineView to get the selected row indices
@property(weak) NSOutlineView *outlineView;

@end
