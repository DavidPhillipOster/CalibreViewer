//  Created by David Phillip Oster on 9/29/20.
// Apache 2 license
#import "Engine.h"

#import "fmdb.h"
#import "Item.h"

#import <sqlite3.h>

// true if the book title+author contains all the elements in parts.
BOOL TitleContainsAllParts(NSString *title, NSArray *parts){
  for (NSString *part in parts){
    if (part.length) {
      NSRange r = [title rangeOfString:part options:NSCaseInsensitiveSearch];
      if (NSNotFound == r.location) {
        return NO;
      }
    }
  }
  return YES;
}

// Should remove this entry if it doesn't contain any of the words in the search string.
static BOOL ShouldRemoveByParts(NSMutableArray<Item *> *filtered, NSInteger i, NSArray *parts) {
  Item *book = filtered[i];
  return ! TitleContainsAllParts(book.name, parts);
}

// Should remove this entry if it matches the previous one.
static BOOL ShouldRemoveByDuplication(NSMutableArray<Item *> *filtered, NSInteger i) {
  if (0 < i) {
    Item *book = filtered[i];
    Item *previousBook = filtered[i - 1];
    return [previousBook.name isEqual:book.name];
  }
  return NO;
}

@interface NSString (Engine)
- (BOOL)hasSuffixOrPrefixOf:(NSString *)s;
@end
@implementation NSString (Engine)
- (BOOL)hasSuffixOrPrefixOf:(NSString *)s {
  return 0 < self.length && 0 < s.length && ([self hasPrefix:s] || [self hasSuffix:s]);
}
@end

@interface NSArray (Engine)
- (BOOL)allAreSuffixOrPrefixOf:(NSArray *)old;
@end
@implementation NSArray (Engine)
- (BOOL)allAreSuffixOrPrefixOf:(NSArray *)old; {
  // only possibly true for pairs of arrays that have contents.
  if ( ! (0 < self.count && self.count == old.count)) {
    return NO;
  }
  NSUInteger count = self.count;
  for (NSUInteger i = 0; i < count; ++i) {
    NSString *selfPart = self[i];
    NSString *oldPart = old[i];
    if ( ! [selfPart hasSuffixOrPrefixOf:oldPart]) {
      return NO;
    }
  }
  return YES;
}
@end


@interface Engine ()
@property(nonatomic) NSMutableDictionary<NSString *, Item *> *authorDict; // for Mac

// non-main-thread Database operations on the dbQueue // for Mac
@property NSOperationQueue *dbQueue;

@property(nonatomic) NSArray<Item *> *authorModel;
@property(nonatomic) NSArray<Item *> *tagModel;
@property(nonatomic, readonly) NSArray<Item *> *model;

// non-main-thread network file system operations
@property NSOperationQueue *fileQueue;

// non-main-thread network search operations
@property NSOperationQueue *searchQueue;

@property NSUInteger titleCount;

@property(nonatomic, nullable, readwrite) NSArray<NSString *> *duplicateAnthologyNames;
@property(nonatomic, nullable, readwrite) NSArray<NSString *> *duplicateFirstLines;
@property(nonatomic, nullable, readwrite) NSArray<NSString *> *duplicateAuthors;

@end

@implementation Engine

- (instancetype)initWithDelegate:(id<EngineDelegate>)delegate {
  self = [super init];
  if (self) {
    _searchString = @"";
    _previousSearchString = @"";
    _titleModel = @[ ];
    _authorDict = [NSMutableDictionary dictionary];
    self.delegate = delegate;
    self.dbQueue = [self constructWorkQueueWithQuality:NSQualityOfServiceUserInteractive];
    self.searchQueue = [self constructWorkQueueWithQuality:NSQualityOfServiceUserInteractive];
    self.fileQueue = [self constructWorkQueueWithQuality:NSQualityOfServiceUtility];
    [self.dbQueue addOperationWithBlock:^{ [self readFirst]; }];
  }
  return self;
}

- (NSOperationQueue *)constructWorkQueueWithQuality:(NSQualityOfService)quality {
  NSOperationQueue *workQueue = [[NSOperationQueue alloc] init];
  workQueue.qualityOfService = quality;
  workQueue.maxConcurrentOperationCount = 1;
  return workQueue;
}

- (FMDatabase *)constructDB {
  NSURL *folderURL = self.delegate.folderURL;
  NSURL *fileURL = [folderURL URLByAppendingPathComponent:@"metadata.db"];
  FMDatabase *db = [FMDatabase databaseWithURL:fileURL];
  if ( ! [db openWithFlags:SQLITE_OPEN_READONLY]) {
    return [self.delegate constructDBSecondChance];
  }
  return db;
}

- (void)restart {
  self.titleModel = @[];
  self.authorDict = [NSMutableDictionary dictionary];
  [self.dbQueue addOperationWithBlock:^{ [self readFirst]; }];
}

