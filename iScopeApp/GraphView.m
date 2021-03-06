#import "GraphView.h"

#pragma mark - Overview of operation

// The GraphView class needs to be able to update the scene quickly in order to track the accelerometer data
// at a fast enough frame rate. The naive implementation tries to draw the entire graph every frame,
// but unfortunately that is too much content to sustain a high framerate. As such this class uses CALayers
// to cache previously drawn content and arranges them carefully to create an illusion that we are
// redrawing the entire graph every frame.

#pragma mark - Quartz Helpers

// Functions used to draw all content

CGColorRef CreateDeviceGrayColor(CGFloat w, CGFloat a)
{
	CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
	CGFloat comps[] = {w, a};
	CGColorRef color = CGColorCreate(gray, comps);
	CGColorSpaceRelease(gray);
	return color;
}

CGColorRef CreateDeviceRGBColor(CGFloat r, CGFloat g, CGFloat b, CGFloat a)
{
	CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
	CGFloat comps[] = {r, g, b, a};
	CGColorRef color = CGColorCreate(rgb, comps);
	CGColorSpaceRelease(rgb);
	return color;
}

CGColorRef graphBackgroundColor()
{
	static CGColorRef c = NULL;
	if(c == NULL)
	{
		c = CreateDeviceGrayColor(0.6, 1.0);
	}
	return c;
}

CGColorRef graphLineColor()
{
	static CGColorRef c = NULL;
	if(c == NULL)
	{
		c = CreateDeviceGrayColor(0.5, 1.0);
	}
	return c;
}

CGColorRef graphXColor()
{
	static CGColorRef c = NULL;
	if(c == NULL)
	{
		c = CreateDeviceRGBColor(1.0, 0.0, 0.0, 1.0);
	}
	return c;
}

CGColorRef graphYColor()
{
	static CGColorRef c = NULL;
	if(c == NULL)
	{
		c = CreateDeviceRGBColor(0.0, 0.8, 0.0, 1.0);
	}
	return c;
}

CGColorRef graphZColor()
{
	static CGColorRef c = NULL;
	if(c == NULL)
	{
		c = CreateDeviceRGBColor(0.0, 0.0, 1.0, 1.0);
	}
	return c;
}

void DrawGridlines(CGContextRef context, CGFloat x, CGFloat width)
{
	for(CGFloat y = -5; y > -260; y -= 22.73)
	{
		CGContextMoveToPoint(context, x, y);
		CGContextAddLineToPoint(context, x + width, y);
	}
	CGContextSetStrokeColorWithColor(context, graphLineColor());
	CGContextStrokePath(context);
}

#pragma mark - GraphViewSegment

// The GraphViewSegment manages up to 32 accelerometer values and a CALayer that it updates with
// the segment of the graph that those values represent. 

@interface GraphViewSegment : NSObject
{
	CALayer *layer;
	// Need 33 values to fill 32 pixel width.
	double xhistory[33];
	int index;
}

// returns true if adding this value fills the segment, which is necessary for properly updating the segments
-(BOOL)addX:(double)x; 

// When this object gets recycled (when it falls off the end of the graph)
// -reset is sent to clear values and prepare for reuse.
-(void)reset;

// Returns true if this segment has consumed 32 values.
-(BOOL)isFull;

// Returns true if the layer for this segment is visible in the given rect.
-(BOOL)isVisibleInRect:(CGRect)r;

// The layer that this segment is drawing into
@property(nonatomic, readonly) CALayer *layer;

@end

@implementation GraphViewSegment

@synthesize layer;

-(id)init
{
	self = [super init];
	if(self != nil)
	{
		layer = [[CALayer alloc] init];
		// the layer will call our -drawLayer:inContext: method to provide content
		// and our -actionForLayer:forKey: for implicit animations
		layer.delegate = self;
		// This sets our coordinate system such that it has an origin of 0.0,-56 and a size of 32,260.
		// This would need to be changed if you change either the number of pixel values that a segment
		// represented, or if you changed the size of the graph view.
		layer.bounds = CGRectMake(0.0, -260, 32.0, 260);
		// Disable blending as this layer consists of non-transperant content.
		// Unlike UIView, a CALayer defaults to opaque=NO
		layer.opaque = YES;
		// Index represents how many slots are left to be filled in the graph,
		// which is also +1 compared to the array index that a new entry will be added
		index = 33;
	}
	return self;
}

-(void)dealloc
{
	[layer release];
	[super dealloc];
}

-(void)reset
{
	// Clear out our components and reset the index to 33 to start filling values again...
	memset(xhistory, 0, sizeof(xhistory));
	index = 33;
	// Inform Core Animation that we need to redraw this layer.
	[layer setNeedsDisplay];
}

