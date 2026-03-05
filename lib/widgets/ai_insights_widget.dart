import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_service.dart';
import '../screens/ai_detailed_forecast_screen.dart';

class AIInsightsWidget extends StatefulWidget {
  const AIInsightsWidget({super.key});

  @override
  State<AIInsightsWidget> createState() => _AIInsightsWidgetState();
}

class _AIInsightsWidgetState extends State<AIInsightsWidget> {
  final AIService _ai = AIService.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _reorderAlerts = [];
  Map<String, dynamic>? _salesInsights;
  Map<String, dynamic>? _profitOptimization;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);

    // Load all concurrently
    final results = await Future.wait([
      _ai.getReorderAlerts(),
      _ai.getSalesInsights(),
      _ai.getProfitOptimization(),
    ]);

    if (mounted) {
      setState(() {
        _reorderAlerts = results[0] as List<Map<String, dynamic>>;
        _salesInsights = results[1] as Map<String, dynamic>;
        _profitOptimization = results[2] as Map<String, dynamic>;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    final bool hasInsights =
        _reorderAlerts.isNotEmpty ||
        (_salesInsights?['hasData'] == true) ||
        (_profitOptimization?['hasData'] == true);

    if (!hasInsights) {
      return const SizedBox.shrink(); // Hide if completely empty (need more data)
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1), // yellow-50
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFFFB300),
                    size: 20,
                  ), // Amber-600
                ),
                const SizedBox(width: 12),
                Text(
                  'AI Insights',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (_reorderAlerts.isNotEmpty) ...[
            _buildSectionTitle('Demand Forecast', Icons.timeline),
            ..._reorderAlerts.take(2).map((alert) => _buildAlertItem(alert)),
          ],

          if (_salesInsights?['hasData'] == true) ...[
            _buildSectionTitle('Sales Trends', Icons.trending_up),
            _buildTrendItem(
              'Peak Sales Day',
              "${_salesInsights!['bestDay']} (+${_salesInsights!['bestDaySpike']}% vs avg)",
              Icons.arrow_upward,
              Colors.green,
            ),
            if (_salesInsights!['worstDay'] != null &&
                _salesInsights!['worstDay'].toString().isNotEmpty)
              _buildTrendItem(
                'Slow Day',
                "${_salesInsights!['worstDay']}",
                Icons.arrow_downward,
                Colors.red,
              ),
          ],

          if (_profitOptimization?['hasData'] == true) ...[
            _buildSectionTitle(
              'Smart Recommendations',
              Icons.lightbulb_outline,
            ),
            _buildRecommendationItem(
              "Focus on ${_profitOptimization!['bestMarginProduct']}",
              "Best profit margin (${_profitOptimization!['bestMargin']}%) with good sales velocity.",
            ),
          ],

          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AIDetailedForecastScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'VIEW DETAILED FORECAST',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFEBEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert['productName'],
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Stock out in ${alert['daysRemaining']} days ⚠️",
            style: GoogleFonts.poppins(
              color: const Color(0xFFE53935),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            "Order ${alert['recommendedOrder']} units NOW",
            style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.green[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(color: Colors.green[700], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
