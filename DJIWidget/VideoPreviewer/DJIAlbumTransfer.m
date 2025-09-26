//
//  DJIAlbumTransfer.h
//
//  Copyright (c) 2015 DJI. All rights reserved.
//


#import <DJIWidgetMacros.h>
#import "DJIAlbumTransfer.h"
#import <Photos/Photos.h>

#ifndef SAFE_BLOCK
#define SAFE_BLOCK(block, ...) if(block){block(__VA_ARGS__);};
#endif


@implementation DJIAlbumTransfer
+(void) writeVideo:(NSString*)file toAlbum:(NSString*)album completionBlock:(void(^)(NSURL *assetURL, NSError *error))block{
    
    NSFileManager* fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:file]) {
        NSError *customError = [[NSError alloc] initWithDomain:@"drone.dji.com" code:DJIAlbumTransferErrorCode_FileNotFound userInfo:nil];
        SAFE_BLOCK(block, nil, customError);
        return;
    }
    
    if(!UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(file)){
        NSError *customError = [[NSError alloc] initWithDomain:@"drone.dji.com" code:DJIAlbumTransferErrorCode_FileCannotPlay userInfo:nil];
        SAFE_BLOCK(block, nil, customError);
        return;
    }
    
    NSURL* fileURL = [NSURL fileURLWithPath:file];
    [self saveVideoToPhotoLibrary:fileURL toAlbum:album completionBlock:block];
}

+(void) writeVidoToAssetLibrary:(NSString*)file completionBlock:(void(^)(NSURL *assetURL, NSError *error))block{
    
    NSFileManager* fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:file]) {
        NSError *customError = [[NSError alloc] initWithDomain:@"drone.dji.com" code:DJIAlbumTransferErrorCode_FileNotFound userInfo:nil];
        SAFE_BLOCK(block, nil, customError);
        return;
    }
    
    if(!UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(file)){
        NSError *customError = [[NSError alloc] initWithDomain:@"drone.dji.com" code:DJIAlbumTransferErrorCode_FileCannotPlay userInfo:nil];
        SAFE_BLOCK(block, nil, customError);
        return;
    }
    
    NSURL* fileURL = [NSURL fileURLWithPath:file];
    [DJIAlbumTransfer saveVideoToPhotoLibrary:fileURL toAlbum:nil completionBlock:block];
}


//The file will be transferred to photo library
+ (void)saveVideoToPhotoLibrary:(NSURL *)url toAlbum:(NSString *)albumName completionBlock:(void(^)(NSURL *assetURL, NSError *error))block {
    
    __block NSString *createdAssetIdentifier = nil;
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        // Create the asset
        PHAssetChangeRequest *assetRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
        PHObjectPlaceholder *placeholder = assetRequest.placeholderForCreatedAsset;
        createdAssetIdentifier = placeholder.localIdentifier;
        
        // If album name is provided, add to specific album
        if (albumName && albumName.length > 0) {
            // Find or create the album
            PHAssetCollection *album = [self findOrCreateAlbum:albumName];
            if (album) {
                PHAssetCollectionChangeRequest *albumRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:album];
                [albumRequest addAssets:@[placeholder]];
            }
        }
        
    } completionHandler:^(BOOL success, NSError *error) {
        if (success) {
            // Create a URL from the local identifier
            if (createdAssetIdentifier) {
                NSURL *assetURL = [NSURL URLWithString:[NSString stringWithFormat:@"ph://%@", createdAssetIdentifier]];
                SAFE_BLOCK(block, assetURL, nil);
            } else {
                NSError *customError = [[NSError alloc] initWithDomain:@"drone.dji.com" code:DJIAlbumTransferErrorCode_NoDiskSpace userInfo:nil];
                SAFE_BLOCK(block, nil, customError);
            }
        } else {
            NSLog(@"saveVideoToPhotoLibrary error: %@", error);
            SAFE_BLOCK(block, nil, error);
        }
    }];
}

// Helper method to find or create album
+ (PHAssetCollection *)findOrCreateAlbum:(NSString *)albumName {
    // First, try to find existing album
    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.predicate = [NSPredicate predicateWithFormat:@"title = %@", albumName];
    PHFetchResult *fetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:fetchOptions];
    
    if (fetchResult.count > 0) {
        return fetchResult.firstObject;
    }
    
    // If not found, create new album
    __block PHAssetCollection *createdAlbum = nil;
    [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        PHAssetCollectionChangeRequest *createRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:albumName];
        createdAlbum = createRequest.placeholderForCreatedAssetCollection;
    } error:nil];
    
    // Get the actual created album
    if (createdAlbum) {
        PHFetchResult *fetchResult = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[createdAlbum.localIdentifier] options:nil];
        if (fetchResult.count > 0) {
            return fetchResult.firstObject;
        }
    }
    
    return nil;
}




+(void) createAlbumIfNotExist:(NSString *)album{
    [self findOrCreateAlbum:album];
}

@end

