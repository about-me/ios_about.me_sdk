//
//  AboutMe.m
//  About-Me
//
//  Created by Blazing Pair on 5/7/12.
//  Copyright (c) 2012 Blazing Cloud, Inc. All rights reserved.
//

#import "AboutMe.h"
#import "AboutMeUser.h"
#import "JSONKit.h"
#import <CoreLocation/CoreLocation.h>

#define kMAX_IMAGE_UPLOAD_SIZE 5000 * 1024
#define kAPI_KEY @"78fa6bc58ce385ef6253dce92532ba2ba29b5995"

typedef enum {
  AboutMeStatusSuccess = 200,
  AboutMeStatusAuthorizationFailure = 401
} AboutMeStatusCodes;

typedef enum {
    AboutMeErrorNoError,
    AboutMeErrorBadJSON,
    AboutMeErrorBadStatus,
} AboutMeErrorType;

typedef enum {
    AboutMeErrorCodeNoError = 0,
    AboutMeErrorCodeBadClientID = 1,
    AboutMeErrorCodeInvalidAuthToken = 2,
    AboutMeErrorCodeFailedToLogin = 3,
} AboutMeErrorCode;

@interface AboutMe ()
- (void) enqueueOperation:(NSString *)httpMethod atPath:(NSString*)path withParams:(NSDictionary*)params onComplete:(void(^)(NSDictionary *json))complete;
@end

@implementation AboutMe {
    NSString* apiKey;
}

@synthesize currentUser, currentUsername, currentPassword, authenticationToken;

+ (id) singleton {
    static id singleton;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        singleton = [[self alloc] initSingleton];
    });
    return singleton;
}

- (id) initWithHostName:(NSString*) hostName apiPath:(NSString*) apiPath customHeaderFields:(NSDictionary*) headers {
    self = [super initWithHostName:hostName apiPath:apiPath customHeaderFields:headers];
    if (self) {
        [self useCache];
    }
    return self;
}

- (id)initSingleton {
    if (self = [self initWithHostName:@"api.about.me"
                               apiPath:@"api/v3/json"
                    customHeaderFields:nil]) {
    }
    return self;    
}

+ (NSUserDefaults*) config {
    return [NSUserDefaults standardUserDefaults];
}

- (NSArray*) usersFromProfiles:(NSArray *)profiles {
    NSMutableArray* users = [NSMutableArray array];
    for (NSDictionary* profile in profiles) {
        [users addObject:[[AboutMeUser alloc] initWithDictionary:profile]];
    }
    return users;
}

- (id)jsonFromData:(NSData *)jsonData {
    return [[JSONDecoder decoder] objectWithData:jsonData];
}

- (id)jsonFromResponse:(MKNetworkOperation *)response {
    return [self jsonFromData:[response responseData]];
}

- (MKNetworkOperation *) createApiOperation:(NSString *)httpMethod atPath:(NSString*)path withParams:(NSDictionary*)params {
    NSMutableDictionary *modifiedParams = [NSMutableDictionary dictionaryWithDictionary:params];
    BOOL validate = [params objectForKey:@"token"] && [params objectForKey:@"client_id"];
    if (!validate) {
        [modifiedParams removeObjectForKey:@"token"];
        [modifiedParams removeObjectForKey:@"client_id"];
    }
    MKNetworkOperation *op = [self operationWithPath:path 
                                              params:modifiedParams
                                          httpMethod:httpMethod 
                                                 ssl:YES];
    if (!validate) {
        if ([params objectForKey:@"token"]) {
            [op setAuthorizationHeaderValue:self.authenticationToken
                                forAuthType:@"OAuth"];
        } else {
            [op setAuthorizationHeaderValue:apiKey == nil ? kAPI_KEY : apiKey
                                forAuthType:@"Basic"];
        }
    }
    return op;
}

