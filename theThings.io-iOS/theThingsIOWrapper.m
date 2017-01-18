//
//  theThingsIOWrapper.m
//  theThings.io-iOS
//
// Copyright (c) 2015 Lafosca (http://lafosca.cat/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


// All theThings.io API documentation can be found on this link below
// https://developers.thethings.io/app-development.html

#import "theThingsIOWrapper.h"
#import <AFNetworking/AFNetworking.h>
#import "Account.h"

#define kAPIURL @"http://api.devices.thethings.io/v2/"

@interface theThingsIOWrapper()

@property (nonatomic, strong) AFHTTPRequestOperationManager *manager;

@end

@implementation theThingsIOWrapper

+ (instancetype)sharedInstance {
    static theThingsIOWrapper *_sharedInstance = nil;
    static dispatch_once_t _onceToken;
    dispatch_once(&_onceToken, ^{
        _sharedInstance = [[theThingsIOWrapper alloc] init];
    });
    
    return _sharedInstance;
}


- (instancetype)init {
    //Setup server by configuration
    
    NSString *apiURL = kAPIURL;
    NSLog(@"%@", apiURL);
    self = [self initWithBaseURL:[NSURL URLWithString:apiURL]];
    
    return self;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super init];
    if (self == nil)
        return nil;
    [self setupManagerWithURL:url];
    
    return self;
}


#pragma mark - Authentication 


- (void)setupManagerWithURL:(NSURL *)url {
    self.manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:url];
    self.manager.requestSerializer = [[AFJSONRequestSerializer alloc] init];
    [self.manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [self.manager.requestSerializer setValue:[NSString stringWithFormat:@"%@",[[NSLocale preferredLanguages] objectAtIndex:0]]
                          forHTTPHeaderField:@"Accept-Language"];
    
    [self addAuthenticationTokenToManager];
}

- (void)addAuthenticationTokenToManager {
    NSString *sessionToken = [[Account sharedInstance] sessionToken];
    if (sessionToken){
        [self.manager.requestSerializer setValue:sessionToken
                              forHTTPHeaderField:@"Authorization"];
    }
}

#pragma mark - Sign up

- (void)signUpWithEmail:(NSString *)email
              password:(NSString *)password
        withCompletion:(theThingsHandler)completion
{
    NSDictionary *parameters = @{
                                 @"email": email,
                                 @"password": password,
                                 @"app" : kAppId
                                 };
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    [self.manager POST:@"register" parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        NSString *sessionToken = [responseObject valueForKey:@"token"];
        
        if (sessionToken){
            [[Account sharedInstance] setSessionToken:sessionToken];
            [self addAuthenticationTokenToManager];
            if (completion) completion (responseObject, nil);
        }
        
        if (completion) completion (responseObject, nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [self processServerError:&error withResponseObject:operation.responseObject];
        NSLog(@"Error with theThings request: %@", error);
        if (completion) completion (nil, error);
    }];
}


#pragma mark - Login

- (void)loginWithEmail:(NSString *)email andPassword:(NSString *)password withCompletion:(theThingsHandler)completion {

    NSDictionary *parameters  = @{
                                  @"email": email,
                                  @"password": password,
                                  @"app" : kAppId
                                  };
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self.manager POST:@"login" parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        NSString *sessionToken = [responseObject valueForKey:@"token"];
        
        if (sessionToken){
            [[Account sharedInstance] setSessionToken:sessionToken];
            [self addAuthenticationTokenToManager];
            
            if (completion) completion (responseObject, nil);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        NSLog(@"Error with theThings request: %@", error);
        [self processServerError:&error withResponseObject:operation.responseObject];
        if (completion) completion (nil, error);
    }];
}

#pragma mark - Send data to thing

- (void)sendData:(id)value toThing:(NSString *)thingID withCompletion:(theThingsHandler)completion {
    NSString *url = [NSString stringWithFormat:@"me/resources/temperature/%@",thingID];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    NSDictionary *parameters =  @{@"values": @[@{@"value": value }] };
    
    [self.manager POST:url parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        if (completion) completion (responseObject,nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        NSLog(@"Error with theThings request: %@", error);
        [self processServerError:&error withResponseObject:operation.responseObject];
        if (completion) completion (nil, error);
    }];
}

#pragma mark - Receive data from a thing

- (void)getDataWithCompletion:(theThingsHandler)completion {
    NSString *url = @"me/resources/temperature";
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self.manager GET:url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        if (completion) completion (responseObject,nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        NSLog(@"Error with theThings request: %@", error);
        [self processServerError:&error withResponseObject:operation.responseObject];
        if (completion) completion (nil, error);
    }];
}

#pragma mark - Link with device

- (void)linkDeviceWithDeviceToken:(NSString *)deviceToken withCompletion:(theThingsHandler)completion {
    NSDictionary *parameters = @{
                                 @"thingToken" : deviceToken
                                 };
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self.manager POST:@"me/things" parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        if (completion) completion (responseObject,nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        NSLog(@"Error with theThings request: %@", error);
        [self processServerError:&error withResponseObject:operation.responseObject];
        if (completion) completion (nil, error);
    }];
}

#pragma mark - Private methods

- (BOOL)processServerError:(NSError **)error withResponseObject:(id)responseObject{
    NSString *message = NSLocalizedString(@"Error with connection", nil);
    NSString *serverResponseError = [responseObject valueForKey:@"message"];
    if ([serverResponseError length] > 0){
        message = serverResponseError;
    }
    if (error){
        *error = [NSError errorWithDomain:@"theThingsDomain"
                                     code:1
                                 userInfo:@{@"message": message }];
        return YES;
    }
    return NO;
}


@end
