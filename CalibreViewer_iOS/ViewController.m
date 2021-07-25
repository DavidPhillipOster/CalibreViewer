//
//  ViewController.m
//  Calibre_Viewer
//
//  Created by David Phillip Oster on 9/29/20.
// Apache 2 license

#import "ViewController.h"

#import "Engine.h"

@interface ViewController () <EngineDelegate, UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating>
@property(nonatomic) Engine *engine;
@property(nonatomic) UISearchController *searchController;
@property(nonatomic) UIProgressView *progressView;
@property(nonatomic) ItemKind itemKind;
@property(nonatomic) NSArray<NSString *> *sectionIndexTitles;
@property(nonatomic) NSArray<NSNumber *> *sectionIndexValues;
@end

@implementation ViewController
@synthesize maxValue = _maxValue;
@synthesize doubleValue = _doubleValue;
@synthesize indeterminate = _indeterminate;
@synthesize progressHidden = _progressHidden;

- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = @"Calibre Viewer";
  self.sectionIndexTitles = @[];
  self.sectionIndexValues = @[];
  UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
  self.searchController = searchController;
  searchController.delegate = self;
  searchController.searchResultsUpdater = self;
  searchController.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
  searchController.dimsBackgroundDuringPresentation = NO;
  searchController.searchBar.delegate = self; // Monitor when the search button is tapped.
  searchController.searchBar.scopeButtonTitles = @[@"Title", @"Authors", @"Tags"];
  self.navigationItem.searchController = searchController;
  self.navigationItem.hidesSearchBarWhenScrolling = NO;
  self.engine = [[Engine alloc] initWithDelegate:self];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  if (self.progressView == nil) {
    UIView *progressSuper = self.navigationController.navigationBar;
    self.progressView = [[UIProgressView alloc] initWithFrame:CGRectZero];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    [progressSuper addSubview:self.progressView];
    [NSLayoutConstraint activateConstraints:@[
      [self.progressView.leftAnchor constraintEqualToAnchor:progressSuper.leftAnchor],
      [self.progressView.rightAnchor constraintEqualToAnchor:progressSuper.rightAnchor],
      [self.progressView.bottomAnchor constraintEqualToAnchor:progressSuper.bottomAnchor],
   ]];
  }
}

#pragma mark -

- (void)setItemKind:(ItemKind)itemKind {
  _itemKind = itemKind;
  [self.engine setItemKind:itemKind];
}

- (void)setDoubleValue:(double)doubleValue {
  _doubleValue = doubleValue;
  if (self.maxValue) {
    self.progressView.progress = doubleValue / self.maxValue;
  }
}

- (void)setProgressHidden:(BOOL)progressHidden {
  _progressHidden = progressHidden;
  self.progressView.hidden = progressHidden;
}

- (void)setEnabled:(BOOL)enabled forSegment:(NSInteger)segment {
}

// iOS can't update the metadata.db file.
- (void)updateMetadataIfNeeded {
}

- (NSURL *)folderURL {
  NSFileManager *fm = [NSFileManager defaultManager];
  return [[fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
}

- (FMDatabase *)constructDBSecondChance {
  return nil;
}

- (void)reloadData {
  [self rebuildIndexStrip];
  [self.tableView reloadData];
}


#pragma mark -

- (void)rebuildIndexStrip {
  if (_itemKind) {
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    NSMutableArray<NSNumber *> *sections = [NSMutableArray array];
    NSString *last = @"";
    NSUInteger count = [self numberOfSectionsInTableView:self.tableView];
    for (NSUInteger i = 0; i < count; ++i) {
      NSString *current = [self tableView:self.tableView titleForHeaderInSection:i];
      if (_itemKind == ItemKindTag) {
        if ([current hasPrefix:@".anth "]) {
          current = [current substringFromIndex:6];
        }
      }
      NSString *prefix = [[current substringToIndex:1] uppercaseString];
      if ([prefix isEqual:@"Ö"]) {
        prefix = @"O";
      }
      if ( ! [prefix isEqual:last] ) {
        last = prefix;
        [titles addObject:prefix];
        [sections addObject:@(i)];
      }
    }
    if (3 <= [titles count]) {
      self.sectionIndexTitles = titles;
      self.sectionIndexValues = sections;
      return; // <-- Note: good return
    }
  }
  self.sectionIndexTitles = @[];
  self.sectionIndexValues = @[];
}

- (UITableViewCell *)configureCell:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {
  if (_itemKind) {
    Item *group = self.engine.filteredModel[indexPath.section];
    NSString *name = [group.children[indexPath.item] name];
    if (_itemKind == ItemKindAuthor) {
      NSRange pipeRange = [name rangeOfString:@"|" options:NSBackwardsSearch];
      if (pipeRange.location != NSNotFound) {
        name = [name substringToIndex:pipeRange.location];
      }
    }
    cell.textLabel.text = name;
  } else {
    Item *item = self.engine.filteredModel[indexPath.item];
    cell.textLabel.text = item.name;
  }
  return cell;
}


#pragma mark -

- (nullable NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView {
  return self.sectionIndexTitles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
  if (index < [self.sectionIndexValues count]) {
    return [self.sectionIndexValues[index] integerValue];
  }
  return 0;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  if (_itemKind) {
    Item *item = self.engine.filteredModel[section];
    return item.name;
  } else {
    return nil;
  }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  if (_itemKind) {
    return self.engine.filteredModel.count;
  } else {
    return 1;
  }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (_itemKind) {
    Item *item = self.engine.filteredModel[section];
    return item.children.count;
  } else {
    return self.engine.filteredModel.count;
  }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"A"];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"A"];
    cell.textLabel.numberOfLines = 0;
  }
  return [self configureCell:cell indexPath:indexPath];
}

// dismiss the soft keyboard when the user taps the table.
- (void)tableView:(UITableView *)tableView  didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [self.searchController.searchBar resignFirstResponder];
}

#pragma mark -

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
  [searchBar resignFirstResponder];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
  self.itemKind = (ItemKind)selectedScope;
}

#pragma mark -

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
  [self.engine setSearchString:searchController.searchBar.text];
}

@end
