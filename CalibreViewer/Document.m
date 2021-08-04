//  Created by David Phillip Oster on 9/29/20.
// Apache 2 license
#import "Document.h"

#import "DocumentResponder.h"
#import "Engine.h"
#import "fmdb.h"

#import <sqlite3.h>

@interface Document ()<EngineDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource, NSSearchFieldDelegate>
@property IBOutlet NSSearchField *searchField;
@property IBOutlet NSProgressIndicator *progressIndicator;
@property IBOutlet NSOutlineView *outlineView;
@property IBOutlet NSSegmentedControl *modeControl;
@property IBOutlet NSTextView *duplicatesText;
@property NSButton *updateButton;
@property DocumentResponder *documentResponder;
@end

// true if the directory contains a file with one of a number of suffixes.
static BOOL HasEbookFile(NSString *path) {
  NSArray<NSString *> *suffixes = @[
    @"pdf",
    @"epub",
    @"cbz",
    @"rtf",
    @"rtfd",
    @"txt",
  ];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray *contents = [fm contentsOfDirectoryAtPath:path error:NULL];
  for (NSString *fileName in contents) {
    NSString *ext = [[fileName pathExtension] lowercaseString];
    if ([suffixes containsObject:ext]) {
      return YES;
    }
  }
  return NO;
}

@implementation Document


- (instancetype)init {
  self = [super init];
  if (self) {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"root" : @"/Volumes/YOUR_VOLUME/Calibre",
        @"server": @"YOUR_SERVER",
        @"volume": @"YOUR_VOLUME",
    }];
    self.documentResponder = [[DocumentResponder alloc] init];
    self.documentResponder.document = self;
    self.engine = [[Engine alloc] initWithDelegate:self];
  }
  return self;
}

+ (BOOL)autosavesInPlace {
  return YES;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
  [super windowControllerDidLoadNib:windowController];
  self.outlineView.doubleAction = @selector(doDoubleClick:);
  self.documentResponder.outlineView = self.outlineView;
  windowController.nextResponder = self.documentResponder;
  // Fix: rows clipped before first resize.
  CGFloat tableWidth = self.outlineView.frame.size.width;
  if (32 < tableWidth) {
    self.outlineView.tableColumns.firstObject.width = tableWidth;
  }
  [self.outlineView reloadData];
}

- (NSString *)windowNibName {
  return @"Document";
}

- (NSString *)defaultDraftName {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  return [ud stringForKey:@"volume"];
}

// Retruning an empty data here cures a crash if you click on the v in tht title bar and rename the document.
- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
  // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
  // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
 // [NSException raise:@"UnimplementedMethod" format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
  return [NSData data];
}


- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
  // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
  // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
  // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
  [NSException raise:@"UnimplementedMethod" format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
  return YES;
}

// Check that the downloaded file is valid by opening it and seeing if there are at least 1000 records in it.
- (BOOL)isValidDB:(NSURL *)candidate {
  BOOL isOK = NO;
  FMDatabase *db = [FMDatabase databaseWithURL:candidate];
  if (db && [db openWithFlags:SQLITE_OPEN_READONLY]) {
    NSUInteger count = [db intForQuery:@"select count(id) from books"];
    isOK = 1000 <= count;
    [db close];
  }
  return isOK;
}