-(BOOL)isFull
{
	// Simple, this segment is full if there are no more space in the history.
	return index == 0;
}

-(BOOL)isVisibleInRect:(CGRect)r
{
	// Just check if there is an intersection between the layer's frame and the given rect.
	return CGRectIntersectsRect(r, layer.frame);
}

-(BOOL)addX:(double)x
{
	// If this segment is not full, then we add a new acceleration value to the history.
	if(index > 0)
	{
		// First decrement, both to get to a zero-based index and to flag one fewer position left
		--index;
		xhistory[index] = x;
		// And inform Core Animation to redraw the layer.
		[layer setNeedsDisplay];
	}
	// And return if we are now full or not (really just avoids needing to call isFull after adding a value).
	return index == 0;
}

-(void)drawLayer:(CALayer*)l inContext:(CGContextRef)context
{
	// Fill in the background
	CGContextSetFillColorWithColor(context, graphBackgroundColor());
	CGContextFillRect(context, layer.bounds);
	
	// Draw the grid lines
	DrawGridlines(context, 0.0, 32.0);

	// Draw the graph
	CGPoint lines[64];
	int i;
	
	// X
	for(i = 0; i < 32; ++i)
	{
		lines[i*2].x = i;
		lines[i*2].y = -5 - xhistory[i] * 250.0;
		lines[i*2+1].x = i + 1;
		lines[i*2+1].y = -5 - xhistory[i+1] * 250.0;
	}
    
	CGContextSetStrokeColorWithColor(context, graphXColor());
	CGContextStrokeLineSegments(context, lines, 64);
}

-(id)actionForLayer:(CALayer *)layer forKey :(NSString *)key
{
	// We disable all actions for the layer, so no content cross fades, no implicit animation on moves, etc.
	return [NSNull null];
}

// The accessibilityValue of this segment should be the x,y,z values last added.
- (NSString *)accessibilityValue
{
	return [NSString stringWithFormat:NSLocalizedString(@"graphSegmentFormat", @""), xhistory[index]];
}

@end

#pragma mark - GraphTextView

// We use a seperate view to draw the text for the graph so that we can layer the segment layers below it
// which gives the illusion that the numbers are draw over the graph, and hides the fact that the graph drawing
// for each segment is incomplete until the segment is filled.

@interface GraphTextView : UIView
{
}

@end

@implementation GraphTextView

-(void)drawRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	// Fill in the background
	CGContextSetFillColorWithColor(context, graphBackgroundColor());
	CGContextFillRect(context, self.bounds);
	
	CGContextTranslateCTM(context, 0.0, 260.0);

	// Draw the grid lines
	DrawGridlines(context, 26.0, 6.0);

	// Draw the text
	UIFont *systemFont = [UIFont systemFontOfSize:10.0];
	[[UIColor whiteColor] set];
	[@"3300" drawInRect:CGRectMake(2.0,-262+22.73*0, 24.0, 30.0) withFont:systemFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentRight];
	[@"3000" drawInRect:CGRectMake(2.0,-262+22.73*1, 24.0, 30.0) withFont:systemFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentRight];
	[@"2700" drawInRect:CGRectMake(2.0,-262+22.73*2, 24.0, 30.0) withFont:systemFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentRight];
	[@"2400" drawInRect:CGRectMake(2.0,-262+22.73*3, 24.0, 30.0) withFont:systemFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentRight];
	[@"2100" drawInRect:CGRectMake(2.0,-262+22.73*4, 24.0, 30.0) withFont:systemFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentRight];
	[@"1800" drawInRect:CGRectMake(2.0,-262+22.73*5, 24.0, 30.0) withFont:systemFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentRight];
	[@"1500" drawInRect:CGRectMake(2.0,-262+22.73*6, 24.0, 30.0) withFont:systemFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentRight];
	[@"1200" drawInRect:CGRectMake(2.0,-262+22.73*7, 24.0, 30.0) withFont:systemFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentRight];
	[@" 900" drawInRect:CGRectMake(2.0,-262+22.73*8, 24.0, 30.0) withFont:systemFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentRight];
	[@" 600" drawInRect:CGRectMake(2.0,-262+22.73*9, 24.0, 30.0) withFont:systemFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentRight];
	[@" 300" drawInRect:CGRectMake(2.0,-262+22.73*10, 24.0, 30.0) withFont:systemFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentRight];
	[@"   0" drawInRect:CGRectMake(2.0,-262+22.73*11, 24.0, 30.0) withFont:systemFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentRight];
}

@end

#pragma mark - GraphView

// Finally the actual GraphView class. This class handles the public interface as well as arranging
// the subviews and sublayers to produce the intended effect. 

@interface GraphView()

// Internal accessors
@property(nonatomic, retain) NSMutableArray *segments;
@property(nonatomic, assign) GraphViewSegment *current;
@property(nonatomic, assign) GraphTextView *text;

