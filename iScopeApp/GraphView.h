#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@class GraphViewSegment;
@class GraphTextView;
@interface GraphView : UIView
{
	NSMutableArray *segments;
	GraphViewSegment *current; // weak reference
	GraphTextView *text; // weak reference
}

-(void)addX:(double)x;
-(void)advanceSegments;
@end
