# USB Monitor Menu Bar

A lightweight macOS menu bar application that monitors USB device connections and disconnections in real-time.

![WhatsApp Image 2025-05-03 at 15 14 35](https://github.com/user-attachments/assets/5b2ce41f-ccd8-4bcd-b1ef-f8b9a047ecc9)


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
