#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/IOCFPlugIn.h>

@interface USBMonitorAppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate>
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSMenu *menu;
@property (strong, nonatomic) NSMenuItem *toggleMenuItem;
@property (strong, nonatomic) NSMenuItem *logMenuItem;
@property (strong, nonatomic) NSMenuItem *notificationsMenuItem;
@property (strong, nonatomic) NSWindow *logWindow;
@property (strong, nonatomic) NSTextView *logTextView;
@property (assign, nonatomic) BOOL isMonitoring;
@property (assign, nonatomic) BOOL notificationsEnabled;
@property (assign, nonatomic) IONotificationPortRef notificationPort;
@property (assign, nonatomic) io_iterator_t addedIterator;
@property (assign, nonatomic) io_iterator_t removedIterator;
@property (strong, nonatomic) NSMutableArray *logEntries;
- (void)toggleMonitoring;
- (void)toggleNotifications;
- (void)setupUSBNotifications;
- (void)tearDownUSBNotifications;
- (void)deviceAdded:(io_iterator_t)iterator;
- (void)deviceRemoved:(io_iterator_t)iterator;
- (void)showLog;
- (void)addLogEntry:(NSString *)entry isConnected:(BOOL)isConnected;
- (void)showNotification:(NSString *)title message:(NSString *)message;
@end

// C callback functions
void DeviceAdded(void *refCon, io_iterator_t iterator) {
    USBMonitorAppDelegate *self = (__bridge USBMonitorAppDelegate *)refCon;
    [self deviceAdded:iterator];
}

void DeviceRemoved(void *refCon, io_iterator_t iterator) {
    USBMonitorAppDelegate *self = (__bridge USBMonitorAppDelegate *)refCon;
    [self deviceRemoved:iterator];
}

@implementation USBMonitorAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Initialize log entries array
    self.logEntries = [NSMutableArray array];
    
    // Set up status item in menu bar
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setTitle:@"USB*"];
    [self.statusItem setHighlightMode:YES];
    
    // Create menu
    self.menu = [[NSMenu alloc] init];
    self.toggleMenuItem = [[NSMenuItem alloc] initWithTitle:@"Stop Monitoring" 
                                                    action:@selector(toggleMonitoring) 
                                             keyEquivalent:@""];
    self.logMenuItem = [[NSMenuItem alloc] initWithTitle:@"Show Log" 
                                                  action:@selector(showLog) 
                                           keyEquivalent:@""];
    self.notificationsMenuItem = [[NSMenuItem alloc] initWithTitle:@"Disable Notifications" 
                                                          action:@selector(toggleNotifications) 
                                                   keyEquivalent:@""];
    
    NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit" 
                                                          action:@selector(terminate:) 
                                                   keyEquivalent:@"q"];
    
    [self.menu addItem:self.toggleMenuItem];
    [self.menu addItem:self.logMenuItem];
    [self.menu addItem:[NSMenuItem separatorItem]];
    [self.menu addItem:self.notificationsMenuItem];
    [self.menu addItem:[NSMenuItem separatorItem]];
    [self.menu addItem:quitMenuItem];
    
    self.statusItem.menu = self.menu;
    
    // Initialize state - monitoring and notifications enabled by default
    self.isMonitoring = YES;
    self.notificationsEnabled = YES;
    
    // Set up notification center delegate
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    // Start monitoring by default
    [self setupUSBNotifications];
}

- (void)toggleMonitoring {
    if (self.isMonitoring) {
        // Stop monitoring
        [self tearDownUSBNotifications];
        self.isMonitoring = NO;
        [self.toggleMenuItem setTitle:@"Start Monitoring"];
        [self.statusItem setTitle:@"USB"];
    } else {
        // Start monitoring
        [self setupUSBNotifications];
        self.isMonitoring = YES;
        [self.toggleMenuItem setTitle:@"Stop Monitoring"];
        [self.statusItem setTitle:@"USB*"];
    }
}

