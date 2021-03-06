//Copyright (c) 2011 Heinrich Fink hf@hfink.eu
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in
//all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//THE SOFTWARE.

#import "IPViewController.h"

#import <MediaPlayer/MediaPlayer.h>

#include <dispatch/dispatch.h>

#include <mach/mach_time.h>

#include "WordMatch.h"

#include "IPSongReader.h"

@implementation IPViewController
@synthesize ibHeaderLabel = ibHeaderLabel_;
@synthesize ibMfccAvgLabel;
@synthesize ibTitleLabel = ibTitleLabel_;
@synthesize ibActivityIndicator = ibActivityIndicator_;
@synthesize ibAvgDurationPerSong = ibAvgDurationPerSong_;
@synthesize ibBenchmarkButton = ibBenchmarkButton_;
@synthesize ibArtistLabel;
@synthesize ibTotalDuration = ibTotalDuration_;
@synthesize ibBenchmarkProgress = ibBenchmarkProgress_;
@synthesize ibCounterLabel;
@synthesize mfccMelMax;
@synthesize mfccWindowSize;
@synthesize ibChannelSwitch;
@synthesize ibModeSelector;
@synthesize samplingRate;
@synthesize numChannelsRequest;

- (void)dealloc
{
    [ibBenchmarkProgress_ release];
    [ibTotalDuration_ release];
    [ibAvgDurationPerSong_ release];
    [ibActivityIndicator_ release];
    [ibTitleLabel_ release];
    [ibBenchmarkButton_ release];
    [ibTitleLabel_ release];
    [ibHeaderLabel_ release];
    [ibCounterLabel release];
    [ibMfccAvgLabel release];
    [ibArtistLabel release];
    [ibModeSelector release];
    [ibChannelSwitch release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)hideRunningLabels
{
    [self.ibArtistLabel setHidden:YES];
    [self.ibTitleLabel setHidden:YES];          
}

- (void)showRunningLabels
{
    [self.ibArtistLabel setHidden:NO];
    [self.ibTitleLabel setHidden:NO];           
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    isExecutingBenchmark = NO;
    
    //We use an operation queue to hand off the batch processing task
    //of processing all media files available
    [self hideRunningLabels];
    
    //Initial configuration
    self.mfccMelMax = 15000;
    self.samplingRate = 44100;
    self.mfccWindowSize = 1024;
    self.numChannelsRequest = 2;
}


- (void)viewDidUnload
{
    [self setIbBenchmarkProgress:nil];
    [self setIbTotalDuration:nil];
    [self setIbAvgDurationPerSong:nil];
    [self setIbActivityIndicator:nil];
    [self setIbTitleLabel:nil];
    [self setIbBenchmarkButton:nil];
    [self setIbTitleLabel:nil];
    [self setIbHeaderLabel:nil];
    [self setIbCounterLabel:nil];
    [self setIbMfccAvgLabel:nil];
    [self setIbArtistLabel:nil];
    [self setIbModeSelector:nil];
    [self setIbChannelSwitch:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)startOrStopBenchmark:(id)sender {
    
    if (isExecutingBenchmark) {
        
        //stop the benchmark process
        isExecutingBenchmark = NO;
        
    } else {
        
        self.ibModeSelector.enabled = NO;
        self.ibChannelSwitch.enabled = NO;
        
        [self.ibBenchmarkButton setTitle:@"Stop Benchmark" forState:UIControlStateNormal];        
        isExecutingBenchmark = YES;
        
        //Note that this MUST be low priority or else we will get a weird
        //error by AVFoundation later on...
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
        
        dispatch_async(queue, ^{
            
            //Initialization the MFCC Session provided by our WordMatch lib
            
            static const float mfcc_duration = 30.0f;            
            
            float * mfcc_average = malloc(sizeof(float)*13);
            memset(mfcc_average, 0, sizeof(float)*13);
            
            WMSessionRef mfcc_session;            
            WMMfccConfiguration mfcc_config;
            mfcc_config.mel_min_freq = 20.0f;
            mfcc_config.mel_max_freq = self.mfccMelMax;
            mfcc_config.sampling_rate = self.samplingRate;
            mfcc_config.pre_empha_alpha = 0.97f;           
            mfcc_config.window_size = self.mfccWindowSize;            
            
            WMSessionResult result = WMSessionCreate(mfcc_duration, 
                                                     mfcc_config, 
                                                     &mfcc_session);
            
            if (result != kWMSessionResultOK) {
                NSLog(@"WMSession returned %hd, exiting calculation", result);
                return;
            }            
            
            dispatch_queue_t main_queue = dispatch_get_main_queue();            
            
            NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
            
            MPMediaPropertyPredicate *music_type_filter = 
            [MPMediaPropertyPredicate predicateWithValue: [NSNumber numberWithInt:MPMediaTypeMusic]
                                             forProperty: MPMediaItemPropertyMediaType];       


            //Use the commented code to pick out a particular song with its title
            //from the iPod lib.
            
//            MPMediaPropertyPredicate* debug_filter = [MPMediaPropertyPredicate predicateWithValue: @"Wake Up"
//                                                                                      forProperty: MPMediaItemPropertyTitle];                   
//            NSSet* predicate_set = [NSSet setWithObjects:music_type_filter, debug_filter, nil];
            
            NSSet* predicate_set = [NSSet setWithObject:music_type_filter];            

            
            MPMediaQuery* songs_query = [[MPMediaQuery alloc] initWithFilterPredicates:predicate_set];
            
            NSArray* all_songs = [songs_query items];
            
            dispatch_async(main_queue, ^{  
                
                NSString * str = [[NSString alloc] initWithFormat:@"Reading %u songs", [all_songs count]];        
                
                [self.ibHeaderLabel setText:str];
                
                [str release];
                
            });            
            
            double duration = 0;
            
            int songs_counter = 0;
            
            uint64_t now = mach_absolute_time();
            double song_processing_start = WMMachTimeToMilliSeconds(now);                            
            double song_processing_end = 0;
            
            BOOL was_canceled = NO;
            BOOL was_error = NO;            
            
            NSAutoreleasePool* song_pool = nil;            
            
            for (MPMediaItem* song in all_songs) {
                
                song_pool = [[NSAutoreleasePool alloc] init];                
                
                //Resetting the session
                result = WMSessionReset(mfcc_session);
                if (result != kWMSessionResultOK) {
                    NSLog(@"Could not reset WMSessin: %hd", result);
                    was_error = YES;
                    break;
                }
                
                NSString * title = [song valueForProperty:MPMediaItemPropertyTitle];
                NSString * artist = [song valueForProperty:MPMediaItemPropertyArtist];                
                NSURL* song_url = [song valueForProperty:MPMediaItemPropertyAssetURL];
                
                if (song_url == nil) {
                    
                    NSLog(@"Can not access MPMediaItemPropertyAssetURL for song '%@'.", title);
                    duration = 0;
                    
                } else {
                    
                    IPSongReader* song_reader = [[IPSongReader alloc] initWithURL:song_url 
                                                                      forDuration:mfcc_duration 
                                                                     samplingRate:self.samplingRate
                                                                      numChannels:self.numChannelsRequest
                                                                        withBlock:^BOOL(CMSampleBufferRef sample_buffer) {
                                                                            
                                                                            if (!WMSessionIsCompleted(mfcc_session)) {
                                                                                WMSessionResult mfcc_result = WMSessionFeedFromSampleBuffer(sample_buffer, mfcc_session);
                                                                                if (mfcc_result != kWMSessionResultOK) {
                                                                                    NSLog(@"MFCC calculation returned an error: %hd", mfcc_result);
                                                                                    return NO;
                                                                                }
                                                                            } else {
                                                                                NSLog(@"Session was already completed.");
                                                                            }
                                                                            
                                                                            return TRUE;
                                                                        }];
                    
                    //Make the paths below easier to maintain by additn try catch finally
                    if (song_reader == nil) {
                        NSLog(@"Song reader initialization failed.");
                        was_error = YES;
                        break;
                        continue;
                    }                    
                    
                    Float64 duration_sec = CMTimeGetSeconds([song_reader.assetReader.asset duration]);
                    if (duration_sec < mfcc_duration+2) {
                        NSLog(@"Song '%@' by '%@' is too short, skipping it. You \
                              should remove this song from the test set to \
                              prevent it from biasing the results.", 
                              title, 
                              artist);
                        [song_reader release];
                        continue;
                    }
                    
                    dispatch_async(main_queue, ^{                      
                    
                        [self showRunningLabels];
                        
                        [self.ibTitleLabel setText:title];
                        [self.ibArtistLabel setText:artist];
                        [self.ibBenchmarkProgress setProgress:songs_counter/(float)[all_songs count]];
                        
                        NSString* str = [[NSString alloc] initWithFormat:@"%i / %u", songs_counter+1, [all_songs count]];                    
                        [self.ibCounterLabel setText:str];                    
                        [str release];                    
                        
                    });
                    
                    
                    //Start processing that stuff
                    BOOL success = [song_reader consumeRange];
                    if (!success) {
                        NSLog(@"Could not consume the song properly.");
                        was_error = YES;
                        [song_reader release];
                        break;
                    }
                    
                    //Get the average MFCC values
                    result = WMSessionGetAverage(mfcc_average, mfcc_session);
                    if (result != kWMSessionResultOK) {
                        NSLog(@"WMSessionGetAverage returned an error: %hd", result);
                        was_error = YES;
                        [song_reader release];
                        break;
                    }
                    
                    song_processing_end = WMMachTimeToMilliSeconds(mach_absolute_time());
                    
                    duration = (song_processing_end - song_processing_start)*1e-3;
                    
                    [song_reader release];     
                    
                }
                
                songs_counter++;                
                
                //Update GUI information
                
                dispatch_async(main_queue, ^{  
                    
                    double avg_song_time = duration / (double)songs_counter;
                    
                    NSString * str = [[NSString alloc] initWithFormat:@"%.2f sec", avg_song_time];
                    [self.ibAvgDurationPerSong setText:str];
                    [str release];
                    
                    str = [[NSString alloc] initWithFormat:@"%.2f sec", duration];
                    [self.ibTotalDuration setText:str];
                    [str release];
                    
                    str = [[NSString alloc] initWithFormat:@"%.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f", 
                                                           mfcc_average[0], 
                                                           mfcc_average[1],
                                                           mfcc_average[2],
                                                           mfcc_average[3],
                                                           mfcc_average[4],
                                                           mfcc_average[5],
                                                           mfcc_average[6],
                                                           mfcc_average[7],
                                                           mfcc_average[8],
                                                           mfcc_average[9],
                                                           mfcc_average[10],
                                                           mfcc_average[11],
                                                           mfcc_average[12]];                    
                    [self.ibMfccAvgLabel setText:str];                    
                    
                    [str release];                    
                    
                });
                
                //Check early exit
                if (isExecutingBenchmark == NO) {
                    was_canceled = YES;
                    break;
                }
                
                [song_pool release];
                song_pool = nil;
            }            
            
            [song_pool release];
            
            dispatch_async(main_queue, ^{  
                
                NSString * str = [[NSString alloc] initWithFormat:@"%.2f sec", duration];
                [self.ibTotalDuration setText:str];
                [str release];
                
                if (was_canceled)
                    [self.ibHeaderLabel setText:@"User canceled benchmark"];
                else if (was_error)
                    [self.ibHeaderLabel setText:@"Error in benchmark process"];                    
                else
                    [self.ibHeaderLabel setText:@"All song were processed successfully"];                    
                
                isExecutingBenchmark = NO;
                
                //[self hideRunningLabels];
                self.ibModeSelector.enabled = YES;
                self.ibChannelSwitch.enabled = YES;
                
                [self.ibBenchmarkButton setTitle:@"Run Benchmark" forState:UIControlStateNormal];
                [self.ibBenchmarkProgress setProgress:.0f];
                [self.ibActivityIndicator stopAnimating];
                
            });           
            
            [songs_query release];
            [pool release];                  
            result = WMSessionDestroy(mfcc_session);
            if (result != kWMSessionResultOK)
                NSLog(@"After destruction, WMSession returned %hd", result);
            
            free(mfcc_average);
            
        });
        
        [self.ibActivityIndicator startAnimating];
        [self.ibBenchmarkProgress setProgress:.0f];
                
    }
    
}
- (IBAction)ibChangeMode:(id)sender {
    
    if (self.ibModeSelector.selectedSegmentIndex == 0) {
        self.mfccWindowSize = 370;
        self.mfccMelMax = 8000;
        self.samplingRate = 16000;
    } else {
        self.mfccWindowSize = 1024;
        self.mfccMelMax = 15000;
        self.samplingRate = 44100;        
    }
    
}
- (IBAction)ibChangeChannelMode:(id)sender {
    if (self.ibChannelSwitch.selectedSegmentIndex == 0)
        self.numChannelsRequest = 1;
    else
        self.numChannelsRequest = 2;
}

@end
