// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSJwtClaims.h"
#import "MSAppCenterInternal.h"
#import "MSLogger.h"
#import <Foundation/Foundation.h>

static NSString *const JWT_PARTS_SEPARATOR = @".";
static NSString *const SUBJECT = @"sub";
static NSString *const EXPIRATION = @"exp";

@implementation MSJwtClaims

- (instancetype)initWithSubject:(NSString *)subject expirationDate:(NSDate *)expirationDate {
  self = [super init];
  if (self) {
    _subject = subject;
    _expirationDate = expirationDate;
  }
  return self;
}

+ (MSJwtClaims *)parse:(NSString *)jwt {
  NSArray *parts = [jwt componentsSeparatedByString:JWT_PARTS_SEPARATOR];
  if ([parts count] < 2) {
    MSLogError([MSAppCenter logTag], @"Failed to parse JWT, not enough parts.");
    return nil;
  }
  NSString *base64ClaimsPart = parts[1];
  @try {
    NSError *error;
    NSData *claimsPartData = [[NSData alloc] initWithBase64EncodedString:base64ClaimsPart options:0];
    NSDictionary *claims = [NSJSONSerialization JSONObjectWithData:claimsPartData options:0 error:&error];
    if ([claims objectForKey:EXPIRATION] == nil || [claims objectForKey:SUBJECT] == nil) {
      MSLogError([MSAppCenter logTag], @"Deserialized claims is missing `sub` or `exp`");
      return nil;
    }
    int expirationTimeIntervalSince1970 = [[claims objectForKey:EXPIRATION] intValue];
    return [[MSJwtClaims alloc] initWithSubject:[claims objectForKey:SUBJECT] expirationDate:[[NSDate alloc] initWithTimeIntervalSince1970:expirationTimeIntervalSince1970]];
  } @catch (NSException *e) {
    MSLogError([MSAppCenter logTag], @"Failed to parse JWT: %@", e);
    return nil;
  }
}

- (NSString *)getSubject {
  return self.subject;
}

- (NSDate *)getExpirationDate {
  return self.expirationDate;
}

@end
