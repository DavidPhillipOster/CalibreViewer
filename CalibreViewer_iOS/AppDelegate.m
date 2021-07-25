//  AppDelegate.m
//  Calibre_Viewer
//
//  Created by David Phillip Oster on 9/29/20.
// Apache 2 license

#import "AppDelegate.h"

#import "ViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  CGRect bounds = UIScreen.mainScreen.bounds;
  UIWindow *window = [[UIWindow alloc] initWithFrame:bounds];
  UIViewController *vc = [[ViewController alloc] initWithNibName:nil bundle:nil];
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
  [window setRootViewController:nav];
  self.window = window;
  [window makeKeyAndVisible];
  return YES;
}

@end
