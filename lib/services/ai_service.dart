import 'package:ml_algo/ml_algo.dart';
import 'package:ml_dataframe/ml_dataframe.dart';
import '../database/database_helper.dart';
import '../models/product.dart';

class AIService {
  static final AIService instance = AIService._init();
  AIService._init();

  final DatabaseHelper _db = DatabaseHelper.instance;

  // 1. Demand Forecasting (Next 7 Days)
  Future<Map<String, dynamic>> getDemandForecast(Product product) async {
    final db = await _db.database;
    final companyId = _db.currentCompanyId;
    
    // Get sales for the last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    
    // Aggregate sales by day
    final result = await db.rawQuery('''
      SELECT 
        DATE(saleDate) as date,
        SUM(quantitySold) as totalSold
      FROM sales
      WHERE companyId = ? AND productId = ? AND saleDate >= ?
      GROUP BY DATE(saleDate)
      ORDER BY date ASC
    ''', [companyId, product.id, thirtyDaysAgo]);

    if (result.length < 7) {
      return {
        'hasEnoughData': false,
        'message': 'Need at least 7 days of sales data for AI forecasting.',
      };
    }

    // Prepare features and targets for Linear Regression
    List<Iterable<num>> features = [];
    List<num> targets = [];
    
    // Map dates to continuous indices (1 to 30) based on actual dates
    DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
    for (var row in result) {
      DateTime rowDate = DateTime.parse(row['date'] as String);
      int dayIndex = rowDate.difference(startDate).inDays;
      features.add([dayIndex]);
      targets.add((row['totalSold'] as num).toDouble());
    }

    try {
      final data = DataFrame([
        ['day', 'sales'],
        for (int i = 0; i < features.length; i++) [features[i].first, targets[i]]
      ]);

      final model = LinearRegressor(
        data,
        'sales',
        optimizerType: LinearOptimizerType.gradient,
        iterationsLimit: 100,
      );

      // Predict next 7 days
      double future7DaysTotal = 0;
      int nextDayIndex = 31;
      
      for (int i = 0; i < 7; i++) {
        final predictionData = DataFrame([
          ['day'],
          [nextDayIndex + i]
        ]);
        final prediction = model.predict(predictionData);
        double val = prediction.rows.first.first.toDouble();
        if (val < 0) val = 0;
        future7DaysTotal += val;
      }

      int recommendedOrder = future7DaysTotal.round() - product.quantity;
      if (recommendedOrder < 0) recommendedOrder = 0;
      
      // Add 20% safety buffer to order
      recommendedOrder = (recommendedOrder * 1.2).round();

      return {
        'hasEnoughData': true,
        'predictedSales7Days': future7DaysTotal.round(),
        'recommendedOrder': recommendedOrder,
        'riskLevel': (product.quantity < future7DaysTotal) ? 'HIGH' : 'LOW',
      };
    } catch (e) {
      return {
        'hasEnoughData': false,
        'message': 'Error training model: $e',
      };
    }
  }

  // 2. Sales Pattern Recognition (Insights)
  Future<Map<String, dynamic>> getSalesInsights() async {
    final db = await _db.database;
    final companyId = _db.currentCompanyId;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    final result = await db.rawQuery('''
      SELECT 
        STRFTIME('%w', saleDate) as dayOfWeek,
        SUM(totalAmount) as totalRevenue,
        COUNT(*) as transactionCount
      FROM sales
      WHERE companyId = ? AND saleDate >= ?
      GROUP BY dayOfWeek
    ''', [companyId, thirtyDaysAgo]);

    if (result.isEmpty) {
      return {'hasData': false};
    }

    final daysMap = {
      '0': 'Sunday', '1': 'Monday', '2': 'Tuesday', '3': 'Wednesday', 
      '4': 'Thursday', '5': 'Friday', '6': 'Saturday'
    };

    String bestDay = '';
    double maxRev = 0;
    String worstDay = '';
    double minRev = double.infinity;
    double totalRev = 0;

    for (var row in result) {
      double rev = (row['totalRevenue'] as num).toDouble();
      totalRev += rev;
      if (rev > maxRev) { maxRev = rev; bestDay = daysMap[row['dayOfWeek']] ?? ''; }
      if (rev < minRev) { minRev = rev; worstDay = daysMap[row['dayOfWeek']] ?? ''; }
    }

    double avgPerDay = totalRev / result.length;
    double bestDaySpike = ((maxRev - avgPerDay) / avgPerDay) * 100;

    return {
      'hasData': true,
      'bestDay': bestDay,
      'bestDaySpike': bestDaySpike.round(),
      'worstDay': worstDay,
    };
  }

  // 3. Smart Reorder Alerts
  Future<List<Map<String, dynamic>>> getReorderAlerts() async {
    final db = await _db.database;
    final companyId = _db.currentCompanyId;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    // Get daily average sales for each product over the last 30 days
    final result = await db.rawQuery('''
      SELECT 
        p.id, p.name, p.quantity,
        SUM(s.quantitySold) / 30.0 as dailyAvg
      FROM products p
      LEFT JOIN sales s ON p.id = s.productId AND s.saleDate >= ?
      WHERE p.companyId = ?
      GROUP BY p.id
      HAVING dailyAvg > 0
    ''', [thirtyDaysAgo, companyId]);

    List<Map<String, dynamic>> alerts = [];

    for (var row in result) {
      int stock = (row['quantity'] as num).toInt();
      double dailyAvg = (row['dailyAvg'] as num).toDouble();
      double daysUntilStockout = stock / dailyAvg;

      if (daysUntilStockout <= 5) {
        alerts.add({
          'productId': row['id'],
          'productName': row['name'],
          'daysRemaining': daysUntilStockout.floor(),
          'recommendedOrder': (dailyAvg * 14).round(), // recommend 14 days worth
        });
      }
    }

    alerts.sort((a, b) => (a['daysRemaining'] as int).compareTo(b['daysRemaining'] as int));
    return alerts;
  }

  // 4. Profit Optimization Suggestions
  Future<Map<String, dynamic>> getProfitOptimization() async {
    final db = await _db.database;
    final companyId = _db.currentCompanyId;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    final result = await db.rawQuery('''
      SELECT 
        p.name,
        p.costPrice,
        p.sellingPrice,
        SUM(s.quantitySold) as totalSold,
        ((p.sellingPrice - p.costPrice) / p.sellingPrice) * 100 as marginPercentage
      FROM products p
      JOIN sales s ON p.id = s.productId
      WHERE p.companyId = ? AND s.saleDate >= ?
      GROUP BY p.id
      HAVING totalSold > 0
    ''', [companyId, thirtyDaysAgo]);

    if (result.isEmpty) return {'hasData': false};

    var sortedByMargin = List<Map<String, dynamic>>.from(result)
      ..sort((a, b) => (b['marginPercentage'] as num).compareTo(a['marginPercentage'] as num));
      
    var sortedByVolume = List<Map<String, dynamic>>.from(result)
      ..sort((a, b) => (b['totalSold'] as num).compareTo(a['totalSold'] as num));

    return {
      'hasData': true,
      'bestMarginProduct': sortedByMargin.first['name'],
      'bestMargin': (sortedByMargin.first['marginPercentage'] as num).round(),
      'bestVolumeProduct': sortedByVolume.first['name'],
      'underperformingProduct': sortedByVolume.last['name'],
    };
  }
}
