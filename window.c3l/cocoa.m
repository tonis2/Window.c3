#import <Cocoa/Cocoa.h>

typedef struct Window_Params
{
    int x;
    int y;
    int width;
    int height;
} Window_Params;

NSUInteger windowStyle = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable;

void new(Window_Params params) {
    NSRect frame = NSMakeRect(params.x, params.y, params.width, params.height);
    // NSLog(@"CREATE WINDOW %d", params.y);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:windowStyle backing:NSBackingStoreBuffered defer:NO];
    // Make it blue just for better visibility
    [window setBackgroundColor:[NSColor blackColor]];
    // Bring to front and make it key
    [window makeKeyAndOrderFront:nil];
    [window setTitle: [NSString stringWithUTF8String:"Mac window"]];
    // Custom run loop
    NSEvent* event;
    while(1) {
        do {
            event = [window nextEventMatchingMask:NSEventMaskAny]; //window shows now
            if ([event type] == NSEventTypeLeftMouseDown) {
                NSLog(@"Mouse down");
            }
            else {
                NSLog(@"Something happened");
            }
        } while (event != nil);
    }

    [window autorelease];
}