- (void) handleError:(NSError*)error {
    NSString* title = @"Error";
    NSString* message = [error.userInfo valueForKeyPath:@"json.error_message"];
    if (!message) {
        title = @"Network Error";
        message = [error localizedDescription];            
    }
    
    [[[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil] show];
    
    DLogObject(error);
}

- (void)complete:(MKNetworkOperation *)op withBlock:(void(^)(NSDictionary *json))block {
    [op onCompletion:^(MKNetworkOperation *response) {
        id json = [self jsonFromResponse:response];
        if ([json respondsToSelector:@selector(objectForKey:)]) {
            NSNumber *status = [json objectForKey:@"status"];
            if (status 
                && [status intValue] != AboutMeStatusSuccess 
                && [status intValue] != AboutMeStatusAuthorizationFailure) {
                NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                           op, @"operation",
                                           json, @"json", 
                                           nil];
                NSError *error = [NSError errorWithDomain:@"AboutMeAPIError"
                                                            code:AboutMeErrorBadStatus
                                                        userInfo:errorInfo];
                [self handleError:error];
            }
            if (block) {
                block(json);
            }
        } else {
            NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                       op, @"operation",
                                       json, @"json", 
                                       nil];
            NSError *error = [NSError errorWithDomain:@"AboutMeAPIError"
                                                 code:AboutMeErrorBadJSON
                                             userInfo:errorInfo];
            [self handleError:error];
        }
    } onError:^(NSError *error) {
        [self handleError:error];
    }];
    [self enqueueOperation:op];
}

- (BOOL)isFailedToLoginResponse:(NSDictionary *)jsonResponse {
    BOOL failedToLoginBasedOnErrorCode = [[jsonResponse objectForKey:@"error_code"] intValue] == AboutMeErrorCodeFailedToLogin;
    BOOL failedToLoginBasedOnErrorMessage = [@"Failed to authenticate" isEqualToString:[jsonResponse objectForKey:@"error_message"]];
    return failedToLoginBasedOnErrorCode || failedToLoginBasedOnErrorMessage;    
}

- (void)reloginAndEnqueue:(NSString *)httpMethod atPath:(NSString*)path withParams:(NSDictionary*)params onComplete:(void(^)(NSDictionary *json))complete {
    self.authenticationToken = nil;
    [self userLogin:self.currentUsername andPassword:self.currentPassword onComplete:^(BOOL success) {
        if (success) {
            NSMutableDictionary *modifiedParams = [NSMutableDictionary dictionaryWithDictionary:params];
            [modifiedParams setObject:self.authenticationToken forKey:@"token"];
            [self enqueueOperation:httpMethod atPath:path withParams:modifiedParams onComplete:complete];        
        }
    }];
}

- (BOOL)invalidAuthToken:(MKNetworkOperation *)operation response:(NSDictionary *)json {
    NSNumber *status = [json objectForKey:@"status"];
    NSString *authType = [[[operation readonlyRequest] allHTTPHeaderFields] objectForKey:@"Authorization"];
    NSString *stringErrorCode = [json objectForKey:@"error_code"];
    NSInteger errorCode = [stringErrorCode intValue];
    if (stringErrorCode && errorCode == AboutMeErrorCodeInvalidAuthToken) {
        return YES;
    }
    return [status intValue] == AboutMeStatusAuthorizationFailure && [authType hasPrefix:@"OAuth "];
}

- (BOOL)invalidApiKey:(MKNetworkOperation *)operation response:(NSDictionary *)json {
    NSNumber *status = [json objectForKey:@"status"];
    if ([status intValue] == AboutMeStatusAuthorizationFailure) {
        NSString *authType = [[[operation readonlyRequest] allHTTPHeaderFields] objectForKey:@"Authorization"];
        NSString *stringErrorCode = [json objectForKey:@"error_code"];
        NSInteger errorCode = [stringErrorCode intValue];
        if (stringErrorCode && errorCode != AboutMeErrorCodeBadClientID) {
            return NO;
        }
        BOOL apiKeyAuth = [authType hasPrefix:@"Basic "];
        BOOL hasApiKeyParameter = [[[[operation readonlyRequest] URL] absoluteString] rangeOfString:@"client_id="].location != NSNotFound;
        return apiKeyAuth || hasApiKeyParameter;
    }
    return NO;
}

