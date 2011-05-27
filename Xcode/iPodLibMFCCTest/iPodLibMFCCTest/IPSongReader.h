//
//  IPSongReader.h
//  iPodLibMFCCTest
//
//  Created by Heinrich Fink on 5/20/11.
//  Copyright 2011 Heinrich Fink. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMTimeRange.h>
#import <CoreMedia/CMSampleBuffer.h>

/**
 * This class provides the means to consume the audio samples from any 
 * audio-based medium accessible by an URL, for a specified duration. 
 * Since this class uses AVFoundation, it will also understand the special
 * ipod:// URL, as accessible by a MediaQuery.
 */
@interface IPSongReader : NSObject {
    BOOL (^consumer_block_)(CMSampleBufferRef);
}

@property (nonatomic, retain) AVAssetReader* assetReader;
@property (nonatomic, retain) AVAssetReaderOutput* assetOutput;

/**
 * Initializes the reader. This call might return nil, when an error occurred
 * during initialization of the assetReader or assetOutput property of this
 * class. Be aware that this initializer synchronously asks the media server 
 * to open the audio file. This might take some time. Be aware of that.
 *
 * @param url The URL pointing to the audio file to be opened.
 * @param seconds Amount of time, for which samples shall be consumed by the caller.
 * The duration given here refers to the middle of the song, i.e. we read samples
 * in the range of [songTotal/2 - duration/2; songTotal/2 + duration/2]
 * @param samplingRate The sampling rate in which the client wants to access the
 * audio samples.
 * @param numChannels If set to "1", the audio format that is used to request
 * audio samples from the media server is set to mono (effectively de-interleaved).
 * If set to "2", the audio format is set to stereo interleaved (this can be asked
 * for with the CMSamplerBuffer passed to client).
 * @param consumer_block A block provided by the caller. This block is called
 * synchronously and is being passed a CMSamplerBuffer element, that is only
 * guaranteed to be valid during the callback in the block. A block returns the
 * success of its consumption operation as a BOOL variable. Return YES if the 
 * execution was successful, return NO if the execution encountered an error and
 * when you want the consumption process to be terminated.
 */
- (id)initWithURL:(NSURL*)url 
     forDuration:(float)seconds 
     samplingRate:(Float64)samplingRate
      numChannels:(NSUInteger)numChannels
        withBlock:(BOOL (^)(CMSampleBufferRef)) consumer_block;

/**
 * Triggers the actual consumption of the designated file. The consumer_block
 * as given by the initializer will then be called sequntially. Note that this
 * call executes synchronously, i.e. it will block until the complete duration
 * has been consumed by the consumer block.
 *
 * @return YES if consumption was successful, NO otherwise.
 */
- (BOOL)consumeRange;

- (void)cancel;

@end
