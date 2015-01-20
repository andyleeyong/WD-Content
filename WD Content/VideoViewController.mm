//
//  VideoViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 12.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VideoViewController.h"

#import "Demuxer.h"
#import "MBProgressHUD.h"

#import <CoreMedia/CoreMedia.h>

@interface VideoViewController () <DemuxerDelegate> {
	dispatch_queue_t _videoOutputQueue;
}

@property (strong, nonatomic) Demuxer* demuxer;

@property (strong, nonatomic) AVSampleBufferDisplayLayer *videoOutput;

- (IBAction)done:(id)sender;

@end

@implementation VideoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.title = [_node.info title] ? _node.info.title : _node.name;
	
	_videoOutputQueue = dispatch_queue_create("com.vchannel.WD-Content.VideoOutput", DISPATCH_QUEUE_SERIAL);
	
	_videoOutput = [[AVSampleBufferDisplayLayer alloc] init];
	_videoOutput.videoGravity = AVLayerVideoGravityResizeAspect;
	_videoOutput.backgroundColor = [[UIColor blackColor] CGColor];
	
	CMTimebaseRef tmBase = nil;
	CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(), CMClockGetHostTimeClock(),&tmBase);
	_videoOutput.controlTimebase = tmBase;
	CMTimebaseSetTime(_videoOutput.controlTimebase, CMTimeMake(5, 1));
	CMTimebaseSetRate(_videoOutput.controlTimebase, 1.0);
	
	[self layoutScreen];
	
	_demuxer = [[Demuxer alloc] init];
	_demuxer.delegate = self;
	
	[MBProgressHUD showHUDAddedTo:self.view animated:YES];
	[_demuxer openWithPath:_node.path completion:^(BOOL success) {
		dispatch_async(dispatch_get_main_queue(), ^() {
			[MBProgressHUD hideHUDForView:self.view animated:YES];
			if (!success) {
				[self errorOpen];
			} else {
				[self play];
			}
		});
	}];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)errorOpen
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error open movie"
													message:@"Error reading or media format not supported"
												   delegate:self
										  cancelButtonTitle:@"Ok"
										  otherButtonTitles:nil];
	[alert show];
}

- (void)layoutScreen
{
	[_videoOutput removeFromSuperlayer];
	_videoOutput.bounds = self.view.bounds;
	_videoOutput.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
	[self.view.layer addSublayer:_videoOutput];
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self layoutScreen];
}

- (void)play
{
	[_demuxer play];
	[_videoOutput requestMediaDataWhenReadyOnQueue:_videoOutputQueue usingBlock:^() {
		while (_videoOutput.isReadyForMoreMediaData) {
			CMSampleBufferRef buffer = _demuxer.takeVideo;
			if (buffer) {
				[_videoOutput enqueueSampleBuffer:buffer];
				CFRelease(buffer);
			} else {
				break;
			}
		}
	}];
}

- (void)stop
{
	[_videoOutput stopRequestingMediaData];
	[_demuxer stop];
}

- (IBAction)done:(id)sender
{
	[self stop];
	[_demuxer close];
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didStopped:(Demuxer *)demuxer
{
	NSLog(@"demuxer finished");
}

@end
