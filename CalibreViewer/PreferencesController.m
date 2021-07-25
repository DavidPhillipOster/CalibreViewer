//  Created by David Phillip Oster on 9/29/20.
// Apache 2 license
#import "PreferencesController.h"

@interface PreferencesController () <NSControlTextEditingDelegate, NSWindowDelegate>
@property IBOutlet NSTextField *rootPath;
@property IBOutlet NSTextField *server;
@property IBOutlet NSTextField *volume;
@end

@implementation PreferencesController

- (BOOL)windowShouldClose:(NSWindow *)sender {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString *serverName = self.server.stringValue;
  [ud setObject:serverName forKey:@"server"];
  NSString *rootPathString = self.rootPath.stringValue;
  [ud setObject:rootPathString forKey:@"root"];
  NSString *volumeString = self.volume.stringValue;
  [ud setObject:volumeString forKey:@"volume"];
  return YES;
}

- (void)windowDidLoad {
  [super windowDidLoad];
  self.window.delegate = self;
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString *serverName = [ud stringForKey:@"server"];
  self.server.stringValue = serverName;
  NSString *rootPathString = [ud stringForKey:@"root"];
  self.rootPath.stringValue = rootPathString;
  NSString *volumeString = [ud stringForKey:@"volume"];
  self.volume.stringValue = volumeString;
}

- (void)controlTextDidEndEditing:(NSNotification *)note {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  if (note.object == self.server) {
    NSString *serverName = self.server.stringValue;
    [ud setObject:serverName forKey:@"server"];
  } else if (note.object == self.rootPath) {
    NSString *rootPathString = self.rootPath.stringValue;
    [ud setObject:rootPathString forKey:@"root"];
  } else if (note.object == self.volume) {
    NSString *volumeString = self.volume.stringValue;
    [ud setObject:volumeString forKey:@"volume"];
  }
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName {
  return @"Preferences";
}


@end