- (void)setupUSBNotifications {
    // Set up notification port
    self.notificationPort = IONotificationPortCreate(kIOMainPortDefault);
    CFRunLoopSourceRef runLoopSource = IONotificationPortGetRunLoopSource(self.notificationPort);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    
    // Set up matching dictionary for USB devices
    CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    
    // Register for device added notifications
    kern_return_t kr = IOServiceAddMatchingNotification(self.notificationPort,
                                                      kIOMatchedNotification,
                                                      matchingDict,
                                                      DeviceAdded,
                                                      (__bridge void *)(self),
                                                      &_addedIterator);
    if (kr != KERN_SUCCESS) {
        NSLog(@"Failed to register device added notification");
        return;
    }
    
    // Call the callback function to arm the notification
    [self deviceAdded:self.addedIterator];
    
    // Create a new matching dictionary for removal (since the previous one was consumed)
    matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    
    // Register for device removed notifications
    kr = IOServiceAddMatchingNotification(self.notificationPort,
                                        kIOTerminatedNotification,
                                        matchingDict,
                                        DeviceRemoved,
                                        (__bridge void *)(self),
                                        &_removedIterator);
    if (kr != KERN_SUCCESS) {
        NSLog(@"Failed to register device removed notification");
        return;
    }
    
    // Call the callback function to arm the notification
    [self deviceRemoved:self.removedIterator];
    
    [self addLogEntry:@"Monitoring started" isConnected:YES];
}

- (void)tearDownUSBNotifications {
    if (self.notificationPort) {
        IONotificationPortDestroy(self.notificationPort);
        self.notificationPort = NULL;
    }
    
    if (self.addedIterator) {
        IOObjectRelease(self.addedIterator);
        self.addedIterator = 0;
    }
    
    if (self.removedIterator) {
        IOObjectRelease(self.removedIterator);
        self.removedIterator = 0;
    }
    
    [self addLogEntry:@"Monitoring stopped" isConnected:NO];
}

- (void)deviceAdded:(io_iterator_t)iterator {
    io_service_t device;
    while ((device = IOIteratorNext(iterator))) {
        // Get device properties
        CFMutableDictionaryRef propertiesDict = NULL;
        kern_return_t kr = IORegistryEntryCreateCFProperties(device, &propertiesDict, kCFAllocatorDefault, 0);
        
        if (kr == KERN_SUCCESS && propertiesDict != NULL) {
            // Extract device information
            CFStringRef productName = CFDictionaryGetValue(propertiesDict, CFSTR("USB Product Name"));
            CFStringRef vendorName = CFDictionaryGetValue(propertiesDict, CFSTR("USB Vendor Name"));
            CFNumberRef vendorIDRef = CFDictionaryGetValue(propertiesDict, CFSTR("idVendor"));
            CFNumberRef productIDRef = CFDictionaryGetValue(propertiesDict, CFSTR("idProduct"));
            
            // Set default values if not available
            if (productName == NULL) {
                productName = CFSTR("Unknown Device");
            }
            if (vendorName == NULL) {
                vendorName = CFSTR("Unknown Vendor");
            }
            
            // Get values
            uint16_t vendorID = 0;
            uint16_t productID = 0;
            
            if (vendorIDRef) {
                CFNumberGetValue(vendorIDRef, kCFNumberSInt16Type, &vendorID);
            }
            if (productIDRef) {
                CFNumberGetValue(productIDRef, kCFNumberSInt16Type, &productID);
            }
            
            // Format device info with the new simplified format
            NSString *deviceInfo = [NSString stringWithFormat:
                @"%@ (%@) [VID: 0x%04X PID: 0x%04X]",
                (__bridge NSString *)productName,
                (__bridge NSString *)vendorName,
                vendorID,
                productID];
            
            NSString *logMessage = [NSString stringWithFormat:@"Connected: %@", deviceInfo];
            [self addLogEntry:logMessage isConnected:YES];
            
            // Show notification if enabled with new format
            if (self.notificationsEnabled) {
                [self showNotification:@"USB Device Connected" message:deviceInfo];
            }
            
            CFRelease(propertiesDict);
        }
        
        IOObjectRelease(device);
    }
}