- (void)registerAndEnqueue:(NSString *)httpMethod atPath:(NSString*)path withParams:(NSDictionary*)params onComplete:(void(^)(NSDictionary *json))complete {
    apiKey = nil;
    self.authenticationToken = nil;
    [self enqueueOperation:@"GET" atPath:@"user/register/iossdk" withParams:nil onComplete:^(NSDictionary *json) {
        apiKey = [json objectForKey:@"apikey"];
        NSMutableDictionary *modified = [NSMutableDictionary dictionaryWithDictionary:params];
        if ([modified objectForKey:@"client_id"]) {
            [modified setObject:apiKey forKey:@"client_id"];
        }
        if ([modified objectForKey:@"token"]) {
            [self reloginAndEnqueue:httpMethod atPath:path withParams:modified onComplete:complete];
        } else {
            [self enqueueOperation:httpMethod atPath:path withParams:modified onComplete:complete];
        }
    }];
}

- (void) enqueueOperation:(NSString *)httpMethod atPath:(NSString*)path withParams:(NSDictionary*)params onComplete:(void(^)(NSDictionary *json))complete {
    DLog(@"request: %@", path);
    MKNetworkOperation *op = [self createApiOperation:httpMethod atPath:path withParams:params];
    [self complete:op withBlock:^(NSDictionary *json) {
        DLog(@"completed %@: %@", [op isCachedResponse] ? @"cached" : @"not cached", path);
        if ([op isCachedResponse] && [[json valueForKey:@"status"] intValue] != 200) {            
            DLog(@"discard invalid cached data: %@", json);
            return;
        }
        
        if ([self invalidAuthToken:op response:json]) {
            [self reloginAndEnqueue:httpMethod atPath:path withParams:params onComplete:complete];            
        } else if ([self invalidApiKey:op response:json]) {
            [self registerAndEnqueue:httpMethod atPath:path withParams:params onComplete:complete];            
        } else if (complete) {
            complete(json);
        } else {
            DLog(@"there is no complete block for path: %@, params: %@", path, params);
        }
    }];
}

- (void)make:(NSString *)httpMethod 
      atPath:(NSString*)path 
  withParams:(NSDictionary*)params 
  onComplete:(void(^)(NSDictionary *json))complete {
    if (apiKey) {
        [self enqueueOperation:httpMethod atPath:path withParams:params onComplete:complete];
    } else {        
        [self registerAndEnqueue:httpMethod atPath:path withParams:params onComplete:complete];
    }
}

- (void)post:(NSString*)path withParams:(NSDictionary*)params onComplete:(void(^)(NSDictionary *json))complete {
    [self make:@"POST" atPath:path withParams:params onComplete:complete];
}

- (void)get:(NSString*)path withParams:(NSDictionary*)params onComplete:(void(^)(NSDictionary *json))complete {
    [self make:@"GET" atPath:path withParams:params onComplete:complete];
}

- (NSArray*)parseUsersFromDirectories:(NSDictionary *)jsonObject {
    NSArray *profiles = [jsonObject valueForKeyPath:@"directories.@unionOfArrays.profiles"];
    return [self usersFromProfiles:profiles];
}

- (NSPredicate *)notCurrentUserPredicate {
    return [NSPredicate predicateWithFormat:@"user_name != %@", self.currentUsername];
}

- (NSArray*)parseUsersFromResult:(NSDictionary *)jsonObject {
    NSArray* profiles = [jsonObject objectForKey:@"result"];
    NSArray *filtered = [profiles filteredArrayUsingPredicate:[self notCurrentUserPredicate]];
    return [self usersFromProfiles:filtered];
}

