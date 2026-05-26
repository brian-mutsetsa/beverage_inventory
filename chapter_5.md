# Chapter 5: System Implementation and Testing

## 5.1 Introduction
This chapter discusses the implementation of the Aura - Intelligent Beverage Inventory application. It details the development tools used, the architecture of the main and initialization modules, the implementation of management features, and the predictive models utilized in the project. Note that since cloud integration is planned for future phases, all functionalities described here are handled locally on the device.

## 5.2 Tools Used
The development of the Aura application relied on an array of modern frameworks and libraries to deliver a robust and intelligent experience:
- **Flutter & Dart**: The core framework and programming language used for cross-platform mobile app development.
- **SQLite (sqflite)**: Utilized as the primary local database for offline support, fast data retrieval, and full data persistence without relying on a cloud backend.
- **ml_algo & ml_dataframe**: Crucial machine learning libraries in Dart used to build and train the Linear Regression models for demand forecasting entirely on-device.
- **pdf & printing**: Implemented for generating, rendering, and exporting comprehensive financial and inventory PDF reports directly from the application.
- **google_fonts & lottie**: Integrated to enhance the user interface with modern typography (Poppins) and animated assets.
- **flutter_local_notifications**: Used to dispatch smart system alerts, such as low-stock warnings.

## 5.3 The Main Module
The main application module (`AuraApp`) establishes the foundational aesthetic and routing configurations through the `MaterialApp` widget. 
It defines the global theme, establishing a minimalist color scheme prioritizing sleek blacks and whites, custom typography via `GoogleFonts.poppins`, and rounded UI elements (such as pill-shaped buttons and cards with subtle shadows). It serves as the root of the widget tree, disabling the debug banner, and seamlessly routing the user to the initial `SplashScreen`.

## 5.4 The Initialization Module
The initialization sequence, located within the `main()` function in `main.dart`, is responsible for asynchronously bootstrapping essential services before the UI is fully rendered. The process involves:
1. **Flutter Binding**: Calling `WidgetsFlutterBinding.ensureInitialized()` to ensure native channels are ready.
2. **Database Initialization**: Instantiating `DatabaseHelper.instance.database` to ensure the local SQLite database is spun up and ready for offline data operations immediately upon launch.
3. **Notification Setup**: Initializing `NotificationService.instance` to prepare the local operating system to receive low-stock alerts and predictive reorder prompts.

*(Insert screenshot of `main.dart` initialization code here)*

## 5.5 Techniques Used
### 5.5.1 AI-Driven Demand Forecasting
To provide intelligent insights, we utilized a `LinearRegressor` from the `ml_algo` package to predict the next 7 days of product demand. 
- The system aggregates the last 30 days of sales data for a specific product from the SQLite database.
- It maps the dates continuously and transforms them into numerical feature matrices using `ml_dataframe`.
- The model uses gradient descent to output a continuous value prediction. The predicted volume is then aggregated, and a 20% safety buffer is automatically appended to compute a smart "Recommended Order".

### 5.5.2 Role-Based Access Control (RBAC)
The application dynamically restricts UI components and database operations based on the user's role. For instance, within the inventory screens, deletion capabilities are strictly locked behind an `_isManager` boolean flag. This technique ensures that regular staff can only read, add, or amend stock, preventing unauthorized data manipulation.

*(Insert screenshot of Code snippet demonstrating RBAC or ML Model training here)*

## 5.6 Manage Module
The Manage Module (primarily represented by the `InventoryScreen` and `UserManagementScreen`) is designed to handle CRUD (Create, Read, Update, Delete) operations with high efficiency and visual clarity.
Key functionalities include:
- **View & Filter Inventory**: A real-time search interface that dynamically filters the product grid by name or category.
- **Add / Edit Items**: Dedicated forms to input product details (quantity, cost price, selling price, and supplier metrics). Visual chips and color-coded tags instantly denote if an item is "OK", "Low", or "Empty" (e.g., Green, Yellow, Red).
- **Security & Logging**: Deletion requests prompt a confirmation dialog and verify managerial privileges before executing the SQL drop command. Furthermore, critical actions are recorded via an `AuditLog` object to ensure complete accountability on the device.

*(Insert screenshot of the Manage Module UI here)*

## 5.7 Prediction Test Set Results
The AI forecasting service gathers a 30-day historical dataset to train its regression model dynamically on the device.
When tested with sample aggregated sales data, the predictive system correctly processes the input dataframe and successfully outputs the following test set results for the UI:
- **Predicted Sales (7 Days)**: Projected demand based on recent velocity.
- **Recommended Order Quantity**: Dynamically calculated restock suggestions incorporating the model's output plus the safety buffer.
- **Risk Level**: Real-time evaluation identifying products at high risk of stockout ('HIGH' or 'LOW') based on the current quantity versus the 7-day predicted need.

*(Due to current testing constraints without cloud integration, actual validation sets and accuracy matrices are generated locally. Below are the representation screenshots of the prediction test results from the device interface.)*

*(Insert screenshot of Prediction Test Results here)*
