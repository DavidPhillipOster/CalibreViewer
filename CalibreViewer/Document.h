//  Created by David Phillip Oster on 9/29/20.
// Apache 2 license
#import <Cocoa/Cocoa.h>

@class Engine;

@interface Document : NSDocument

@property IBOutlet NSWindow *duplicates;

@property Engine *engine;

- (void)showDuplicateAnthologies:(id)sender;
- (void)showDuplicateFirstLines:(id)sender;
- (void)showDuplicateAuthors:(id)sender;

- (IBAction)hideDuplicatesSheet:(id)sender;

- (void)showCache:(id)sender;

@end