- (void)getFeaturedUsers:(void(^)(NSArray *users))completion {
    [self  get:@"users/view/directory/all" 
    withParams:[NSDictionary dictionaryWithObjectsAndKeys:
                @"false", @"extended",
                self.authenticationToken, @"token",
                nil]
    onComplete:^(NSDictionary *json) {
        completion([self parseUsersFromDirectories:json]);
    }];
}

- (void)setCurrentUser:(AboutMeUser *)user {
    currentUser = user;
    self.currentUsername = [user username];
}

- (void)clearUserPasswordAndToken {
    self.currentUser = nil;
    self.currentPassword = nil;
    self.authenticationToken = nil;
}

- (void)userCreate:(NSString *)username password:(NSString*)password email:(NSString*)email 
          onComplete:(void(^)(NSString *accessToken, AboutMeUser *newUser))completion {
    NSString *path = [NSString stringWithFormat:@"user/create/%@", username];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"true", @"extended",
                            @"true", @"login",
                            @"mobile", @"scope",
                            username, @"username",
                            password, @"password",
                            email, @"email",
                            nil];
    [self clearUserPasswordAndToken];
    [self post:path withParams:params onComplete:^(NSDictionary *json) {
        NSString *accessToken = [json objectForKey:@"access_token"];
        NSDictionary *user_info = [json objectForKey:@"user_info"];
        NSMutableDictionary *userWithUsername = [NSMutableDictionary dictionaryWithDictionary:user_info];
        [userWithUsername setObject:username forKey:@"user_name"];
        AboutMeUser *newUser = [[AboutMeUser alloc] initWithDictionary:userWithUsername];
        self.currentUser = newUser;
        self.authenticationToken = accessToken;
        self.currentPassword = password;
        completion(accessToken, newUser);
    }];
}

- (NSString*) appVersion {
    return [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleVersion"];
}

- (NSString *)agent {
    NSString* version = [self appVersion];
    NSString* agent = [NSString stringWithFormat:@"about.me SDK/%@ (%@ %@)", 
                       version,
                       [UIDevice currentDevice].model, 
                       [UIDevice currentDevice].systemVersion];
    return agent;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@, apiKey=%@, token=%@, currentUsername=%@",
            [super description],
            apiKey,
            self.authenticationToken,
            self.currentUsername
            ];
}

- (BOOL)successStatus:(NSDictionary *)json {
    NSNumber *status = [json objectForKey:@"status"];
    return [status intValue] == AboutMeStatusSuccess;
}

- (void)favorite:(BOOL)favorite user:(AboutMeUser*)user onComplete:(void(^)(BOOL))completion {
    NSParameterAssert(self.currentUsername);
    NSParameterAssert(self.authenticationToken);
    NSString *path = [NSString stringWithFormat:@"user/directory/%@", self.currentUsername];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            [user username], favorite ? @"to_add" : @"to_remove",
                            self.authenticationToken, @"token",
                            nil];
    [self post:path withParams:params onComplete:^(NSDictionary *json) {
        completion([self successStatus:json]);
    }];
}

- (void)userLogin:(NSString*)username andPassword:(NSString*)password onComplete:(void(^)(BOOL))completion {
    NSParameterAssert(username);
    NSParameterAssert(password);
    [self clearUserPasswordAndToken];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"password", @"grant_type",
                            @"true", @"extended",
                            @"true", @"show_profile",
                            @"mobile", @"scope",
                            username, @"username",
                            password, @"password",
                            nil];
    [self post:@"user/login" withParams:params onComplete:^(NSDictionary *json) {
        BOOL success = [self successStatus:json];
        if (success) {
            self.authenticationToken = [json objectForKey:@"access_token"];
            NSDictionary *userInfo = [json objectForKey:@"user_info"];
            self.currentUser = [[AboutMeUser alloc] initWithDictionary:userInfo];
            self.currentPassword = password;
        }
        completion(success);
    }];
}