- (void)deviceRemoved:(io_iterator_t)iterator {
    io_service_t device;
    while ((device = IOIteratorNext(iterator))) {
        // Get device properties
        CFMutableDictionaryRef propertiesDict = NULL;
        kern_return_t kr = IORegistryEntryCreateCFProperties(device, &propertiesDict, kCFAllocatorDefault, 0);
        
        if (kr == KERN_SUCCESS && propertiesDict != NULL) {
            // Extract device information
            CFStringRef productName = CFDictionaryGetValue(propertiesDict, CFSTR("USB Product Name"));
            CFStringRef vendorName = CFDictionaryGetValue(propertiesDict, CFSTR("USB Vendor Name"));
            CFNumberRef vendorIDRef = CFDictionaryGetValue(propertiesDict, CFSTR("idVendor"));
            CFNumberRef productIDRef = CFDictionaryGetValue(propertiesDict, CFSTR("idProduct"));
            
            // Set default values if not available
            if (productName == NULL) {
                productName = CFSTR("Unknown Device");
            }
            if (vendorName == NULL) {
                vendorName = CFSTR("Unknown Vendor");
            }
            
            // Get values
            uint16_t vendorID = 0;
            uint16_t productID = 0;
            
            if (vendorIDRef) {
                CFNumberGetValue(vendorIDRef, kCFNumberSInt16Type, &vendorID);
            }
            if (productIDRef) {
                CFNumberGetValue(productIDRef, kCFNumberSInt16Type, &productID);
            }
            
            // Format device info with the new simplified format
            NSString *deviceInfo = [NSString stringWithFormat:
                @"%@ (%@) [VID: 0x%04X PID: 0x%04X]",
                (__bridge NSString *)productName,
                (__bridge NSString *)vendorName,
                vendorID,
                productID];
            
            NSString *logMessage = [NSString stringWithFormat:@"Disconnected: %@", deviceInfo];
            [self addLogEntry:logMessage isConnected:NO];
            
            // Show notification if enabled with new format
            if (self.notificationsEnabled) {
                [self showNotification:@"USB Device Disconnected" message:deviceInfo];
            }
            
            CFRelease(propertiesDict);
        }
        
        IOObjectRelease(device);
    }
}

- (void)addLogEntry:(NSString *)entry isConnected:(BOOL)isConnected {
    // Get current date and time
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    
    // Create full log entry with timestamp
    NSString *fullEntry = [NSString stringWithFormat:@"[%@] %@", dateString, entry];
    
    // Add to log entries array
    [self.logEntries addObject:@{
        @"text": fullEntry,
        @"isConnected": @(isConnected)
    }];
    
    // Update log window if it's open
    if (self.logWindow && [self.logWindow isVisible]) {
        [self updateLogWindowContent];
    }
    
    // Log to console as well
    NSLog(@"%@", fullEntry);
}

