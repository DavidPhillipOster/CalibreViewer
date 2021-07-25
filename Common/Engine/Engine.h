//  Created by David Phillip Oster on 9/29/20.
// Apache 2 license
#import <Foundation/Foundation.h>

#import "Item.h"

NS_ASSUME_NONNULL_BEGIN

@protocol EngineDelegate;

@class FMDatabase;

/// Manages the model.
@interface Engine : NSObject
@property(nonatomic, weak) id<EngineDelegate> delegate;

/// Set this to filter.
@property(nonatomic) NSString *searchString;

@property(nonatomic, readonly) NSString *previousSearchString;


/// set this to change the mode.
@property(nonatomic) ItemKind itemKind;

/// Mac uses this to open anthologies from the title of a story.
@property(nonatomic) NSArray<Item *> *titleModel;

// The actual data source.
@property NSArray<Item *> *filteredModel;

// accessed by the Mac app.
@property FMDatabase *db;

/// If non-null, the engine has run the detection of duplicate anthology names - only used on Mac.
@property(nonatomic, nullable, readonly) NSArray<NSString *> *duplicateAnthologyNames;

/// If non-null, the engine has run the detection of duplicate first lines - only used on Mac.
@property(nonatomic, nullable, readonly) NSArray<NSString *> *duplicateFirstLines;

/// If non-null, the engine has run the detection of duplicate authors - only used on Mac.
@property(nonatomic, nullable, readonly) NSArray<NSString *> *duplicateAuthors;


- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDelegate:(id<EngineDelegate>)delegate NS_DESIGNATED_INITIALIZER;

- (void)restart;

// Called by the Mac app.
- (void)readFirst;

- (void)close:(nullable void (^)(void))continuation;

@end

@protocol EngineDelegate <NSObject>
/// The engine sets these to show its progress.
@property(nonatomic) double maxValue; // for progress indicator
@property(nonatomic) double doubleValue; // for progress indicator
@property(nonatomic) BOOL indeterminate; // for progress indicator. unused on iOS.

// The progress indicator is set to hidden=YES when the engine is done reading the data.
@property(nonatomic) BOOL progressHidden; // for progress indicator

/// the folder containing the database.
@property(nonatomic, readonly) NSURL *folderURL;

/// if the default attempt to open the sqlite database failed, then call this to give the app a second attempt.
- (nullable FMDatabase *)constructDBSecondChance;

/// tell its tableVIew to redraw.
- (void)reloadData;

/// Update the enable state of the segment controller. No-op on iOS because  not feasible .
- (void)setEnabled:(BOOL)enabled forSegment:(NSInteger)segment;

/// Update the metadata.db file if needed. No-op on iOS because  not feasible .
- (void)updateMetadataIfNeeded;
@end

/// true if the book title+author contains all the elements in parts.
BOOL TitleContainsAllParts(NSString *title, NSArray *parts);

NS_ASSUME_NONNULL_END