- (void)getFavorites:(void(^)(NSArray *favoriteUsers))completion {
    NSParameterAssert(self.authenticationToken);
    NSParameterAssert(self.currentUsername);
    [self get:[NSString stringWithFormat:@"user/directory/%@", self.currentUsername] 
   withParams:[NSDictionary dictionaryWithObjectsAndKeys:
               @"false", @"extended",
               @"true", @"on_match",                
               self.authenticationToken, @"token",
               nil]
   onComplete:^(NSDictionary *json) {
       NSArray* users = [self parseUsersFromResult:json];
       [users makeObjectsPerformSelector:@selector(makeFavorite)];
       completion(users);
   }];
}

- (void)synchCurrentUser:(void(^)(void))completion {
    NSParameterAssert(self.currentUsername);
    NSParameterAssert(self.authenticationToken);
    NSString *path = [NSString stringWithFormat:@"user/validate/%@", self.currentUsername];
    [self get:path
   withParams:[NSDictionary dictionaryWithObjectsAndKeys:
               @"true", @"extended",
               @"true", @"on_match",
               self.authenticationToken, @"token",
               apiKey, @"client_id",
               nil]
   onComplete:^(NSDictionary *json) {
       NSDictionary *user_info = [json objectForKey:@"user_info"];
       AboutMeUser *newUser = [[AboutMeUser alloc] initWithDictionary:user_info];
       self.currentUser = newUser;
       completion();
   }];
}

- (void)userLogout:(void(^)(BOOL success))completion {
    if (self.currentUser) {
        NSParameterAssert(self.currentUsername);
        NSString *path = [NSString stringWithFormat:@"user/logout/%@", self.currentUsername];
        [self post:path
        withParams:[NSDictionary dictionaryWithObject:self.authenticationToken forKey:@"token"]
        onComplete:^(NSDictionary *json) {
            [self clearUserPasswordAndToken];
            if (completion) {
                completion([self successStatus:json]);
            }
        }];
    } else {
        self.authenticationToken = nil;
        completion(YES);
    }
}

- (void)userView:(NSString *)username onComplete:(void(^)(AboutMeUser *user))completion {
    NSString *path = [NSString stringWithFormat:@"user/view/%@", username];
    [self get:path
   withParams:[NSDictionary dictionaryWithObjectsAndKeys:
               @"true", @"extended",
               @"true", @"on_match",
               self.currentUsername, @"is_fav_of",
               self.authenticationToken, @"token",
               nil]
   onComplete:^(NSDictionary *json) {
       AboutMeUser *newUser = nil;
       if ([self successStatus:json]) {
           newUser = [[AboutMeUser alloc] initWithDictionary:json];
       }
       completion(newUser);
   }];
}

- (void)getRandomUsers:(NSUInteger)count onComplete:(void(^)(NSArray *users))completion {
    [self get:@"users/view/random"
   withParams:[NSDictionary dictionaryWithObjectsAndKeys:
               [NSString stringWithFormat:@"%d", count], @"profile_number",
               @"true", @"on_match",   
               @"false", @"extended",
               self.authenticationToken, @"token",
               nil]
   onComplete:^(NSDictionary *json) {
       NSArray* users = [self parseUsersFromResult:json];
       completion(users);
   }];   
}

- (void)userUpload:(UIImage*)image onComplete:(void(^)(BOOL success))completion withProgress:(void(^)(double fraction))progress {
    NSParameterAssert(self.authenticationToken);
    MKNetworkOperation *op = [self createApiOperation:@"POST"
                                               atPath:@"user/upload"
                                           withParams:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       self.authenticationToken, @"token",
                                                       nil]];
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0f);
    NSParameterAssert([imageData length] < kMAX_IMAGE_UPLOAD_SIZE);

    [op addData:imageData
         forKey:@"user_background"
       mimeType:@"image/jpg"
       fileName:@"background.jpg"];
    [op onUploadProgressChanged:progress];
    [self complete:op withBlock:^(NSDictionary *json) {
        completion([self successStatus:json]);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UserUpdated" object:nil];
    }];
}

