import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

/// A 7-day daily sales bar chart drawn with CustomPainter — no extra package.
class SalesChartWidget extends StatefulWidget {
  const SalesChartWidget({super.key});

  @override
  State<SalesChartWidget> createState() => _SalesChartWidgetState();
}

class _SalesChartWidgetState extends State<SalesChartWidget> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await DatabaseHelper.instance.getDailySales(days: 7);
    if (mounted) setState(() { _data = raw; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(color: Color(0xFFFFB300))),
      );
    }

    // Build a full 7-day list (fill in zeros for missing days)
    final now = DateTime.now();
    final List<_DayBar> bars = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final key = DateFormat('yyyy-MM-dd').format(day);
      final match = _data.firstWhere(
        (r) => r['date'].toString().startsWith(key),
        orElse: () => {},
      );
      return _DayBar(
        label: DateFormat('E').format(day), // Mon, Tue …
        date: day,
        total: (match['total'] as num?)?.toDouble() ?? 0.0,
      );
    });

    final hasData = bars.any((b) => b.total > 0);
    if (!hasData) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text('No sales in the last 7 days',
              style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13)),
        ),
      );
    }

    final maxVal = bars.fold<double>(0, (m, b) => b.total > m ? b.total : m);
    final currencyFmt = NumberFormat.compact();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sales — Last 7 Days',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(
                'Total: \$${currencyFmt.format(bars.fold<double>(0, (s, b) => s + b.total))}',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _BarChartPainter(bars: bars, maxVal: maxVal),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 8),
          // Day labels row
          Row(
            children: bars.map((b) {
              final isToday = DateFormat('yyyy-MM-dd').format(b.date) ==
                  DateFormat('yyyy-MM-dd').format(now);
              return Expanded(
                child: Text(
                  b.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? Colors.black : Colors.grey[500],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DayBar {
  final String label;
  final DateTime date;
  final double total;
  const _DayBar({required this.label, required this.date, required this.total});
}

class _BarChartPainter extends CustomPainter {
  final List<_DayBar> bars;
  final double maxVal;

  const _BarChartPainter({required this.bars, required this.maxVal});

  @override
  void paint(Canvas canvas, Size size) {
    if (maxVal == 0) return;

    const barPadding = 6.0;
    const bottomLabelHeight = 0.0; // labels drawn separately
    final chartH = size.height - bottomLabelHeight;
    final barW = (size.width - barPadding * (bars.length + 1)) / bars.length;

    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    for (int i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final fraction = bar.total / maxVal;
      final barH = max(fraction * chartH * 0.88, bar.total > 0 ? 4.0 : 0.0);
      final left = barPadding + i * (barW + barPadding);
      final top = chartH - barH;
      final isToday = DateFormat('yyyy-MM-dd').format(bar.date) == todayKey;

      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, barW, barH),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      final paint = Paint()
        ..color = isToday
            ? const Color(0xFFFFB300)
            : const Color(0xFFFFE082);
      canvas.drawRRect(rect, paint);
    }

    // Baseline
    final linePaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, chartH), Offset(size.width, chartH), linePaint);
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.bars != bars || old.maxVal != maxVal;
}
