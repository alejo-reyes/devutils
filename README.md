# DevUtils

A collection of development utilities and shell scripts to streamline common tasks.

## Device Switcher

A powerful Bluetooth device switcher for macOS that allows you to easily switch Magic Keyboard and Magic Mouse between multiple devices (e.g., different laptops).

### Features

- 🎯 **Unified Interface**: Control both keyboard and mouse with a single command
- 🔄 **Smart Switching**: Handles pairing, unpairing, and connection automatically
- 🎨 **Color-coded Output**: Professional, clean interface with no emojis
- ⚡ **Quick Commands**: Short aliases for fast switching
- 🔍 **Device Discovery**: Finds devices in both paired and nearby lists
- 📊 **Status Checking**: Monitor connection status of your devices
- 🛠️ **Both Device Support**: Switch keyboard and mouse simultaneously

### Prerequisites

#### Install blueutil via Homebrew

The script requires `blueutil`, a command-line Bluetooth utility for macOS:

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install blueutil
brew install blueutil
```

#### Device Setup

1. **Rename your devices** in macOS System Settings > Bluetooth:
   - Magic Keyboard → `A.Reyes MagicKeyboard`
   - Magic Mouse → `A.Reyes MagicMouse`
   
   *Note: You can customize these names by editing the constants at the top of `device_switch.sh`*

### Installation

1. **Clone or download** this repository
2. **Make the script executable**:
   ```bash
   chmod +x shell_scripts/device_switch.sh
   ```
3. **Add alias to your shell** (already done if you followed the setup):
   ```bash
   echo "alias ds='$(pwd)/shell_scripts/device_switch.sh'" >> ~/.zshrc
   source ~/.zshrc
   ```

### Usage

#### Basic Commands

```bash
# Show help
ds

# Individual devices
ds keyboard claim      # Claim keyboard for this laptop
ds k c                 # Same (short form)
ds mouse release       # Release mouse to other devices
ds m r                 # Same (short form)

# Both devices
ds both claim          # Claim both devices
ds b c                 # Same (short form)
ds both status         # Check status of both devices
ds b s                 # Same (short form)
```

#### Device Types
- `keyboard` or `k` - Magic Keyboard
- `mouse` or `m` - Magic Mouse  
- `both` or `b` - Both devices

#### Actions
- `claim` or `c` - Claim device (pair & connect to this laptop)
- `release` or `r` - Release device (unpair so other laptop can use)
- `status` or `s` - Check current connection status

### Workflow Examples

#### Switching Between Laptops

**On Laptop A (releasing devices):**
```bash
ds b r    # Release both devices
```

**On Laptop B (claiming devices):**
```bash
ds b c    # Claim both devices
```

#### Individual Device Management

```bash
# Use keyboard on this laptop, but let other laptop use mouse
ds k c    # Claim keyboard
ds m r    # Release mouse

# Check what's connected
ds b s    # Status of both devices
```

### Technical Details

#### How It Works

1. **Device Discovery**: 
   - First searches paired devices
   - Falls back to Bluetooth inquiry for unpaired devices
   - Uses regex to extract MAC addresses and device names

2. **Smart Pairing**:
   - Keyboards use PIN "0000"
   - Mice typically pair without PIN
   - Handles pairing failures gracefully

3. **Connection Management**:
   - Checks current connection status
   - Only pairs if not already paired
   - Provides detailed feedback for each step

#### Configuration

Device names and PINs are configured at the top of `device_switch.sh`:

```bash
readonly KEYBOARD_NAME="A.Reyes MagicKeyboard"
readonly MOUSE_NAME="A.Reyes MagicMouse"
readonly KEYBOARD_PIN="0000"
readonly MOUSE_PIN=""  # Mice typically don't need PIN
```

### Color Coding

- **Blue**: Keyboard operations
- **Green**: Mouse operations & success messages
- **Magenta**: Both device operations
- **Yellow**: Warnings & search messages
- **Red**: Error messages
- **Gray**: Secondary information

### Troubleshooting

#### Common Issues

**Device not found:**
- Ensure device is turned on and in range
- Check that device name matches configuration
- Try putting device in pairing mode

**Pairing fails:**
- Make sure device is in pairing mode
- Check if device is already paired to another device
- Try releasing from other device first

**Connection fails:**
- Wait a few seconds and try again
- Check Bluetooth is enabled
- Restart Bluetooth service if needed

#### Debug Commands

```bash
# List all paired devices
blueutil --paired

# Check if specific device is connected
blueutil --is-connected <device-id>

# Manual pairing
blueutil --pair <device-id> 0000
```

### File Structure

```
devutils/
├── README.md                    # This file
├── package.json                 # Project configuration
└── shell_scripts/
    ├── device_switch.sh         # Main device switcher script
    ├── keyboard_switch.sh       # Original keyboard-only script
    ├── inject-simple.sh         # Other utility scripts
    ├── re_pair.sh
    └── keyboard_switch.sh
```

### Contributing

Feel free to submit issues and pull requests to improve the functionality or add support for additional device types.

### License

This project is open source and available under the MIT License.