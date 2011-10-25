#import "AppDelegate.h"
#import "MainViewController.h"

@implementation AppDelegate

@synthesize window, viewController;

-(void)applicationDidFinishLaunching:(UIApplication*)application
{
	// Add the view controller's view to the window
	[window addSubview:viewController.view];
}

// Release resources.
-(void)dealloc
{
    [window release];
	[viewController release];
    [super dealloc];
}

@end