// on the db work queue. Called only at app start and on update
- (void)readFirst {
  self.db = [self constructDB];
  if (!self.db.isOpen) {
    return;
  }
  [self.fileQueue addOperationWithBlock:^{ [self.delegate updateMetadataIfNeeded]; }];
  self.titleCount = [self.db intForQuery:@"select count(title) FROM books"];
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    self.delegate.maxValue = self.titleCount;
    self.delegate.indeterminate = NO;
  }];
  FMResultSet *rs = [self.db executeQuery:@"select id,title,author_sort from books order by title limit 100"];
  [self readFromResultSet:rs];
}

// on the db work queue:
- (void)readNextAfter:(NSString *)lastRead {
  if (!self.db.isOpen) {
    return;
  }
  FMResultSet *rs = [self.db executeQuery:@"select id,title,author_sort from books where title > ? order by title limit 15000", lastRead];
  [self readFromResultSet:rs];
}

// on the db work queue:
- (void)readFromResultSet:(FMResultSet *)rs {
  NSMutableArray *titleModel = [self.titleModel mutableCopy];
  BOOL didSome = NO;
  while (self.db.isOpen && rs.next) {
    Item *book = [[Item alloc] init];
    book.ident = [rs intForColumn:@"id"];
    NSString *title = [rs stringForColumn:@"title"];
    NSString *author = [rs stringForColumn:@"author_sort"];
    if (author.length) {
      Item *authorItem = self.authorDict[author];
      if (authorItem == nil) {
        authorItem = [[Item alloc] init];
        authorItem.itemKind = ItemKindAuthor;
        authorItem.name = author;
        authorItem.children = [@[book] mutableCopy];
        self.authorDict[author] = authorItem;
      } else {
        [authorItem.children addObject:book];
      }
      title = [title stringByAppendingFormat:@" | %@",author];
    }
    book.name = title;
    [titleModel addObject:book];
    didSome = YES;
  }
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    self.titleModel = titleModel;
    self.delegate.doubleValue = titleModel.count;
    if (0 < titleModel.count && titleModel.count < self.titleCount && didSome) {
      [self.dbQueue addOperationWithBlock:^{
        NSString *lastRead = [(Item *)titleModel.lastObject name];
        [self readNextAfter:lastRead];
      }];
    } else {
      [self.dbQueue addOperationWithBlock:^{
        [self buildAuthorModel];
      }];
      self.delegate.progressHidden = YES;
    }
  }];
}

// on the db work queue:
- (void)buildAuthorModel {
  NSSortDescriptor *ascendingByName = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES comparator:^(id obj1, id  obj2) {
    return [(NSString *)obj1 caseInsensitiveCompare:(NSString *)obj2];
  }];
  self.authorModel = [self.authorDict.allValues sortedArrayUsingDescriptors:@[ascendingByName]];
#if ANTHDUP
  [self authorsCaseDup];
#endif
  [self.authorDict removeAllObjects];
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self.delegate setEnabled:YES forSegment:1];
  }];
  [self buildTagModel];
}

- (void)buildTagModel {
  FMResultSet *rs = [self.db executeQuery:@"select id,name from tags"];
  NSMutableDictionary<NSNumber *, Item *> *tagMap = [NSMutableDictionary dictionary];
  while (self.db.isOpen && rs.next) {
    Item *tag = [[Item alloc] init];
    tag.ident = [rs intForColumn:@"id"];
    tag.itemKind = ItemKindTag;
    tag.name = [rs stringForColumn:@"name"];
    tag.children = [NSMutableArray array];
    tagMap[@(tag.ident)] = tag;
  }
  NSMutableDictionary<NSNumber *, Item *> *bookMap = [NSMutableDictionary dictionary];
  for (Item *book in self.titleModel) {
    bookMap[@(book.ident)] = book;
  }
  rs = [self.db executeQuery:@"select book,tag from books_tags_link"];
  while (self.db.isOpen && rs.next) {
    NSUInteger bookN = [rs intForColumn:@"book"];
    NSUInteger tagN = [rs intForColumn:@"tag"];
    Item *book = bookMap[@(bookN)];
    if (book) {
      Item *tag = tagMap[@(tagN)];
      [tag.children addObject:book];
    }
  }
  NSSortDescriptor *ascendingByName = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES comparator:^(id obj1, id  obj2) {
    return [(NSString *)obj1 caseInsensitiveCompare:(NSString *)obj2];
  }];
  self.tagModel = [tagMap.allValues sortedArrayUsingDescriptors:@[ascendingByName]];
  for (Item *tag in self.tagModel) {
    [tag.children sortUsingDescriptors:@[ascendingByName]];
  }
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self.delegate reloadData];
    [self.delegate setEnabled:YES forSegment:2];
  }];
