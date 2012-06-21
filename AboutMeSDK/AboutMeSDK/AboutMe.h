//
//  AboutMe.h
//  About-Me
//
//  Created by Blazing Pair on 5/7/12.
//  Copyright (c) 2012 Blazing Cloud, Inc. All rights reserved.
//

#import "MKNetworkEngine.h"

@class AboutMeUser;
@class CLLocation;

@interface AboutMe : MKNetworkEngine

@property (nonatomic, strong) AboutMeUser *currentUser;
@property (nonatomic, strong) NSString *currentUsername;
@property (nonatomic, strong) NSString *currentPassword;
@property (nonatomic, strong) NSString *authenticationToken;

+ (id) singleton;

- (void) registerUser:(NSString *)username password:(NSString*)password email:(NSString*)email onComplete:(void(^)(NSString *accessToken, AboutMeUser *newUser))completion;
- (void) signInWithUsername:(NSString*)username andPassword:(NSString*)password onComplete:(void(^)(BOOL success))completion;
- (void) editUserDetails:(NSDictionary*)details onComplete:(void(^)(BOOL success))completion;
- (void) uploadUserImage:(UIImage*)image onComplete:(void(^)(BOOL success))completion withProgress:(void(^)(double fraction))progress;
- (void) logout:(void(^)(BOOL success))completion;

- (void) getCurrentUserProfile:(void(^)(void))completion;
- (void) checkInAtLocation:(CLLocation *)location onComplete:(void(^)(BOOL success))completion;

- (void) getFavorites:(void(^)(NSArray *favoriteUsers))completion;
- (void) favorite:(BOOL)favorite user:(AboutMeUser *)user onComplete:(void(^)(BOOL success))completion;

- (void) getUserProfile:(NSString *)username onComplete:(void(^)(AboutMeUser *user))completion;

- (void) getFeaturedUsers:(void(^)(NSArray *users))completion;
- (void) searchByName:(NSString *)searchTerm count:(int)count offset:(int)offset onComplete:(void(^)(NSArray *users))completion;
- (void) searchByUsername:(NSString *)username count:(int)count offset:(int)offset onComplete:(void(^)(NSArray *users))completion;
- (void) searchByTags:(NSArray *)tags count:(int)count offset:(int)offset onComplete:(void(^)(NSArray *users))completion;
- (void) searchWithinRadius:(NSUInteger)miles nearLocation:(CLLocation *)location withCount:(NSUInteger)count onComplete:(void(^)(NSArray *users))completion;
- (void) getRandomUsers:(NSUInteger)count onComplete:(void(^)(NSArray *users))completion;

@end
