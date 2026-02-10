# 🍹 Beverage Inventory Management System

A modern, user-friendly Flutter application for managing beverage inventory, tracking sales, and generating comprehensive reports. Perfect for small to medium-sized beverage businesses and retailers.

---

## 📋 Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Running the Application](#running-the-application)
- [Project Structure](#project-structure)
- [Key Features in Detail](#key-features-in-detail)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

---

## ✨ Features

✅ **User Authentication** - Secure login system with user management  
✅ **Product Management** - Add, edit, and manage beverage products with categories  
✅ **Inventory Tracking** - Real-time inventory monitoring with low-stock alerts  
✅ **Sales Management** - Record and track beverage sales transactions  
✅ **Dashboard** - Visual overview of key metrics and business statistics  
✅ **Reporting** - Generate detailed PDF reports for analysis  
✅ **Multi-Platform** - Run on Android, iOS, Windows, macOS, Linux, and Web  
✅ **Database Management** - Secure local SQLite database  
✅ **Audit Logging** - Track all system changes and user activities  

---

## 📦 Prerequisites

Before you begin, ensure you have the following installed on your computer:

### Required Software:

1. **Flutter SDK** (version 3.10.7 or higher)
   - Download from: https://flutter.dev/docs/get-started/install
   - Follow the installation guide for your operating system (Windows/Mac/Linux)

2. **Dart SDK** (comes with Flutter)
   - Automatically included with Flutter

3. **Git** (optional, but recommended)
   - Download from: https://git-scm.com/

### For Platform-Specific Development:

- **Android**: Android Studio or Android SDK
- **iOS**: Xcode (Mac only)
- **Windows**: Visual Studio or Build Tools
- **Web**: Chrome or any modern browser

### Verify Installation:

Open Command Prompt/Terminal and run:

```bash
flutter --version
dart --version
```

---

## 🚀 Installation

### Step 1: Clone or Download the Project

**Option A: Using Git**
```bash
git clone <repository-url>
cd beverage_inventory
```

**Option B: Download ZIP File**
1. Click "Code" → "Download ZIP" on GitHub
2. Extract the ZIP file to your desired location
3. Open Command Prompt/Terminal and navigate to the folder

```bash
cd beverage_inventory
```

### Step 2: Get Flutter Dependencies

Run this command to download all required packages:

```bash
flutter pub get
```

This may take a few minutes on first run.

### Step 3: Verify Setup

Check if everything is properly configured:

```bash
flutter doctor
```

This command will show any missing dependencies. Address any warnings related to your target platform (Android, iOS, etc.).

---

## ▶️ Running the Application

### On Android (Requires Android emulator or physical device):

```bash
flutter run
```

Or to specify a particular device:

```bash
flutter run -d <device-id>
```

### On Windows:

```bash
flutter run -d windows
```

### On Web (Browser):

```bash
flutter run -d chrome
```

### On iOS (Mac only):

```bash
flutter run -d ios
```

### To List Available Devices:

```bash
flutter devices
```

---

## 📁 Project Structure

Navigate through the project using this structure:

```
beverage_inventory/
├── lib/                          # Main application code
│   ├── main.dart                 # App entry point
│   ├── database/
│   │   └── database_helper.dart  # Database operations & SQL queries
│   ├── models/                   # Data models
│   │   ├── product.dart          # Product data structure
│   │   ├── sale.dart             # Sale transaction structure
│   │   ├── user.dart             # User account structure
│   │   └── audit_log.dart        # Audit trail tracking
│   ├── screens/                  # Application screens (UI pages)
│   │   ├── login_screen.dart     # Login & authentication
│   │   ├── dashboard_screen.dart # Main dashboard view
│   │   ├── home_screen.dart      # Home page
│   │   ├── inventory_screen.dart # Inventory management & products
│   │   ├── sales_screen.dart     # Sales tracking & transactions
│   │   ├── reports_screen.dart   # Report generation & analytics
│   │   ├── add_product_screen.dart
│   │   ├── user_management_screen.dart  # User admin panel
│   │   └── setup_screen.dart     # Initial setup wizard
│   ├── widgets/                  # Reusable UI components
│   ├── helpers/
│   │   ├── database_helper.dart  # Database initialization
│   │   ├── pdf_report_generator.dart  # PDF report creation
│   │   └── demo_data_helper.dart # Sample data for testing
│   └── assets/                   # Images, fonts, and resources
│
├── pubspec.yaml                  # Project dependencies & configuration
├── analysis_options.yaml         # Code quality settings
├── README.md                     # This file
│
├── android/                      # Android-specific files
├── ios/                          # iOS-specific files
├── windows/                      # Windows-specific files
├── macos/                        # macOS-specific files
├── linux/                        # Linux-specific files
├── web/                          # Web-specific files
└── test/                         # Test files
```

### Quick Navigation Links:

- 🔒 **Authentication**: [lib/screens/login_screen.dart](lib/screens/login_screen.dart)
- 📦 **Inventory Management**: [lib/screens/inventory_screen.dart](lib/screens/inventory_screen.dart)
- 💰 **Sales Tracking**: [lib/screens/sales_screen.dart](lib/screens/sales_screen.dart)
- 📊 **Reports & Analytics**: [lib/screens/reports_screen.dart](lib/screens/reports_screen.dart)
- 👥 **User Management**: [lib/screens/user_management_screen.dart](lib/screens/user_management_screen.dart)
- 🗄️ **Database Logic**: [lib/database/database_helper.dart](lib/database/database_helper.dart)
- 📄 **PDF Reports**: [lib/helpers/pdf_report_generator.dart](lib/helpers/pdf_report_generator.dart)

---

## 🎯 Key Features in Detail

### 1. **User Authentication**
- Secure login with username and password
- User roles and permissions
- See [lib/screens/login_screen.dart](lib/screens/login_screen.dart)

### 2. **Inventory Management** 
- Add new beverage products with categories
- Track quantity, cost price, and selling price
- Monitor supplier information and barcodes
- Set low-stock alerts with minimum quantity thresholds
- See [lib/screens/inventory_screen.dart](lib/screens/inventory_screen.dart)

### 3. **Sales Tracking**
- Record sales transactions with date and quantity
- Calculate profits automatically
- Track sales history
- See [lib/screens/sales_screen.dart](lib/screens/sales_screen.dart)

### 4. **Dashboard**
- Overview of total products, sales, and revenue
- Quick access to key metrics
- See [lib/screens/dashboard_screen.dart](lib/screens/dashboard_screen.dart)

### 5. **Reporting**
- Generate PDF reports for analysis
- Export sales and inventory data
- See [lib/helpers/pdf_report_generator.dart](lib/helpers/pdf_report_generator.dart)

### 6. **Database**
- Local SQLite database for secure data storage
- Automatic schema management
- See [lib/database/database_helper.dart](lib/database/database_helper.dart)

---

## 🔧 Troubleshooting

### Issue: "Flutter command not found"
**Solution**: Ensure Flutter is added to your system PATH. 
- Windows: Restart Command Prompt after installing Flutter
- Mac/Linux: Run `export PATH="$PATH:`pwd`/flutter/bin"` 

### Issue: "Android SDK not found"
**Solution**: 
```bash
flutter config --android-sdk <path-to-android-sdk>
flutter doctor --android-licenses
```

### Issue: "No connected devices"
**Solution**:
- For Android emulator: Open Android Studio → AVD Manager → Start an emulator
- For physical device: Enable Developer Mode and USB Debugging, then connect via USB
- Run `flutter devices` to verify

### Issue: Dependency errors
**Solution**:
```bash
flutter clean
flutter pub get
flutter run
```

### Issue: Build fails on first run
**Solution**: Clear Flutter cache and rebuild:
```bash
flutter clean
flutter pub get
flutter run
```

---

## 💡 Basic Usage

1. **First Time Setup**: 
   - The app will create a demo admin account on first launch
   - Default login: Check setup screen for credentials
   - Change password from user management panel

2. **Adding Products**:
   - Navigate to Inventory screen
   - Click "Add Product"
   - Fill in product details (name, category, price, quantity)

3. **Recording Sales**:
   - Go to Sales screen
   - Click "New Sale"
   - Select product and quantity
   - Inventory updates automatically

4. **Generating Reports**:
   - Open Reports screen
   - Choose report type (Sales, Inventory, etc.)
   - Download as PDF

---

## 📞 Support

If you encounter issues or have questions:

1. **Check the Troubleshooting section** above
2. **Read Flutter documentation**: https://flutter.dev/docs
3. **Contact the development team** for assistance
4. **Check database**: Data is stored locally in the app's database directory

---

## 📝 License & Notes

- This project uses Flutter and Dart
- Database: SQLite
- PDF Generation: pdf package
- Printing: printing package

For more information about Flutter, visit: https://flutter.dev