// A common init routine for use with -initWithFrame: and -initWithCoder:
-(void)commonInit;

// Creates a new segment, adds it to 'segments', and returns a weak reference to that segment
// Typically a graph will have around a dozen segments, but this depends on the width of the graph view and segments
-(GraphViewSegment*)addSegment;

// Recycles a segment from 'segments' into  'current'
-(void)recycleSegment;
@end

@implementation GraphView

@synthesize segments, current, text;

// Designated initializer
-(id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self != nil)
	{
		[self commonInit];
	}
	return self;
}

// Designated initializer
-(id)initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];
	if(self != nil)
	{
		[self commonInit];
	}
	return self;
}

-(void)commonInit
{
	// Create the text view and add it as a subview. We keep a weak reference
	// to that view afterwards for laying out the segment layers.
	text = [[GraphTextView alloc] initWithFrame:CGRectMake(0.0, 0.0, 32.0, 260.0)];
	[self addSubview:text];
	[text release];
	
	// Create a mutable array to store segments, which is required by -addSegment
	segments = [[NSMutableArray alloc] init];

	// Create a new current segment, which is required by -addX:y:z and other methods.
	// This is also a weak reference (we assume that the 'segments' array will keep the strong reference).
	current = [self addSegment];
}

-(void)dealloc
{
	// Since 'text' and 'current' are weak references, we do not release them here.
	// [super dealloc] will take care to release 'text' as a subview, and releasing 'segments' will release 'current'.
	[segments release];
	[super dealloc];
}

-(void)addX:(double)x
{
	// First, add the new acceleration value to the current segment
	if([current addX:x])
	{
		// If after doing that we've filled up the current segment, then we need to
		// determine the next current segment
		[self recycleSegment];
		// And to keep the graph looking continuous, we add the acceleration value to the new segment as well.
		[current addX:x];
	}
    
  [self advanceSegments];
}                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          

-(void)advanceSegments
{
    // After adding a new data point, we need to advance the x-position of all the segment layers by 1 to
	// create the illusion that the graph is advancing.
	for(GraphViewSegment * s in segments)
	{
		CGPoint position = s.layer.position;
		position.x += 1.0;
		s.layer.position = position;
	}
}

-(GraphViewSegment*)addSegment
{
	// Create a new segment and add it to the segments array.
	GraphViewSegment * segment = [[GraphViewSegment alloc] init];
	// We add it at the front of the array because -recycleSegment expects the oldest segment
	// to be at the end of the array. As long as we always insert the youngest segment at the front
	// this will be true.
	[segments insertObject:segment atIndex:0];
	[segment release]; // this is now a weak reference
	
	// Ensure that newly added segment layers are placed after the text view's layer so that the text view
	// always renders above the segment layer.
	[self.layer insertSublayer:segment.layer below:text.layer];
	// Position it properly (see the comment for kSegmentInitialPosition)
	segment.layer.position = CGPointMake(14.0, 130);
	
	return segment;
}

-(void)recycleSegment
{
	// We start with the last object in the segments array, as it should either be visible onscreen,
	// which indicates that we need more segments, or pushed offscreen which makes it eligable for recycling.
	GraphViewSegment * last = [segments lastObject];
	if([last isVisibleInRect:self.layer.bounds])
	{
		// The last segment is still visible, so create a new segment, which is now the current segment
		current = [self addSegment];
	}
	else
	{
		// The last segment is no longer visible, so we reset it in preperation to be recycled.
		[last reset];
		// Position it properly (see the comment for kSegmentInitialPosition)
		last.layer.position = CGPointMake(14.0, 130);;
		// Move the segment from the last position in the array to the first position in the array
		// as it is now the youngest segment.
		[segments insertObject:last atIndex:0];
		[segments removeLastObject];
		// And make it our current segment
		current = last;
	}
}

// The graph view itself exists only to draw the background and gridlines. All other content is drawn either into
// the GraphTextView or into a layer managed by a GraphViewSegment.
-(void)drawRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	// Fill in the background
	CGContextSetFillColorWithColor(context, graphBackgroundColor());
	CGContextFillRect(context, self.bounds);
	
	CGFloat width = self.bounds.size.width;
	CGContextTranslateCTM(context, 0.0, 260.0);

	// Draw the grid lines
	DrawGridlines(context, 0.0, width);
}


// Return an up-to-date value for the graph.
- (NSString *)accessibilityValue
{
	if (segments.count == 0)
	{
		return nil;
	}
	
	// Let the GraphViewSegment handle its own accessibilityValue;
	GraphViewSegment *graphViewSegment = [segments objectAtIndex:0];
	return [graphViewSegment accessibilityValue];
}

@end
