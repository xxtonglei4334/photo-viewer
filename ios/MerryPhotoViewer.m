//
//  MerryPhotoViewController.m
//  MerryPhotoViewer
//
//  Created by bang on 19/07/2017.
//  Copyright © 2017 MerryJS. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MerryPhoto.h"
#import "MerryPhotoViewer.h"

@implementation MerryPhotoViewer {
  BOOL presented;
}

// tell React we want export this module
RCT_EXPORT_MODULE();

- (instancetype)init {
  if (self = [super init]) {
    self.options = @{ @"X" : @NO };
  }
  return self;
}

/**
   we want to auto generate some getters and setters for our bridge.
 */
@synthesize bridge = _bridge;

/**
 Get root view

 @param rootViewController <#rootViewController description#>
 @return presented View
 */
- (UIViewController *)visibleViewController:(UIViewController *)rootViewController {
  if (rootViewController.presentedViewController == nil) {
    return rootViewController;
  }
  if ([rootViewController.presentedViewController isKindOfClass:[UINavigationController class]]) {
    UINavigationController *navigationController =
        (UINavigationController *)rootViewController.presentedViewController;
    UIViewController *lastViewController = [[navigationController viewControllers] lastObject];

    return [self visibleViewController:lastViewController];
  }
  if ([rootViewController.presentedViewController isKindOfClass:[UITabBarController class]]) {
    UITabBarController *tabBarController =
        (UITabBarController *)rootViewController.presentedViewController;
    UIViewController *selectedViewController = tabBarController.selectedViewController;

    return [self visibleViewController:selectedViewController];
  }

  UIViewController *presentedViewController =
      (UIViewController *)rootViewController.presentedViewController;

  return [self visibleViewController:presentedViewController];
}

- (UIViewController *)getRootView {
  UIViewController *rootView =
      [self visibleViewController:[UIApplication sharedApplication].keyWindow.rootViewController];
  return rootView;
}

RCT_EXPORT_METHOD(hide
                  : (RCTResponseSenderBlock)callback {
                    if (!presented) {
                      return;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{

                      [[self getRootView] dismissViewControllerAnimated:YES
                                                             completion:^{
                                                               presented = NO;
                                                               callback(@[ [NSNull null] ]);
                                                             }];

                    });

                  })

RCT_EXPORT_METHOD(config
                  : (NSDictionary *)options
                  : (RCTPromiseResolveBlock)resolve
                  : (RCTPromiseRejectBlock)reject) {
  @try {
    self.options = [NSMutableDictionary dictionaryWithDictionary:self.options];
    for (NSString *key in options.keyEnumerator) {
      [self.options setValue:options[key] forKey:key];
    }
    NSMutableArray *photos = [self.options mutableArrayValueForKey:@"data"];
    //  NSUInteger initialPhoto = [[self.options objectForKey:@"initial"] integerValue];

    NSMutableArray *msPhotos = [NSMutableArray array];

    for (int i = 0; i < photos.count; i++) {
      MerryPhoto *merryPhoto = [MerryPhoto new];

      merryPhoto.image = nil;

      [msPhotos addObject:merryPhoto];
    }

    self.photos = msPhotos;
    self.dataSource = [NYTPhotoViewerArrayDataSource dataSourceWithPhotos:self.photos];
    resolve(nil);
  } @catch (NSException *exception) {
    reject(@"9527", @"Display photo viewer failed, please config it first", nil);
  } @finally {
  }
}

RCT_EXPORT_METHOD(show
                  : (NSInteger *)initialPhoto resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject) {
  if (presented) {
    return;
  }
  if (!self.options) {
    reject(@"9527", @"Display photo viewer failed, please config it first", nil);
    return;
  }
  dispatch_async(dispatch_get_main_queue(), ^{

    @try {
      NYTPhotosViewController *photosViewController = [[NYTPhotosViewController alloc]
          initWithDataSource:self.dataSource
                initialPhoto:[self.photos objectAtIndex:initialPhoto]
                    delegate:self];

      [[self getRootView] presentViewController:photosViewController
                                       animated:YES
                                     completion:^{
                                       presented = YES;
                                     }];
      if (initialPhoto) {
        [self updatePhotoAtIndex:photosViewController Index:initialPhoto];
      }
      [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:YES];
      resolve(@[]);
    } @catch (NSException *exception) {
      reject(@"9527", @"Display photo viewer failed, please check your configurations", exception);
    } @finally {
    }

  });
}