- (void)doUpdate {
  [self hideUpdateButton];
  NSURL *dbURL = self.engine.db.databaseURL;
  NSURL *tmpURL = [[dbURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"tmp"];
  NSURL *oldURL = [[dbURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"old"];
  [self.engine close:^{
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtURL:oldURL error:NULL];
    if ([fm moveItemAtURL:dbURL toURL:oldURL error:NULL]) {
      if ([fm moveItemAtURL:tmpURL toURL:dbURL error:NULL]) {
        [self.engine restart];
      } else {
        if ([fm moveItemAtURL:oldURL toURL:dbURL error:NULL]) {
          [self.engine.db openWithFlags:SQLITE_OPEN_READONLY];
        }
      }
    }
  }];
}

- (void)hideUpdateButton {
  if (self.updateButton && ! [self.updateButton isHidden]) {
    CGRect searchFrame = self.searchField.frame;
    CGRect updateFrame = self.updateButton.frame;
    searchFrame.size.width += (updateFrame.size.width + 10);
    self.searchField.frame = searchFrame;
    [self.updateButton setHidden:YES];
  }
}

// creates the button if if didn't already exist.
- (void)showUpdateButton {
  if (self.updateButton == nil) {
    NSString *updateTitle = NSLocalizedString(@"Update", 0);
    self.updateButton = [NSButton buttonWithTitle:updateTitle target:self action:@selector(doUpdate)];
    [self.updateButton sizeToFit];
    [self.updateButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
    [self.updateButton setAllowsExpansionToolTips:YES];
    NSString *updateTip = NSLocalizedString(@"UpdateTip", 0);
    [self.updateButton setToolTip:updateTip];
    NSView *superview = self.searchField.superview;
    [superview addSubview:self.updateButton];
    [self.updateButton setHidden:YES];
  }
  if ([self.updateButton isHidden]) {
    CGRect searchFrame = self.searchField.frame;
    CGRect updateFrame = self.updateButton.frame;
    searchFrame.size.width -= updateFrame.size.width + 10;
    updateFrame.origin.x = CGRectGetMaxX(searchFrame) + 10;
    updateFrame.origin.y = searchFrame.origin.y + (searchFrame.size.height - updateFrame.size.height)/2;
    self.searchField.frame = searchFrame;
    self.updateButton.frame = updateFrame;
    [self.updateButton setHidden:NO];
  }
}

// on the file system queue. 
- (BOOL)isMetadataUpdateNeeded {
  NSURL *dbURL = self.engine.db.databaseURL;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path = [dbURL path];
  if (path) {
    NSDictionary *dbAttr = [fm attributesOfItemAtPath:path error:NULL];
    NSDate *dbDate = dbAttr[NSFileModificationDate];
    if (dbDate) {
      NSString *root = [[NSUserDefaults standardUserDefaults] stringForKey:@"root"];
      if (root) {
        root = [root stringByAppendingPathComponent:@"metadata.db"];
        NSDictionary *rootAttr = [fm attributesOfItemAtPath:root error:NULL];
        NSDate *rootDate = rootAttr[NSFileModificationDate];
        if (rootDate) {
          NSTimeInterval since = [rootDate timeIntervalSinceDate:dbDate];
          // i.e, the master is more than an hour older than the working DB
          return 60*60 < since;
        }
      }
    }
  }
  return NO;
}

// on the file system queue.
// Copy the metadata file over the network to the temp directory. On a successful copy, prepare to swap databases.
- (void)updateMetadata {
  NSURL *dbURL = self.engine.db.databaseURL;
  NSString *root = [[NSUserDefaults standardUserDefaults] stringForKey:@"root"];
  if (root) {
    root = [root stringByAppendingPathComponent:@"metadata.db"];
    NSURL *tmpURL = [[dbURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"tmp"];
    NSURL *rootURL = [NSURL fileURLWithPath:root];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtURL:tmpURL error:NULL];
    if ([fm copyItemAtURL:rootURL toURL:tmpURL error:NULL] && [self isValidDB:tmpURL]) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{ [self showUpdateButton]; }];
    }
  }
}

#pragma mark -

// on the file system queue. Called only at app start and we have a database.
- (void)updateMetadataIfNeeded {
  if ([self isMetadataUpdateNeeded]) {
    [self updateMetadata];
  }
}


- (double)maxValue { return self.progressIndicator.maxValue; }
- (void)setMaxValue:(double)maxValue {
  self.progressIndicator.maxValue = maxValue;
}
- (double)doubleValue { return self.progressIndicator.doubleValue; }
- (void)setDoubleValue:(double)doubleValue {
  self.progressIndicator.doubleValue = doubleValue;
}

- (BOOL)indeterminate { return self.progressIndicator.indeterminate; }
- (void)setIndeterminate:(BOOL)indeterminate {
  self.progressIndicator.indeterminate = indeterminate;
}


- (BOOL)progressHidden { return self.progressIndicator.hidden; }
- (void)setProgressHidden:(BOOL)hidden {
  self.progressIndicator.hidden = hidden;
}

- (void)reloadData {
  [self.outlineView reloadData];
}

- (void)setEnabled:(BOOL)enabled forSegment:(NSInteger)segment {
  [self.modeControl setEnabled:enabled forSegment:segment];
}

