//  Created by David Phillip Oster on 9/29/20.
// Apache 2 license
#import "Item.h"

static BOOL AreEqualOrBothNil(id a, id b){
  return a == b || [a isEqual:b];
}

@implementation Item

- (instancetype)copyWithZone:(NSZone *)zone {
  Item *other = [[[self class] allocWithZone:zone] init];
  other.ident = self.ident;
  other.itemKind = self.itemKind;
  other.name = [self.name copyWithZone:zone];
  if (self.children) {
    other.children = [[NSMutableArray allocWithZone:zone] init];
    for (Item *child in self.children) {
      [other.children addObject:[child copyWithZone:zone]];
    }
  }
  return other;
}

- (BOOL)isEqual:(id)object {
  if (self == object) {return YES; }
  Item *other = (Item *)object;
  return [self class] == [other class] && self.ident == other.ident && self.itemKind == other.itemKind &&
    AreEqualOrBothNil(self.name, other.name) &&
    AreEqualOrBothNil(self.children, other.children);
}

- (NSComparisonResult)compare:(Item *)other {
  NSComparisonResult result = [self.name compare:other.name];
  if (NSOrderedSame == result) {
    NSUInteger count = MIN(self.children.count, other.children.count);
    for (NSUInteger i = 0; i < count; ++i) {
      result = [self.children[i] compare:other.children[i]];
      if (NSOrderedSame != result) {
        break;
      }
    }
  }
  if (NSOrderedSame == result && self.ident != other.ident) {
    if (self.ident < other.ident) {
      result = NSOrderedAscending;
    } else {
      result = NSOrderedDescending;
    }
  }
  if (NSOrderedSame == result && self.itemKind != other.itemKind) {
    if (self.itemKind < other.itemKind) {
      result = NSOrderedAscending;
    } else {
      result = NSOrderedDescending;
    }
  }
  return result;
}

- (NSUInteger)hash {
  return [self.name hash] ^ self.ident ^ self.itemKind;
}

@end
