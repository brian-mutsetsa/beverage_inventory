# Project Update & Clarifications

**Hey! I hope you're doing well. Here is some clarity on the project's current state and how we are addressing those specific objectives:**

## 1. Monitoring Customer Orders
The app currently has a very strong local foundation for tracking products, inventory, and sales natively on-device (as seen in the Sales and Inventory screens). To fully monitor customer orders in real-time, we are adding an "Orders" module that links directly to our upcoming cloud database. This will allow managers to oversee real-time order statuses (e.g., Pending, Processing, Completed) and track centralized sales as they come in from multiple terminals or staff members, directly from their dashboard.

## 2. Synchronizing Data with Cloud Storage
Since we are moving away from Firebase, our plan is to implement a robust custom REST API backend (like Node.js or Python) connected to a highly scalable, relational database like PostgreSQL or MySQL. An alternative we are exploring is Supabase, an excellent open-source equivalent.

We have already built the app with an `sqflite` local database. The strategy is to use background synchronization: the app continues to save data locally first (which guarantees perfect offline functionality and speed), and then securely pushes and pulls updates from the remote cloud database in the background whenever an internet connection is detected. 

## 3. Regarding Authentication
Yes, it is absolutely possible and already structured into the app! Right now, we have the local authentication flow functioning (Manager Auth, PIN Setup, & Employee Login screens). Once we finalize the cloud backend, we will upgrade this to use secure, industry-standard token-based authentication (such as JWT). This will manage user sessions globally, ensure data privacy, and enforce Role-Based Access Control (RBAC) securely across all devices.

## 4. How the AI and Linear Regression Features Perform
The application uses **Linear Regression** alongside several mathematical algorithms to provide actionable, accurate insights directly on the device. Here is a breakdown of how the AI features work and how prediction scores are calculated:

*   **Demand Forecasting (Next 7 Days):** 
    The AI uses the last **30 days of continuous historical sales data** for each specific product to train a machine learning model using Gradient Descent optimization. The model identifies the exact trajectory of your daily sales over time. It then calculates a "Prediction Score" estimating exactly how many units you will sell over the next 7 days. To protect against unexpected spikes in demand, the system automatically applies a **20% safety margin** to this prediction to generate your final "Recommended Order" amount. This ensures you never run out of stock during busy periods.

*   **Smart Reorder Alerts:** 
    The AI calculates the daily burn rate (average items sold per day) for every item over the past 30 days and cross-references it with your current physical stock. If the system detects that an item will run out in **5 days or less**, it triggers an automated alert suggesting a customized 14-day supply restock.

*   **Profit Optimization Insights:** 
    The feature continuously evaluates both sales volume and profit margins (selling price vs. cost price) in real-time. It actively highlights which items bring in the highest profit margins, which move the fastest, and which are underperforming, giving managers clear data on what to promote and what to order less of.

## 5. Python's Role vs. Dart's Execution
While the Dart packages (`ml_algo`, `ml_dataframe`) run these sophisticated, lightweight models locally—saving your business mobile data and ensuring speed—**Python** was essential for the initial research phase. We used Python (Pandas, Scikit-learn) historically to clean data, run complex simulations, and validate that *Linear Regression* was the absolute best mathematical fit for your inventory patterns before we hardcoded it into the app.

## 6. Linear Regression Test Pictures
I am finalizing the system documentation right now (specifically Chapter 5), which includes the prediction test set results, accuracy metrics, and the screenshots of the Linear Regression tests. I will be sharing that finalized document with you shortly so you can see the visual proof of how the prediction engine performs!

---
*Let me know if this clears things up!*
