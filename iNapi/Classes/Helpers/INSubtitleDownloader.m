//
//  INSubtitleDownloader.m
//  iNapi
//
//  Created by Wojtek Nagrodzki on 22/06/2012.
//  Copyright (c) 2012 Trifork. All rights reserved.
//

#import "INSubtitleDownloader.h"
#import "INErrors.h"


@interface INSubtitleDownloader ()

@property (assign, nonatomic) dispatch_queue_t downloadQueue;
@property (strong, nonatomic) NSFileManager * fileManager;

@end


@implementation INSubtitleDownloader

+ (INSubtitleDownloader *)sharedDownloader
{
    __strong static id _sharedObject = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (id)init
{
    self = [super init];
    if (self) {
        _downloadQueue = dispatch_queue_create("com.izydor86.inapi.downloadSubtitles", DISPATCH_QUEUE_SERIAL);
        _fileManager = [NSFileManager defaultManager];
    }
    return self;
}

- (void)dealloc
{
    dispatch_release(_downloadQueue);
    _downloadQueue = NULL;
}

#pragma mark - Interface

-(void)downloadSubtitlesAtURL:(NSURL *)subtitlesURL forMovieAtURL:(NSURL *)movieURL completionHandler:(void (^)(NSURL * downloadedSubtitlesURL, NSError * downloadError))completionHandler
{
    dispatch_async(self.downloadQueue, ^{
        
        // download subtitles
        NSError * error;
        NSString * subtitles = [NSString stringWithContentsOfURL:subtitlesURL
                                                        encoding:NSWindowsCP1250StringEncoding
                                                           error:&error];
        
        if (error) {
            completionHandler(nil, error);
            return;
        }
        
        // check if subtitles were found, if not pass error
        if ([subtitles isEqualToString:@"NPc0"]) {
            error = [NSError errorWithDomain:iNapiErrorDomain code:iNapiSubtitlesNotFound userInfo:nil];
            completionHandler(nil, error);
            return;
        }
        
        // construct URL where subtitles will to be stored
        NSURL * subtitlesSaveURL = [[movieURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"txt"];
        
        // rename existing subtitles if necessary
        BOOL archivePreviousSubtitles = [self.delegate subtitleDownloader:self shouldArchivePreviousSubtitlesAtURL:subtitlesSaveURL forMovieAtURL:movieURL];
        if (archivePreviousSubtitles && [self.fileManager fileExistsAtPath:subtitlesSaveURL.path] == YES) {
            NSURL * archiverSubtitlesSaveURL = [self archivedURLWithURL:subtitlesSaveURL];
            if ([self.fileManager moveItemAtURL:subtitlesSaveURL toURL:archiverSubtitlesSaveURL error:&error] == NO) {
                completionHandler(nil, error);
                return;
            }
        }
        
        // save subtitles
        NSStringEncoding encoding = self.convertToUTF8 == YES ? NSUTF8StringEncoding : NSWindowsCP1250StringEncoding;
        if ([subtitles writeToURL:subtitlesSaveURL atomically:YES encoding:encoding error:&error] == NO) {
            completionHandler(nil, error);
            return;
        }
        
        completionHandler(subtitlesSaveURL, nil);
    });
}

#pragma mark - Private

- (NSURL *)archivedURLWithURL:(NSURL *)url
{
    NSString * lastPathComponent = [url lastPathComponent];
    NSString * dateAndExtension = [NSString stringWithFormat:@"%@.txt", [NSDate date]];
    lastPathComponent = [lastPathComponent stringByReplacingOccurrencesOfString:@".txt" withString:dateAndExtension];
    
    return [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:lastPathComponent];
}

@end
