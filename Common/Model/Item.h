//  Created by David Phillip Oster on 9/29/20.
// Apache 2 license
#import <Foundation/Foundation.h>

typedef enum ItemKind {
  ItemKindBook,
  ItemKindAuthor,
  ItemKindTag
} ItemKind;

// Could be a book, an author, or a tag,
@interface Item : NSObject<NSCopying>
@property NSString *name;
@property NSUInteger ident;
@property NSMutableArray<Item *> *children;
@property ItemKind itemKind;  // defaults to book.
@end
