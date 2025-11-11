import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';

class ReservationStatisticsScreen extends StatefulWidget {
  const ReservationStatisticsScreen({Key? key}) : super(key: key);

  @override
  State<ReservationStatisticsScreen> createState() => _ReservationStatisticsScreenState();
}

class _ReservationStatisticsScreenState extends State<ReservationStatisticsScreen> {
  final ApiService _apiService = ApiService();
  
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _apiService.getReservationStatistics();
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezervasyon İstatistikleri'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Hata: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStatistics,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_statistics == null) {
      return const Center(
        child: Text('İstatistik verisi bulunamadı'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI Cards Row 1
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    '💰 Toplam Gelir',
                    '₺${_statistics!['total_revenue']?.toStringAsFixed(2) ?? '0.00'}',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    '📊 Bu Ay',
                    '${_statistics!['this_month'] ?? 0} Ders',
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // KPI Cards Row 2
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    '✅ Tamamlanma',
                    '${_statistics!['completion_rate']?.toStringAsFixed(1) ?? '0.0'}%',
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    '⭐ Değerlendirme',
                    '${_statistics!['rating_rate']?.toStringAsFixed(1) ?? '0.0'}%',
                    Colors.amber,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Summary Stats Card
            _buildSummaryCard(),

            const SizedBox(height: 24),

            // Revenue Card
            _buildRevenueCard(),

            const SizedBox(height: 24),

            // Performance Rates
            _buildPerformanceCard(),

            const SizedBox(height: 24),

            // Monthly Trends Chart
            if (_statistics!['monthly_trends'] != null)
              _buildMonthlyTrendsCard(),

            const SizedBox(height: 24),

            // Popular Time Slots (Teacher only)
            if (_statistics!['popular_time_slots'] != null && 
                (_statistics!['popular_time_slots'] as List).isNotEmpty)
              _buildPopularTimeSlotsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Genel Özet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Toplam Rezervasyon', '${_statistics!['total_reservations'] ?? 0}'),
            _buildStatRow('Bekleyen', '${_statistics!['pending_reservations'] ?? 0}', color: Colors.orange),
            _buildStatRow('Onaylanan', '${_statistics!['confirmed_reservations'] ?? 0}', color: Colors.blue),
            _buildStatRow('Tamamlanan', '${_statistics!['completed_reservations'] ?? 0}', color: Colors.green),
            _buildStatRow('İptal Edilen', '${_statistics!['cancelled_reservations'] ?? 0}', color: Colors.red),
            if (_statistics!['rejected_reservations'] != null)
              _buildStatRow('Reddedilen', '${_statistics!['rejected_reservations']}', color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💰 Gelir Analizi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildRevenueRow(
              'Toplam Gelir', 
              '₺${_statistics!['total_revenue']?.toStringAsFixed(2) ?? '0.00'}',
              Colors.green,
              Icons.account_balance_wallet,
            ),
            _buildRevenueRow(
              'Beklenen Gelir', 
              '₺${_statistics!['potential_revenue']?.toStringAsFixed(2) ?? '0.00'}',
              Colors.blue,
              Icons.pending,
            ),
            _buildRevenueRow(
              'Kayıp Gelir', 
              '₺${_statistics!['lost_revenue']?.toStringAsFixed(2) ?? '0.00'}',
              Colors.red,
              Icons.money_off,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📈 Performans Metrikleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_statistics!['acceptance_rate'] != null)
              _buildProgressRow(
                'Onaylama Oranı',
                _statistics!['acceptance_rate'],
                Colors.blue,
              ),
            _buildProgressRow(
              'İptal Oranı',
              _statistics!['cancellation_rate'],
              Colors.red,
            ),
            _buildProgressRow(
              'Tamamlanma Oranı',
              _statistics!['completion_rate'],
              Colors.green,
            ),
            _buildProgressRow(
              'Değerlendirme Oranı',
              _statistics!['rating_rate'],
              Colors.amber,
            ),
            const SizedBox(height: 16),
            if (_statistics!['average_response_time_minutes'] != null)
              _buildInfoRow(
                'Ortalama Cevap Süresi',
                '${_statistics!['average_response_time_minutes']} dakika',
                Icons.timer,
              ),
            if (_statistics!['average_lesson_duration_minutes'] != null)
              _buildInfoRow(
                'Ortalama Ders Süresi',
                '${_statistics!['average_lesson_duration_minutes']} dakika',
                Icons.access_time,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrendsCard() {
    final trends = _statistics!['monthly_trends'] as List;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Aylık Trend (Son 6 Ay)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < trends.length) {
                            final month = trends[value.toInt()]['month_name'] as String;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                month.split(' ')[0].substring(0, 3),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: trends.asMap().entries.map((e) {
                        return FlSpot(
                          e.key.toDouble(),
                          (e.value['revenue'] as num).toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            ...trends.map((trend) => _buildTrendRow(trend)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularTimeSlotsCard() {
    final slots = _statistics!['popular_time_slots'] as List;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🕐 En Popüler Saatler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...slots.map((slot) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.access_time, color: Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot['time'] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${slot['count']} ders',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text('${slot['count']}'),
                      backgroundColor: Colors.blue.shade100,
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueRow(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, dynamic value, Color color) {
    final percentage = (value as num?)?.toDouble() ?? 0.0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 15),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[200],
              color: color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendRow(Map<String, dynamic> trend) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            trend['month_name'] as String,
            style: const TextStyle(fontSize: 14),
          ),
          Row(
            children: [
              Text(
                '${trend['total']} ders',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Text(
                '₺${(trend['revenue'] as num).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

