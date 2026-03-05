import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../database/database_helper.dart';
import '../services/ai_service.dart';

class AIDetailedForecastScreen extends StatefulWidget {
  const AIDetailedForecastScreen({super.key});

  @override
  State<AIDetailedForecastScreen> createState() => _AIDetailedForecastScreenState();
}

class _AIDetailedForecastScreenState extends State<AIDetailedForecastScreen> {
  final _db = DatabaseHelper.instance;
  final _ai = AIService.instance;
  
  bool _isLoading = true;
  List<Product> _products = [];
  Map<int, Map<String, dynamic>> _forecasts = {};

  @override
  void initState() {
    super.initState();
    _loadForecasts();
  }

  Future<void> _loadForecasts() async {
    setState(() => _isLoading = true);
    final products = await _db.readAllProducts();
    Map<int, Map<String, dynamic>> forecasts = {};

    for (var product in products) {
      final forecast = await _ai.getDemandForecast(product);
      forecasts[product.id!] = forecast;
    }

    if (mounted) {
      setState(() {
        _products = products;
        _forecasts = forecasts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text('Detailed Forecast', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              onRefresh: _loadForecasts,
              color: Colors.black,
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  final forecast = _forecasts[product.id];

                  if (forecast == null || forecast['hasEnoughData'] == false) {
                     return _buildInsufficientDataCard(product);
                  }

                  return _buildForecastCard(product, forecast);
                },
              ),
            ),
    );
  }

  Widget _buildForecastCard(Product product, Map<String, dynamic> forecast) {
    bool isHighRisk = forecast['riskLevel'] == 'HIGH';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isHighRisk ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isHighRisk ? 'HIGH RISK' : 'HEALTHY',
                  style: GoogleFonts.poppins(
                    fontSize: 10, 
                    fontWeight: FontWeight.bold, 
                    color: isHighRisk ? Colors.red[700] : Colors.green[700]
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetric('Current Stock', '\${product.quantity}', Icons.inventory_2_outlined)),
              Expanded(child: _buildMetric('7-Day Forecast', "\${forecast['predictedSales7Days']} units", Icons.trending_up, isHighlighted: true)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_outlined, size: 18, color: Colors.indigo[400]),
                const SizedBox(width: 8),
                Text(
                  'Recommended Order: ',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                ),
                Text(
                  "\${forecast['recommendedOrder']} units",
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientDataCard(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  'Need at least 7 days of sales data to forecast.',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Icon(Icons.hourglass_empty, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, {bool isHighlighted = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value, 
          style: GoogleFonts.poppins(
            fontSize: 18, 
            fontWeight: FontWeight.bold, 
            color: isHighlighted ? Colors.black : Colors.black87
          )
        ),
      ],
    );
  }
}
