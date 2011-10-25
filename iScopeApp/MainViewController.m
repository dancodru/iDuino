#import "MainViewController.h"
#import "GraphView.h"

#define kUpdateFrequency	60.0
#define kLabelFrequency     10 // divider

#define kLocalizedPause		NSLocalizedString(@"Pause","pause taking samples")
#define kLocalizedResume	NSLocalizedString(@"Resume","resume taking samples")

@interface GraphData : NSObject
{
@public
    double x;
}

@property(nonatomic,readwrite) double x;

@end

@implementation GraphData
@synthesize x;
@end

@interface MainViewController()

@end

@implementation MainViewController

@synthesize graphView, pauseButton, xValueLabel; 

// Subclasses override this method to define how the view they control will respond to device rotation 
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (interfaceOrientation == UIDeviceOrientationLandscapeLeft ||
        interfaceOrientation == UIDeviceOrientationLandscapeRight) {
        return YES;
    }
    else
    {
        return NO;
    }
}

// Implement viewDidLoad to do additional setup after loading the view.
-(void)viewDidLoad
{
	[super viewDidLoad];
	
    isPaused = YES;
    [pauseButton setTitle:kLocalizedResume forState:UIControlStateNormal];

    divider = 0;
	[[UIAccelerometer sharedAccelerometer] setUpdateInterval:1.0 / kUpdateFrequency];
//	[[UIAccelerometer sharedAccelerometer] setDelegate:self];
	
	[graphView setIsAccessibilityElement:YES];
	[graphView setAccessibilityLabel:NSLocalizedString(@"unfilteredGraph", @"")];
    
    NSOperationQueue *queue = [NSOperationQueue new];
    NSInvocationOperation *operation = [[NSInvocationOperation alloc] 
                                        initWithTarget:self
                                        selector:@selector(readSerial) 
                                        object:nil];
    [queue addOperation:operation]; 
    [operation release];
}

#define CHANNELS 1
#define FREQ 50.0

typedef struct {
    char Channels;
    char BytesPerSample;
    char IDAC_Value;
    unsigned char VDAC_Value;
    uint Period;
} SendHeader;

typedef union {
    SendHeader Header;
    char buff[8];
} TxBuffer;

typedef union {
    int nums[CHANNELS];
    unsigned char buff[CHANNELS * 1];
} RxBuffer;

- (void)readSerial 
{
    for (; ; ) {
        if (isPaused == YES) {
            [NSThread sleepForTimeInterval:0.02];
        }
        else {   
            // 1843200 921600 460800 115200
            serialFD = OpenSerialPort(115200);
            
            double maxValue = (double)(1 << 8);
            RxBuffer data;
            
            //char buff[] = { 0x03, 0x04, 0x60, 0x01, 0x12, 0x00, 0x0A, 0x64 };
            TxBuffer txBuffer;
            txBuffer.Header.Channels = 0;
            
            WriteSerial(serialFD, txBuffer.buff, 8);
            
            [NSThread sleepForTimeInterval:0.1];
            
            txBuffer.Header.Channels = CHANNELS;
            txBuffer.Header.BytesPerSample = 4;
            double sampleFrequency = FREQ; // Hz
            txBuffer.Header.Period = (uint)(5900000.0 / sampleFrequency);
            txBuffer.Header.IDAC_Value = 10;
            txBuffer.Header.VDAC_Value = 100;
            
            WriteSerial(serialFD, txBuffer.buff, 8);
            
            GraphData *graphData = [GraphData alloc];

            for (; ; ) {
                if (graphView != nil && isPaused == NO) {
                    ReadSerial(serialFD, data.buff, 1 * CHANNELS);
                    
                    graphData.x = data.buff[0] / maxValue;
                    
                    [self performSelectorOnMainThread:@selector(addData:) withObject:graphData waitUntilDone:NO];
                }
                else {
                    break;
                }
            }

            txBuffer.Header.Channels = 0;
            WriteSerial(serialFD, txBuffer.buff, 8);
            
            CloseSerial(serialFD);

            [graphData release];
        }
        
        if (graphView == nil){
            break;
        }
    }
}

-(void)refreshView:(NSObject *)obj
{
    [graphView advanceSegments];
}

-(void)addData:(GraphData *)graphData
{
    [graphView addX:graphData.x];
    divider++;
    if (divider % kLabelFrequency == 0) {
        NSString *xText = [NSString stringWithFormat:@"%.2fmV", graphData.x * 3300.0];
        
        xValueLabel.text = xText;
    }
}

-(void)viewDidUnload
{
	[super viewDidUnload];
	self.graphView = nil;
    self.pauseButton = nil;
    self.xValueLabel = nil;
}

-(IBAction)pauseButtonPressed:(id)sender
{
	if(isPaused)
	{
		// If we're paused, then resume and set the title to "Pause"
		isPaused = NO;
		[pauseButton setTitle:kLocalizedPause forState:UIControlStateNormal];
	}
	else
	{
		// If we are not paused, then pause and set the title to "Resume"
		isPaused = YES;
		[pauseButton setTitle:kLocalizedResume forState:UIControlStateNormal];
	}
	
	// Inform accessibility clients that the pause/resume button has changed.
	UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

-(void)dealloc
{
	// clean up everything.
	[graphView release];
	[pauseButton release];
	[xValueLabel release];

	[super dealloc];
}

@end