#if ANTHDUP
  [self anthDup];
  [self pubDup];
#endif
}

#if ANTHDUP
// Mac only. Compute duplicateStoryNames - Stories in anthologies that have publishers that are
//  multiple words with a subsequence in common of more than 30 characters.
// tables:
// books_publishers_link :    id book publisher
// publishers : id   name
- (void)pubDup {
  FMResultSet *rs = [self.db executeQuery:@"select name,id from publishers"];
  NSMutableDictionary<NSString *, NSMutableIndexSet *> *publisherMap = [NSMutableDictionary dictionary];
  // Collect all the candidate
  while (self.db.isOpen && rs.next) {
    NSString *publisher = [rs stringForColumn:@"name"];
    if (30 <= publisher.length) {
      NSString *prefix = [publisher substringToIndex:30];
      NSUInteger publisherN = [rs intForColumn:@"id"];
      NSMutableIndexSet *pubSet = publisherMap[prefix];
      if (pubSet == nil) {
        pubSet = [NSMutableIndexSet indexSet];
      }
      [pubSet addIndex:publisherN];
      publisherMap[prefix] = pubSet;
    }
  }
  for (NSString *prefix in [publisherMap allKeys]) {
    NSIndexSet *pubSet = publisherMap[prefix];
    NSMutableIndexSet *bookSet = [NSMutableIndexSet indexSet];
    for (NSUInteger pubId = pubSet.firstIndex; pubId != NSNotFound; pubId = [pubSet indexGreaterThanIndex:pubId]) {
      rs = [self.db executeQuery:@"select book from books_publishers_link where publisher = ?", @(pubId)];
      while (self.db.isOpen && rs.next) {
        NSUInteger bookID = [rs intForColumn:@"book"];
        [bookSet addIndex:bookID];
      }
    }
    if (1 < bookSet.count) {
      publisherMap[prefix] = bookSet;
    } else {
      [publisherMap removeObjectForKey:prefix];
    }
  }
  // At this pont, we have a mapping of strings to duplicates.
  NSArray<NSString *> *firstLines = [[publisherMap allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
  self.duplicateFirstLines = firstLines;
  NSLog(@"%@", self.duplicateFirstLines);
}

// Mac only. Compute duplicateAnthologyNames - anthologies that have contents that are entirely
// contained in other anthologies.
- (void)anthDup {
  NSMutableDictionary<NSNumber *, Item *> *itemTags = [NSMutableDictionary dictionary];
  NSMutableSet<Item *> *mayBeTags = [NSMutableSet set];
  for (Item *tag in self.tagModel) {
    if ([tag.name hasPrefix:@".anth "]) {
      for (Item *item in tag.children) {
        if (item.ident) {
          Item *holder = itemTags[@(item.ident)];
          if (nil == holder) {
            holder = [[Item alloc] init];
            holder.ident = item.ident;
            holder.name = item.name;
            holder.children = [NSMutableArray array];
            itemTags[@(item.ident)] = holder;
          }
          [holder.children addObject:tag];
          if (1 < holder.children.count) {
            [mayBeTags addObject:tag];
          }
        }
      }
    }
  }
  for (NSNumber *key in [itemTags.allKeys copy]) {
    Item *holder = itemTags[key];
    if (holder.children.count <= 1) {
      [itemTags removeObjectForKey:key];
    }
  }
  // 1807 items have multiple tags 1144 have multiple anth tags
  // 545 tags have items that are in other tags.
  NSMutableSet<Item *> *dupTags = [NSMutableSet set];
  for (Item *tag in mayBeTags) {
    if ([self isEveryItemIn:tag inOtherTags:mayBeTags]) {
      [dupTags addObject:tag];
    }
  }
  if (dupTags.count) {
    NSMutableArray *dupTagsA = [[dupTags allObjects] mutableCopy];
    NSSortDescriptor *ascendingByName = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES comparator:^(id obj1, id  obj2) {
      return [(NSString *)obj1 caseInsensitiveCompare:(NSString *)obj2];
    }];
    [dupTagsA sortUsingDescriptors:@[ascendingByName]];
    self.duplicateAnthologyNames = [dupTagsA valueForKey:@"name"];
    NSLog(@"duplicate anthologies: %@", self.duplicateAnthologyNames);
  } else {
    self.duplicateAnthologyNames = @[];
    NSLog(@"# NO duplicate anthologies");
  }
}

- (BOOL)isEveryItemIn:(Item *)tag inOtherTags:(NSSet<Item *> *)allTags {
  // Since each tag includes the anthology itself, that one item doesn't need to be in some other tag.
  NSInteger count = 0;
  for (Item *item in tag.children) {
    if ([self isItem:item inOtherTags:allTags excluding:tag]) {
      count++;
    }
  }
  return count + 1 == tag.children.count;
}

// true if the item appears in some tag in allTags that is not the same as thisTag.
- (BOOL)isItem:(Item *)item inOtherTags:(NSSet<Item *> *)allTags excluding:(Item *)thisTag {
  for (Item *aTag in allTags) {
    if ( ! [aTag isEqual:thisTag]) {
      if ([aTag.children containsObject:item]) {
        return YES;
      }
    }
  }
  return NO;
}

// For all authors, a dictionary where the key is the lower case author name, and the value
// is the set of authors that match. For all entries that have a length greater than 1, add them to
// the output array. and sort it, case insensitive.
- (void)authorsCaseDup {
  NSMutableDictionary<NSString *, NSSet<NSString *> *> *authorAuthor = [NSMutableDictionary dictionary];
  NSLog(@"self.authorDict: %@", @(self.authorDict.count));
  for (NSString *fullAuthor in [self.authorDict allKeys]) {
    NSString *lowerAuthor = [fullAuthor lowercaseString];
    NSSet<NSString *> *value = authorAuthor[lowerAuthor];
    if (value == nil) {
      value = [NSSet set];
    }
    value = [value setByAddingObject:fullAuthor];
    authorAuthor[lowerAuthor] = value;
  }
  NSMutableArray<NSString *> *dupAuthors = [NSMutableArray array];
  for (NSSet<NSString *> *authors in [authorAuthor allValues]) {
    if (1 < authors.count) {
      [dupAuthors addObjectsFromArray:[authors allObjects]];
    }
  }
  [dupAuthors sortUsingSelector:@selector(caseInsensitiveCompare:)];
  self.duplicateAuthors = dupAuthors;
}

#endif


- (void)close:(void (^)(void))continuation;{
  [self.dbQueue addOperationWithBlock:^{
    [self.db close];
    if (continuation) {
      [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        continuation();
      }];
    }
  }];
}

