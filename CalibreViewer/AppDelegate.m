//  Created by David Phillip Oster on 9/29/20.
// Apache 2 license
#import "AppDelegate.h"

#import "PreferencesController.h"

@interface AppDelegate ()
@property NSWindowController *prefController;
@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
  return NSTerminateNow;
}

- (IBAction)showPreferences:(id)sender {
  if (self.prefController == nil) {
    self.prefController = [[PreferencesController alloc] initWithWindowNibName:@"Preferences"];
  }
  [self.prefController.window makeKeyAndOrderFront:nil];
}

@end