/**
 Update Photo
 @param photosViewController <#photosViewController description#>
 @param photoIndex <#photoIndex description#>
 */
- (void)updatePhotoAtIndex:(NYTPhotosViewController *)photosViewController
                     Index:(NSUInteger)photoIndex {
  NSInteger current = (unsigned long)photoIndex;
  MerryPhoto *currentPhoto = [self.dataSource.photos objectAtIndex:current];
  NSMutableArray *photos = [self.options mutableArrayValueForKey:@"data"];

  NSString *url = photos[current];
  NSURL *imageURL = [NSURL URLWithString:url];
  dispatch_async(dispatch_get_main_queue(), ^{
    SDWebImageDownloader *downloader = [SDWebImageDownloader sharedDownloader];
    [downloader
        downloadImageWithURL:imageURL
                     options:0
                    progress:nil
                   completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
                     //                       when downloads completed update photo
                     if (image && finished) {
                       currentPhoto.image = image;
                       [photosViewController updatePhoto:currentPhoto];
                     }
                   }];

  });
}

#pragma mark - NYTPhotosViewControllerDelegate

- (UIView *)photosViewController:(NYTPhotosViewController *)photosViewController
           referenceViewForPhoto:(id<NYTPhoto>)photo {
  return nil;
}

/**
 Customize title display

 @param photosViewController <#photosViewController description#>
 @param photo <#photo description#>
 @param photoIndex <#photoIndex description#>
 @param totalPhotoCount <#totalPhotoCount description#>
 @return <#return value description#>
 */
- (NSString *)photosViewController:(NYTPhotosViewController *)photosViewController
                     titleForPhoto:(id<NYTPhoto>)photo
                           atIndex:(NSInteger)photoIndex
                   totalPhotoCount:(nullable NSNumber *)totalPhotoCount {
  return [NSString stringWithFormat:@"%lu/%lu", (unsigned long)photoIndex + 1,
                                    (unsigned long)totalPhotoCount.integerValue];
}

/**
 Download current photo if its nil

 @param photosViewController <#photosViewController description#>
 @param photo <#photo description#>
 @param photoIndex <#photoIndex description#>
 */
- (void)photosViewController:(NYTPhotosViewController *)photosViewController
          didNavigateToPhoto:(id<NYTPhoto>)photo
                     atIndex:(NSUInteger)photoIndex {
  if (!photo.image && !photo.imageData) {
    [self updatePhotoAtIndex:photosViewController Index:photoIndex];
  }
  NSLog(@"Did Navigate To Photo: %@ identifier: %lu", photo, (unsigned long)photoIndex);
}

- (void)photosViewController:(NYTPhotosViewController *)photosViewController
    actionCompletedWithActivityType:(NSString *)activityType {
  NSLog(@"Action Completed With Activity Type: %@", activityType);
}

- (void)photosViewControllerDidDismiss:(NYTPhotosViewController *)photosViewController {
  NSLog(@"Did Dismiss Photo Viewer: %@", photosViewController);
  presented = NO;
  [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:NO];
}

+ (NSAttributedString *)attributedTitleFromString:(NSString *)caption {
  return [[NSAttributedString alloc]
      initWithString:caption
          attributes:@{
            NSForegroundColorAttributeName : [UIColor whiteColor],
            NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleBody]
          }];
}

+ (NSAttributedString *)attributedSummaryFromString:(NSString *)summary {
  return [[NSAttributedString alloc]
      initWithString:summary
          attributes:@{
            NSForegroundColorAttributeName : [UIColor lightGrayColor],
            NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleBody]
          }];
}

+ (NSAttributedString *)attributedCreditFromString:(NSString *)credit {
  return [[NSAttributedString alloc]
      initWithString:credit
          attributes:@{
            NSForegroundColorAttributeName : [UIColor grayColor],
            NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1]
          }];
}
@end