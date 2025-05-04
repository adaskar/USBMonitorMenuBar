# USB Monitor Menu Bar

A lightweight macOS menu bar application that monitors USB device connections and disconnections in real-time.

![image](https://github.com/user-attachments/assets/4f428d2c-b435-4cb1-9ef2-5aedd147ee2d)


## Overview

USB Monitor Menu Bar sits quietly in your macOS menu bar and keeps track of all USB device activities on your system. It provides instant notifications when devices are connected or disconnected and maintains a detailed log of all USB events.

## Features

- **Real-time USB Monitoring**: Tracks all USB device connections and disconnections as they happen
- **Menu Bar Integration**: Stays out of your way in the macOS menu bar with minimal UI footprint
- **Detailed Event Log**: Records timestamps, device names, manufacturers, and hardware IDs
- **Desktop Notifications**: Provides instant alerts when USB devices are connected or disconnected
- **Configurable Settings**: Toggle monitoring and notifications on/off as needed
- **Visual Log Interface**: Color-coded log window for easy scanning (green for connections, red for disconnections)

## Build

- clang -o USBMonitorMenuBar USBMonitorMenuBar.m -framework Cocoa -framework IOKit

## Run

- ./USBMonitorMenuBar

## To Build and Package Your App:
You can build and package your app using the command line tools:

# Compile the code
```
clang -framework Cocoa -framework IOKit USBMonitorMenuBar.m -o USBMonitor
```

# Create the app structure
```
mkdir -p USBMonitor.app/Contents/{MacOS,Resources}
```

# Move the executable into place
```
mv USBMonitor USBMonitor.app/Contents/MacOS/
```

# Create an Info.plist
```
cat > USBMonitor.app/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>USBMonitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.adaskar.usbmonitor</string>
    <key>CFBundleName</key>
    <string>USBMonitor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
```
# Make the app executable
```
chmod +x USBMonitor.app/Contents/MacOS/USBMonitor
```

# Sign the app (optional but recommended)
```
codesign --force --sign - USBMonitor.app
```
