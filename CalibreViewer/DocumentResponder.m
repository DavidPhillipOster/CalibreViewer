//  Created by David Phillip Oster on 9/29/20.
// Apache 2 license
#import "DocumentResponder.h"

#import "Item.h"
#import "Document.h"
#import "Engine.h"

@implementation DocumentResponder

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (void)copyToPasteboard:(NSPasteboard *)pboard {
  NSIndexSet *selected = self.outlineView.selectedRowIndexes;
  NSMutableArray *a = [NSMutableArray array];
  Document *document = self.document;
  for (NSUInteger i = selected.firstIndex; i != NSNotFound; i = [selected indexGreaterThanIndex:i]) {
    Item *book = document.engine.filteredModel[i];
    [a addObject:book.name];
  }
  NSString *s = [a componentsJoinedByString:@"\n"];
  [pboard clearContents];
  [pboard setString:s forType:NSPasteboardTypeString];
}

#pragma mark - Menu bar.

- (IBAction)showDuplicateAnthologies:(id)sender {
  if ([self.document.duplicates.title isEqual:NSLocalizedString(@"Duplicate Anthologies", 0)])  {
    [self.document hideDuplicatesSheet:sender];
  } else {
    [self.document showDuplicateAnthologies:sender];
  }
}

- (IBAction)showDuplicateAuthors:(id)sender {
  if ([self.document.duplicates.title isEqual:NSLocalizedString(@"Duplicate Authors", 0)])  {
    [self.document hideDuplicatesSheet:sender];
  } else {
    [self.document showDuplicateAuthors:sender];
  }
}

- (IBAction)showDuplicateFirstLines:(id)sender {
   if ([self.document.duplicates.title isEqual:NSLocalizedString(@"Duplicate First Lines", 0)])  {
    [self.document hideDuplicatesSheet:sender];
  } else {
    [self.document showDuplicateFirstLines:sender];
  }
}

- (IBAction)showCache:(id)sender {
  [self.document showCache:sender];
}



- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  if ([menuItem action] == @selector(showDuplicateAnthologies:)) {
    if ([self.document.duplicates.title isEqual:NSLocalizedString(@"Duplicate Anthologies", 0)]) {
      [menuItem setTitle:NSLocalizedString(@"Hide Duplicate Anthologies", @"")];
      return YES;
    } else if (self.document.engine.duplicateAnthologyNames) {
      if (self.document.engine.duplicateAnthologyNames.count) {
        [menuItem setTitle:NSLocalizedString(@"Show Duplicate Anthologies", @"")];
        return nil == self.document.duplicates;
      } else {
        [menuItem setTitle:NSLocalizedString(@"NO Duplicate Anthologies", @"")];
        return NO;
      }
    } else {
      [menuItem setTitle:NSLocalizedString(@"Computing Duplicate Anthologies", @"")];
      return NO;
    }
  } else if ([menuItem action] == @selector(showDuplicateFirstLines:)) {
    if ([self.document.duplicates.title isEqual:NSLocalizedString(@"Duplicate First Lines", 0)]) {
      [menuItem setTitle:NSLocalizedString(@"Hide Duplicate First Lines", @"")];
      return YES;
    } else if (self.document.engine.duplicateFirstLines) {
      if (self.document.engine.duplicateFirstLines.count) {
        [menuItem setTitle:NSLocalizedString(@"Show Duplicate First Lines", @"")];
        return nil == self.document.duplicates;
      } else {
        [menuItem setTitle:NSLocalizedString(@"NO Duplicate First Lines", @"")];
        return NO;
      }
    }
  } else if ([menuItem action] == @selector(showDuplicateAuthors:)) {
    if ([self.document.duplicates.title isEqual:NSLocalizedString(@"Duplicate Authors", 0)]) {
      [menuItem setTitle:NSLocalizedString(@"Hide Duplicate Authors", @"")];
      return YES;
    } else if (self.document.engine.duplicateAuthors) {
      if (self.document.engine.duplicateAuthors.count) {
        [menuItem setTitle:NSLocalizedString(@"Show Duplicate Authors", @"")];
        return nil == self.document.duplicates;
      } else {
        [menuItem setTitle:NSLocalizedString(@"NO Duplicate Authors", @"")];
        return NO;
      }
    } else {
      [menuItem setTitle:NSLocalizedString(@"Computing Duplicate First Lines", @"")];
      return NO;
    }
  } else if (menuItem.action == @selector(copy:)) {
    return 0 != self.outlineView.selectedRowIndexes.count;
  } else if (menuItem.action == @selector(showCache:)) {
    return YES;
  }
  return NO;
}

- (void)copy:(id)sender {
  NSPasteboard *pboard = [NSPasteboard generalPasteboard];
  [self copyToPasteboard:pboard];
}

#pragma mark - Service Menu

- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType {
  if (([sendType isEqual:NSPasteboardTypeString] || [sendType isEqual:NSStringPboardType]) &&
      0 != self.outlineView.selectedRowIndexes.count) {
    return self;
  }
  return [[self nextResponder] validRequestorForSendType:sendType returnType:returnType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types {
  if (([types containsObject:NSPasteboardTypeString] || [types containsObject:NSStringPboardType]) &&
      0 != self.outlineView.selectedRowIndexes.count) {
    [self copyToPasteboard:pboard];
    return YES;
  }
  return NO;
}

@end