- (NSURL *)folderURL {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSURL *folderURL = [[fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
  NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
  folderURL = [folderURL URLByAppendingPathComponent:bundleIdentifier];
  [fm createDirectoryAtURL:folderURL withIntermediateDirectories:YES attributes:nil error:NULL];
  return folderURL;
}

- (FMDatabase *)constructDBSecondChance {
  NSURL *folderURL = [self folderURL];
  NSURL *fileURL = [folderURL URLByAppendingPathComponent:@"metadata.db"];
  FMDatabase *db = nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSURL *starter = [[NSBundle mainBundle]  URLForResource:@"metadata" withExtension:@"db"];
  NSError *error;
  if ( ! (starter != nil && [fm copyItemAtURL:starter toURL:fileURL error:&error] && [db openWithFlags:SQLITE_OPEN_READONLY])) {
    starter = [NSURL fileURLWithPath:@"/Users/david/MyWork/WorkOSX/EleanorsTools/CalibreTools/CalibreTool/metadata.db"];
    if ( ! (starter != nil && [fm copyItemAtURL:starter toURL:fileURL error:&error] && [db openWithFlags:SQLITE_OPEN_READONLY])) {
      NSLog(@"Could not open db.");
      return nil;
    }
  }
  return db;
}

- (IBAction)hideDuplicatesSheet:(id)sender {
  NSWindow *window = [self windowForSheet];
  [window endSheet:self.duplicates];
  [self.duplicates orderOut:nil];
  self.duplicates = nil;
}

- (void)showDuplicateTitle:(NSString *)title contents:(NSString *)contents {
  NSWindow *window = [self windowForSheet];
  NSNib *nib = [[NSNib alloc] initWithNibNamed:@"Duplicates" bundle:nil];
  [nib instantiateWithOwner:self topLevelObjects:NULL];
  self.duplicates.title = title;
  self.duplicatesText.string = contents;
  // Remember to uncheck - visible at launch.
  [window beginSheet:self.duplicates completionHandler:nil];
}

- (void)showDuplicateAnthologies:(id)sender {
  NSString *contents = [self.engine.duplicateAnthologyNames componentsJoinedByString:@"\n"];
  [self showDuplicateTitle:NSLocalizedString(@"Duplicate Anthologies", 0) contents:contents];
}

- (void)showDuplicateAuthors:(id)sender {
  NSString *contents = [self.engine.duplicateAuthors componentsJoinedByString:@"\n"];
  [self showDuplicateTitle:NSLocalizedString(@"Duplicate Authors", 0) contents:contents];
}

- (void)showDuplicateFirstLines:(id)sender {
  NSString *contents = [self.engine.duplicateFirstLines componentsJoinedByString:@"\n"];
  [self showDuplicateTitle:NSLocalizedString(@"Duplicate First Lines", 0) contents:contents];
}

- (void)showCache:(id)sender {
  NSURL *dbDirURL = [self.engine.db.databaseURL URLByDeletingLastPathComponent];
  NSWorkspace *workSpace = [NSWorkspace sharedWorkspace];
  [workSpace openURL:dbDirURL];
}

#pragma mark -

- (void)controlTextDidChange:(NSNotification *)note {
  if (note.object != self.searchField) {
    return;
  }
  self.engine.searchString = self.searchField.stringValue;
}

#pragma mark -

- (NSIndexSet *)setOfIndexesContainingTitle:(NSString *)title {
  NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
  for (NSUInteger i = 0; i < self.engine.titleModel.count; ++i) {
    Item *book = self.engine.titleModel[i];
    NSRange r = [book.name rangeOfString:title options:NSCaseInsensitiveSearch];
    if (r.location != NSNotFound) {
      [result addIndex:i];
    }
  }
  return result;
}

- (NSIndexSet *)setOfIndexesMatchingWordsOfTitle:(NSString *)title {
  NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
  NSArray *parts = [title componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  for (NSUInteger i = 0; i < self.engine.titleModel.count; ++i) {
    Item *book = self.engine.titleModel[i];
    if (TitleContainsAllParts(book.name, parts)) {
      [result addIndex:i];
    }
  }
  return result;
}

// Open the metadato file in the directory, extract the anthology data, and find the owning
// anthology and open that folder. With infinite loop protection.
- (Item *)owningBookFromPath:(NSString *)path {
  path = [path stringByAppendingPathComponent:@"metadata.opf"];
  NSURL *url = [NSURL fileURLWithPath:path];
  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:url options:NSXMLNodeOptionsNone error:NULL];
  if (doc) {
    NSXMLElement *metaData = [[doc.rootElement elementsForName:@"metadata"] firstObject];
    NSXMLElement *subject = [[metaData elementsForName:@"dc:subject"] firstObject];
    NSString *subjectText = [subject stringValue];
    if ([subjectText hasPrefix:@".anth"]) {
      subjectText = [[subjectText substringFromIndex:5] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
      if ([subjectText length]) {
        NSIndexSet *set = [self setOfIndexesContainingTitle:subjectText];
        if (set.count == 0) {
          set = [self setOfIndexesMatchingWordsOfTitle:subjectText];
        }
        if (0 < set.count) {
          return self.engine.titleModel[set.firstIndex];
        }
      }
    }
  }
  return nil;
}


- (void)openPartialPath:(NSString *)partialPath ancestors:(NSArray<Item *> *)ancestors {
  NSString *root = [[NSUserDefaults standardUserDefaults] stringForKey:@"root"];
  NSFileManager *fm = [NSFileManager defaultManager];
  if ( ! [fm fileExistsAtPath:root]) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *server = [ud stringForKey:@"server"];
    NSString *volume = [ud stringForKey:@"volume"];
    NSString *suggestion = [NSString stringWithFormat:@"In Finder, Connect to server %@ and mount %@.", server, volume];
    NSString *desc = [NSString stringWithFormat:@"%@ is not mounted.", volume];
    NSError *err = [NSError errorWithDomain:@"App" code:1 userInfo:@{NSLocalizedDescriptionKey : desc,
      NSLocalizedRecoverySuggestionErrorKey: suggestion}];
    [self presentError:err];
    return;
  }
  NSString *path = [root stringByAppendingPathComponent:partialPath];
  NSWorkspace *workSpace = [NSWorkspace sharedWorkspace];
  NSError *error = nil;
  NSURL *url = [NSURL fileURLWithPath:path];
  NSWorkspaceLaunchOptions options = NSWorkspaceLaunchWithErrorPresentation;
  if ([workSpace openURL:url options:options configuration:@{} error:&error]) {
    if ( ! HasEbookFile(path)) {
      Item *book = [self owningBookFromPath:path];
      [self openBookFolder:book ancestors:ancestors];
    }
  } else {
    [self presentError:error];
    NSLog(@"Did not open: %@", partialPath);
  }
}

- (void)openBookFolder:(Item *)book ancestors:(NSArray<Item *> *)ancestors {
  if (nil == book) {
    return;
  }
  if ([ancestors containsObject:book]) {
    return;
  }
  NSMutableArray *mutableAncestors = [ancestors mutableCopy];
  [mutableAncestors addObject:book];
  ancestors = mutableAncestors;
  NSString *ident = [NSString stringWithFormat:@"%lu", (unsigned long)book.ident];
  FMResultSet *rs = [self.engine.db executeQuery:@"select path from books where id = ?", ident];
  if (self.engine.db.isOpen && rs.next) {
    NSString *partialPath = [rs stringForColumn:@"path"];
    [self openPartialPath:partialPath ancestors:ancestors];
  }
}


- (IBAction)doDoubleClick:(id)sender {
  Item *book = (Item *)[self.outlineView itemAtRow:self.outlineView.clickedRow];
  // I hit a case, but can't reproduce it, where the above returned a string.
  if ([book respondsToSelector:@selector(itemKind)]) {
    switch (book.itemKind) {
    case ItemKindBook:
      [self openBookFolder:book ancestors:@[]];
      break;
    case ItemKindAuthor:
    case ItemKindTag:
      if ([self.outlineView isItemExpanded:book]) {
        [self.outlineView collapseItem:book];
      } else {
        [self.outlineView expandItem:book];
      }
      break;
    }
  }
}

- (IBAction)modeChanged:(id)sender {
  if ([sender isKindOfClass:[NSSegmentedControl class]]) {
    self.engine.itemKind = (ItemKind)[(NSSegmentedControl *)sender indexOfSelectedItem];
  }
}


#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item {
  if (item == nil) {
    return self.engine.filteredModel.count;
  }
  if ([item isKindOfClass:[Item class]]) {
    return [[item children] count];
  }
  return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item {
  if (item == nil) {
    return self.engine.filteredModel[index];
  }
  if ([item isKindOfClass:[Item class]]) {
    return [[item children] objectAtIndex:index];
  }
  return [NSNull null];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
  if ([item isKindOfClass:[Item class]]) {
    return 0 < [[item children] count];
  }
  return NO;
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(id)item {
  NSTableCellView *view = [outlineView makeViewWithIdentifier:@"cell" owner:nil];
  if ([item isKindOfClass:[Item class]]) {
    item = [item name];
  }
  view.textField.stringValue = item;
  return view;
}

@end