- (void)setItemKind:(ItemKind)itemKind {
  if (_itemKind != itemKind) {
    _itemKind = itemKind;
    [self updateFilteredModelFull];
  }
}

- (NSArray<Item *> *)model {
  switch(self.itemKind) {
    case 1:
      if (self.authorModel) {
        return self.authorModel;
      }
      break;
    case 2:
      if (self.tagModel) {
        return self.tagModel;
      }
      break;
    case 0:
    default:
      break;
  }
  return self.titleModel;
}


- (void)setTitleModel:(NSArray *)titleModel {
  if (_titleModel != titleModel) {
    _titleModel = titleModel;
    [self updateFilteredModelFull];
  }
}

- (void)setSearchString:(NSString *)searchString {
  if ( ! (_searchString == searchString || [_searchString isEqual:searchString])) {
    _previousSearchString = _searchString;
    _searchString = [searchString copy];
    [self updateFilteredModelIncrementallIfPossible];
  }
}

- (void)updateFilteredModelIncrementallIfPossible {
  NSArray *parts = [self.searchString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSArray *oldParts = [self.previousSearchString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([parts allAreSuffixOrPrefixOf:oldParts]) {
    [self updateFilteredModelFromModel:self.filteredModel];
  } else {
    [self updateFilteredModelFromModel:self.model];
  }
}

- (void)updateFilteredModelFull {
  [self updateFilteredModelFromModel:self.model];
}

/**
 * When the search string or the full model change, create the filtered model by ANDing the words of the
 * search string as a filter on the full model.
 */
- (void)updateFilteredModelFromModel:(NSArray<Item *> *)model {
  NSString *searchString = self.searchString; //self.searchField.stringValue;
  __weak typeof(self) weakSelf = self;
  [self.searchQueue addOperationWithBlock:^{
    typeof(self) strongSelf = weakSelf;
    if (searchString.length) {
      NSArray *parts = [searchString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      NSMutableArray<Item *> *filtered = [model mutableCopy];
      for (NSInteger i = (NSInteger)filtered.count - 1; 0 <= i; --i) {
        if (ShouldRemoveByParts(filtered, i, parts) || ShouldRemoveByDuplication(filtered, i)) {
          [filtered removeObjectAtIndex:i];
        }
      }
      if (![strongSelf.filteredModel isEqual:filtered]) {
        __weak typeof(self) weakSelf = strongSelf;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
          typeof(self) strongSelf = weakSelf;
          strongSelf.filteredModel = filtered;
          [strongSelf.delegate reloadData];
        }];
      }
    } else if (![self.filteredModel isEqual:self.model]) {
       __weak typeof(self) weakSelf = strongSelf;
      [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        typeof(self) strongSelf = weakSelf;
        strongSelf.filteredModel = [strongSelf.model copy];
        [strongSelf.delegate reloadData];
      }];
    }
  }];
}

@end