- (void)userEdit:(NSDictionary*)details onComplete:(void(^)(BOOL success))completion {
    NSParameterAssert(self.currentUsername);
    NSParameterAssert(self.authenticationToken);
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:details];
    [params setObject:@"true" forKey:@"extended"];
    [params setObject:@"true" forKey:@"show_profile"];
    [params setObject:self.authenticationToken forKey:@"token"];
    
    [self post:[NSString stringWithFormat:@"user/edit/%@", self.currentUsername]
   withParams:params
   onComplete:^(NSDictionary *json) {
       BOOL success = [self successStatus:json];
       if (success) {
           NSDictionary *user_info = [json objectForKey:@"user"];
           AboutMeUser *newUser = [[AboutMeUser alloc] initWithDictionary:user_info];
           self.currentUser = newUser;
           [[NSNotificationCenter defaultCenter] postNotificationName:@"UserUpdated" object:nil];
       }
       completion(success);
   }];
}

- (void)searchWithinRadius:(NSUInteger)miles
              nearLocation:(CLLocation *)location 
              withCount:(NSUInteger)count 
                onComplete:(void(^)(NSArray *users))completion {
    [self get:@"users/search"
   withParams:[NSDictionary dictionaryWithObjectsAndKeys:
               @"false", @"extended",
               @"true", @"on_match",
               [NSNumber numberWithDouble:location.coordinate.latitude], @"lat",
               [NSNumber numberWithDouble:location.coordinate.longitude], @"long",
               [NSNumber numberWithInt:miles], @"radius",
               [NSNumber numberWithInt:count], @"count",
               self.authenticationToken, @"token",
               nil]
   onComplete:^(NSDictionary *json) {
       NSArray* users = [self parseUsersFromResult:json];
       completion(users);
   }];
}

- (void)userCheckin:(CLLocation *)location onComplete:(void(^)(BOOL success))completion {
    NSParameterAssert(self.currentUsername);
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithDouble:location.coordinate.latitude], @"lat",
                                   [NSNumber numberWithDouble:location.coordinate.longitude], @"long",
                                   self.authenticationToken, @"token",
                                   nil];
    [self post:[NSString stringWithFormat:@"user/checkin/%@", self.currentUsername]
    withParams:params
    onComplete:^(NSDictionary *json) {
        if (completion) {
            completion([self successStatus:json]);
        }
    }];
}

- (void)search:(NSString*)term by:(NSString*)type count:(int)count offset:(int)offset onComplete:(void(^)(NSArray *users))completion {
    [self get:@"users/search"
   withParams:[NSDictionary dictionaryWithObjectsAndKeys:
               [NSNumber numberWithInt:count], @"count",
               [NSNumber numberWithInt:offset], @"offset",
               @"false", @"extended",
               @"true", @"on_match",   
               term, type,
               self.authenticationToken, @"token",               
               nil]
   onComplete:^(NSDictionary *json) {
       NSArray* users = [self parseUsersFromResult:json];
       completion(users);
   }];   
}

- (void)searchByName:(NSString *)searchTerm count:(int)count offset:(int)offset onComplete:(void(^)(NSArray *users))completion {
    [self search:searchTerm by:@"search_key" count:count offset:offset onComplete:completion];
}

- (void)searchByUsername:(NSString*)username count:(int)count offset:(int)offset onComplete:(void(^)(NSArray *users))completion {
    [self search:username by:@"username" count:count offset:offset onComplete:completion];
}

- (void)searchByTags:(NSArray*)tags count:(int)count offset:(int)offset onComplete:(void(^)(NSArray *users))completion {
    [self search:[tags componentsJoinedByString:@","] by:@"tags" count:count offset:offset onComplete:completion];
}

@end