- (void)showLog {
    // Create log window if it doesn't exist or was closed
    if (!self.logWindow || ![self.logWindow isVisible]) {
        NSRect frame = NSMakeRect(0, 0, 800, 400);
        self.logWindow = [[NSWindow alloc] initWithContentRect:frame
                                                     styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                                                       backing:NSBackingStoreBuffered
                                                         defer:NO];
        [self.logWindow setTitle:@"USB Monitor Log"];
        [self.logWindow center];
        
        // Create scroll view
        NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:[[self.logWindow contentView] bounds]];
        [scrollView setBorderType:NSNoBorder];
        [scrollView setHasVerticalScroller:YES];
        [scrollView setHasHorizontalScroller:NO];
        [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        
        // Create text view
        self.logTextView = [[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]];
        [self.logTextView setMinSize:NSMakeSize(0.0, 0.0)];
        [self.logTextView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
        [self.logTextView setVerticallyResizable:YES];
        [self.logTextView setHorizontallyResizable:NO];
        [self.logTextView setAutoresizingMask:NSViewWidthSizable];
        [self.logTextView setEditable:NO];
        [self.logTextView setRichText:YES];
        
        // Set background color to black
        [self.logTextView setBackgroundColor:[NSColor blackColor]];
        
        // Set up scroll view with text view
        [scrollView setDocumentView:self.logTextView];
        [[self.logWindow contentView] addSubview:scrollView];
    }
    
    // Update log content
    [self updateLogWindowContent];
    
    // Show the window and bring it to front
    [self.logWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)updateLogWindowContent {
    // Clear existing content
    [self.logTextView setString:@""];
    
    // Setup attributes for log entries
    NSMutableAttributedString *logContent = [[NSMutableAttributedString alloc] init];
    NSDictionary *normalAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    NSDictionary *connectedAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor colorWithRed:0 green:0.6 blue:0 alpha:1]
    };
    NSDictionary *disconnectedAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor colorWithRed:0.8 green:0 blue:0 alpha:1]
    };
    
    // Add each log entry with appropriate styling
    for (NSDictionary *entry in self.logEntries) {
        NSString *text = entry[@"text"];
        BOOL isConnected = [entry[@"isConnected"] boolValue];
        
        NSDictionary *attrs = normalAttrs;
        if ([text containsString:@"Connected:"]) {
            attrs = connectedAttrs;
        } else if ([text containsString:@"Disconnected:"]) {
            attrs = disconnectedAttrs;
        }
        
        NSAttributedString *attrLine = [[NSAttributedString alloc] 
                                      initWithString:text 
                                      attributes:attrs];
        [logContent appendAttributedString:attrLine];
        [logContent appendAttributedString:[[NSAttributedString alloc] 
                                          initWithString:@"\n" 
                                          attributes:normalAttrs]];
    }
    
    // Set the content
    [self.logTextView.textStorage setAttributedString:logContent];
    
    // Scroll to end
    [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.string.length, 0)];
}

- (void)toggleNotifications {
    self.notificationsEnabled = !self.notificationsEnabled;
    
    if (self.notificationsEnabled) {
        [self.notificationsMenuItem setTitle:@"Disable Notifications"];
        [self addLogEntry:@"Notifications enabled" isConnected:YES];
    } else {
        [self.notificationsMenuItem setTitle:@"Enable Notifications"];
        [self addLogEntry:@"Notifications disabled" isConnected:NO];
    }
}

- (void)showNotification:(NSString *)title message:(NSString *)message {
    @try {
        // Create a new NSUserNotification
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = title;
        notification.informativeText = message;
        notification.soundName = NSUserNotificationDefaultSoundName;
        
        // Deliver the notification
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        
        NSLog(@"Native notification sent successfully");
    } @catch (NSException *exception) {
        NSLog(@"Failed to show notification: %@", exception);
        [self addLogEntry:[NSString stringWithFormat:@"Failed to show notification: %@", exception.reason] isConnected:NO];
    }
}

// NSUserNotificationCenter delegate method to ensure notifications are shown even when app is active
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Create application programmatically
        [NSApplication sharedApplication];
        
        // Add application menu
        id menubar = [[NSMenu alloc] init];
        id appMenuItem = [[NSMenuItem alloc] init];
        [menubar addItem:appMenuItem];
        [NSApp setMainMenu:menubar];
        
        id appMenu = [[NSMenu alloc] init];
        id quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit" 
                                                    action:@selector(terminate:) 
                                             keyEquivalent:@"q"];
        [appMenu addItem:quitMenuItem];
        [appMenuItem setSubmenu:appMenu];
        
        // Create and set delegate
        USBMonitorAppDelegate *delegate = [[USBMonitorAppDelegate alloc] init];
        [NSApp setDelegate:delegate];
        
        // Activate and run
        [NSApp activateIgnoringOtherApps:YES];
        [NSApp run];
    }
    return 0;
}
