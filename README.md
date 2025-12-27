# AGiXT Mobile

![AGiXT_New](https://github.com/user-attachments/assets/14a5c1ae-6af8-4de8-a82e-f24ea52da23f)

<p align="center">
  <b>AI-Powered Assistant for Even Realities G1 Smart Glasses</b>
</p>

## 📱 Overview

AGiXT Mobile is a cutting-edge Flutter application designed as the perfect companion for Even Realities G1 smart glasses. This app creates a seamless bridge between AI-powered intelligence and wearable technology, empowering users to interact with their digital world through natural voice commands, view real-time information on their glasses display, and manage their digital life effortlessly.

## ✨ Key Features

### 🔄 Bluetooth Connectivity
- **Instant Pairing**: One-touch connection with Even Realities G1 smart glasses
- **Smart Reconnection**: Automatically reconnects to previously paired devices
- **Dual-Glass Communication**: Real-time bi-directional data exchange with both left and right glasses
- **Stable Connection**: Maintains reliable connectivity even in challenging environments

### 🎤 Voice Recognition & AI Assistant
- **Multi-Language Support**: On-device speech recognition for 14+ languages
- **Real-Time Transcription**: Instant display of speech-to-text on glasses display
- **AI-Powered Responses**: Natural language processing to understand and respond to user queries
- **Context-Aware Assistance**: Remembers conversation history for more relevant interactions

### 📅 Calendar & Smart Planning
- **Cross-Platform Integration**: Syncs with Google Calendar, Apple Calendar and other providers
- **AI-Enhanced Scheduling**: Intelligent event management and conflict resolution
- **Heads-Up Reminders**: Timely notifications displayed directly on glasses
- **Voice-Controlled Management**: Create, modify, or cancel events using just your voice

### 📱 Smart Notifications
- **Priority Filtering**: Customizable notification importance levels
- **Contextual Display**: Shows notifications when appropriate based on user activity
- **Quick Actions**: Respond to messages directly from glasses interface
- **Focus Modes**: Automatically filter notifications based on current activity or meeting status

### 🌐 Real-Time Translation
- **Conversation Mode**: Translate spoken language in real-time during conversations
- **Text Recognition**: Translate written text viewed through the glasses camera
- **Offline Support**: Core languages available without internet connection
- **14+ Languages**: Comprehensive support including English, Chinese, Japanese, Russian, Korean, Spanish, French, German, Dutch, Norwegian, Danish, Swedish, Finnish, and Italian

### 📊 Customizable Dashboard
- **Modular Widgets**: Arrange information cards based on personal preference
- **At-a-Glance Info**: Time, weather, calendar, tasks, and more
- **Voice Note System**: Capture and display thoughts and reminders
- **Task Tracking**: Manage to-do lists directly on your glasses

### 🔋 Battery Optimization
- **Power-Saving Modes**: Intelligent adjustment based on usage patterns
- **Battery Monitoring**: Real-time status of both mobile device and glasses
- **Usage Analytics**: Insights into battery consumption by feature

## 🌍 Supported Languages

AGiXT supports voice recognition, command processing, and translation in:

| Language | Voice Recognition | Translation | Command Support |
|----------|:----------------:|:-----------:|:---------------:|
| English (US) | ✅ | ✅ | ✅ |
| Chinese | ✅ | ✅ | ✅ |
| Japanese | ✅ | ✅ | ✅ |
| Russian | ✅ | ✅ | ✅ |
| Korean | ✅ | ✅ | ✅ |
| Spanish | ✅ | ✅ | ✅ |
| French | ✅ | ✅ | ✅ |
| German | ✅ | ✅ | ✅ |
| Dutch | ✅ | ✅ | ✅ |
| Norwegian | ✅ | ✅ | ✅ |
| Danish | ✅ | ✅ | ✅ |
| Swedish | ✅ | ✅ | ✅ |
| Finnish | ✅ | ✅ | ✅ |
| Italian | ✅ | ✅ | ✅ |

## 🚀 Getting Started

### System Requirements
- **Flutter SDK**: ^3.5.4
- **iOS**: 13.0 or newer
- **Android**: API level 21+ (Android 5.0+)
- **Hardware**: Even Realities G1 smart glasses for full functionality
- **Bluetooth**: 5.0+ recommended for optimal performance

### Installation

1. **Clone the repository**:
```bash
git clone https://github.com/AGiXT/mobile.git
cd mobile
```

2. **Install dependencies**:
```bash
flutter pub get
```

3. **Run the application**:
```bash
flutter run
```

### Solana Wallet Login (dApp Store Ready)

AGiXT Mobile now supports authenticating with Solana wallets so it can be listed in the Seeker dApp Store alongside the traditional email/MFA flow.

1. Install a supported Solana wallet on the device (Phantom, Solflare, or the built-in Solana Mobile Wallet on Seeker devices).
2. Launch the wallet at least once so it registers its deep links.
3. Open AGiXT Mobile and choose **Wallet Login** on the sign-in screen.
4. Pick your preferred wallet provider when prompted and approve the connection request in the wallet app.
5. When asked, review and sign the nonce message; AGiXT automatically verifies the signature and stores the issued session token.

If multiple wallets are installed, AGiXT filters the list to providers compatible with the Solana Mobile Wallet Adapter—including the native Solana Mobile Wallet vault shipped with Seeker devices. You can switch back to email login at any time from the same screen.

### Connecting to Even Realities G1 Glasses

1. **Power on** your G1 smart glasses
2. **Open AGiXT Mobile** and navigate to the connection screen
3. **Enable Bluetooth** if not already active
4. **Scan for devices** and select your G1 glasses from the list
5. **Follow on-screen pairing instructions** to complete the setup
6. **Verify connection** by checking the status indicator in the app

## 💻 Development

### Project Structure
- `lib/`: Main source code
  - `main.dart`: Application entry point
  - `models/`: Data models for app state and business logic
  - `screens/`: UI screens and navigation
  - `services/`: Core services (Bluetooth, voice recognition, etc.)
  - `utils/`: Helper functions and utilities
  - `widgets/`: Reusable UI components
- `ios/`: iOS-specific native code (Swift)
- `android/`: Android-specific native code (Kotlin/Java)
- `assets/`: Static resources (images, icons, fonts, etc.)
- `test/`: Unit and integration tests

### Key Components

#### Bluetooth Connection Manager
Advanced connection handling for reliable communication with Even Realities G1 glasses, with automatic reconnection and error recovery strategies.

#### Multi-Language Speech Recognition
On-device speech processing with real-time feedback and minimal latency, optimized for the G1 glasses ecosystem.

#### Background Service Architecture
Maintains critical functionality even when the app is minimized, ensuring continuous glasses connectivity and timely notifications.

#### State Management
Reactive programming model that ensures UI consistency across app and glasses displays.

## 📖 Usage Examples

### Voice Commands

- **"Hey AGiXT, what's my schedule today?"** - View today's calendar events
- **"Take a note: pick up groceries after work"** - Create a new reminder
- **"Translate 'Where is the train station?' to Japanese"** - Get instant translations
- **"Show me the weather forecast"** - Display weather information
- **"Read my latest messages"** - Review recent notifications

### Gesture Controls

The app also supports the G1 glasses' gesture recognition for hands-free interaction:
- **Swipe right/left**: Navigate between dashboard cards
- **Double tap**: Select or activate current item
- **Swipe up/down**: Scroll through content

## 🔒 Privacy & Security

- **Local Processing**: Primary speech recognition performed on-device
- **Encrypted Communication**: Secure data transfer between app and glasses
- **Opt-in Cloud Features**: Advanced AI features available with transparent data usage
- **Privacy Controls**: Granular permissions and data sharing options
- **Regular Audits**: Continuous security assessment and improvements

## 📬 Contact & Support

- **GitHub Issues**: For bug reports and feature requests
- **Discord**: Join our community at [AGiXT Discord](https://discord.gg/AGiXT)
- **Documentation**: [AGiXT Docs](https://agixt.com/docs)
