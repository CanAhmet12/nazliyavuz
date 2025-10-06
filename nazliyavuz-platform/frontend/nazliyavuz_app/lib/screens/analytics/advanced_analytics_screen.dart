import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../services/offline_service.dart';

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen({super.key});

  @override
  State<AdvancedAnalyticsScreen> createState() => _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  
  late TabController _tabController;
  
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String _selectedPeriod = '30';
  bool _isOfflineMode = false;
  
  final List<String> _periods = ['7', '30', '90', '365'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final analytics = await _apiService.getAdminAnalytics();
      setState(() {
        _analytics = analytics;
        _isLoading = false;
        _isOfflineMode = false;
      });
    } catch (e) {
      // Try to load cached data
      final cachedData = await OfflineService.getCachedCategories();
      if (cachedData != null) {
        setState(() {
          _isOfflineMode = true;
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline modda - önbelleklenmiş veriler gösteriliyor'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Analytics yüklenirken hata: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOfflineMode ? 'Analytics (Offline)' : 'Gelişmiş Analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isOfflineMode)
            const Icon(Icons.wifi_off, color: Colors.orange),
          DropdownButton<String>(
            value: _selectedPeriod,
            items: _periods.map((period) {
              String label;
              switch (period) {
                case '7':
                  label = 'Son 7 Gün';
                  break;
                case '30':
                  label = 'Son 30 Gün';
                  break;
                case '90':
                  label = 'Son 90 Gün';
                  break;
                case '365':
                  label = 'Son 1 Yıl';
                  break;
                default:
                  label = period;
              }
              return DropdownMenuItem(
                value: period,
                child: Text(label),
              );
            }).toList(),
            onChanged: _isOfflineMode ? null : (value) {
              setState(() {
                _selectedPeriod = value!;
              });
              _loadAnalytics();
            },
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Genel'),
            Tab(icon: Icon(Icons.people), text: 'Kullanıcılar'),
            Tab(icon: Icon(Icons.school), text: 'Öğretmenler'),
            Tab(icon: Icon(Icons.trending_up), text: 'Trendler'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isOfflineMode
              ? _buildOfflineContent()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGeneralTab(),
                    _buildUsersTab(),
                    _buildTeachersTab(),
                    _buildTrendsTab(),
                  ],
                ),
    );
  }

  Widget _buildOfflineContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off,
            size: 64,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          const Text(
            'Offline Mod',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'İnternet bağlantısı olmadığı için\nönbelleklenmiş veriler gösteriliyor',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh),
            label: const Text('Yeniden Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    if (_analytics == null) return const Center(child: Text('Veri bulunamadı'));
    
    final userActivity = _analytics!['user_activity'] as Map<String, dynamic>? ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewCards(userActivity),
          const SizedBox(height: 24),
          _buildUserRegistrationsChart(),
          const SizedBox(height: 24),
          _buildReservationTrendsChart(),
          const SizedBox(height: 24),
          _buildRevenueChart(),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_analytics == null) return const Center(child: Text('Veri bulunamadı'));
    
    final userActivity = _analytics!['user_activity'] as Map<String, dynamic>? ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserActivityChart(userActivity),
          const SizedBox(height: 24),
          _buildUserEngagementMetrics(),
          const SizedBox(height: 24),
          _buildUserRetentionChart(),
        ],
      ),
    );
  }

  Widget _buildTeachersTab() {
    if (_analytics == null) return const Center(child: Text('Veri bulunamadı'));
    
    final teacherPerformance = _analytics!['teacher_performance'] as List<dynamic>? ?? [];
    final categoryPopularity = _analytics!['category_popularity'] as List<dynamic>? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTeacherPerformanceChart(teacherPerformance),
          const SizedBox(height: 24),
          _buildCategoryPopularityChart(categoryPopularity),
          const SizedBox(height: 24),
          _buildTeacherEarningsChart(),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    if (_analytics == null) return const Center(child: Text('Veri bulunamadı'));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTrendingCategories(),
          const SizedBox(height: 24),
          _buildPeakHoursChart(),
          const SizedBox(height: 24),
          _buildSeasonalTrendsChart(),
        ],
      ),
    );
  }

  Widget _buildOverviewCards(Map<String, dynamic> userActivity) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          'Aktif Kullanıcılar',
          userActivity['active_users'].toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Yeni Kullanıcılar',
          userActivity['new_users'].toString(),
          Icons.person_add,
          Colors.green,
        ),
        _buildStatCard(
          'Doğrulanmış',
          userActivity['verified_users'].toString(),
          Icons.verified,
          Colors.orange,
        ),
        _buildStatCard(
          'Doğrulanmamış',
          userActivity['unverified_users'].toString(),
          Icons.warning,
          Colors.red,
        ),
      ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRegistrationsChart() {
    final registrations = _analytics!['user_registrations'] as List<dynamic>? ?? [];
    
    if (registrations.isEmpty) {
      return _buildEmptyChart('Kullanıcı Kayıtları', 'Veri bulunamadı');
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kullanıcı Kayıtları',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: registrations.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), 
                            (entry.value['count'] as num).toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationTrendsChart() {
    final trends = _analytics!['reservation_trends'] as Map<String, dynamic>? ?? {};
    
    if (trends.isEmpty) {
      return _buildEmptyChart('Rezervasyon Trendleri', 'Veri bulunamadı');
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rezervasyon Trendleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: trends.entries.map((entry) {
                    final status = entry.key;
                    final data = entry.value as List<dynamic>? ?? [];
                    
                    Color color;
                    switch (status) {
                      case 'completed':
                        color = Colors.green;
                        break;
                      case 'pending':
                        color = Colors.orange;
                        break;
                      case 'cancelled':
                        color = Colors.red;
                        break;
                      default:
                        color = Colors.blue;
                    }
                    
                    return LineChartBarData(
                      spots: data.asMap().entries.map((dataEntry) {
                        return FlSpot(dataEntry.key.toDouble(), 
                            (dataEntry.value['count'] as num).toDouble());
                      }).toList(),
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    final revenue = _analytics!['revenue_analytics'] as List<dynamic>? ?? [];
    
    if (revenue.isEmpty) {
      return _buildEmptyChart('Gelir Analizi', 'Veri bulunamadı');
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gelir Analizi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  barGroups: revenue.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: (entry.value['revenue'] as num).toDouble(),
                          color: Colors.green,
                          width: 16,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserActivityChart(Map<String, dynamic> userActivity) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kullanıcı Aktivite Analizi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: userActivity['active_users'].toDouble(),
                      title: 'Aktif',
                      color: Colors.green,
                    ),
                    PieChartSectionData(
                      value: userActivity['new_users'].toDouble(),
                      title: 'Yeni',
                      color: Colors.blue,
                    ),
                    PieChartSectionData(
                      value: userActivity['verified_users'].toDouble(),
                      title: 'Doğrulanmış',
                      color: Colors.orange,
                    ),
                    PieChartSectionData(
                      value: userActivity['unverified_users'].toDouble(),
                      title: 'Doğrulanmamış',
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserEngagementMetrics() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kullanıcı Etkileşim Metrikleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.login, color: Colors.blue),
              title: Text('Günlük Aktif Kullanıcılar'),
              subtitle: Text('1,234 kullanıcı'),
            ),
            const ListTile(
              leading: Icon(Icons.schedule, color: Colors.green),
              title: Text('Ortalama Oturum Süresi'),
              subtitle: Text('24 dakika'),
            ),
            const ListTile(
              leading: Icon(Icons.repeat, color: Colors.orange),
              title: Text('Geri Dönüş Oranı'),
              subtitle: Text('68%'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRetentionChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kullanıcı Tutma Analizi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 100),
                        const FlSpot(1, 85),
                        const FlSpot(2, 72),
                        const FlSpot(3, 65),
                        const FlSpot(4, 60),
                        const FlSpot(5, 58),
                        const FlSpot(6, 55),
                      ],
                      isCurved: true,
                      color: Colors.purple,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherPerformanceChart(List<dynamic> teacherPerformance) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'En Başarılı Öğretmenler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  barGroups: teacherPerformance.take(5).toList().asMap().entries.map((entry) {
                    final teacher = entry.value;
                    final completedReservations = teacher['completed_reservations'] as int;
                    
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: completedReservations.toDouble(),
                          color: Colors.indigo,
                          width: 16,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPopularityChart(List<dynamic> categories) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Popüler Kategoriler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: categories.take(5).toList().map((category) {
                    final reservationsCount = category['reservations_count'] as int;
                    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple];
                    final index = categories.indexOf(category);
                    
                    return PieChartSectionData(
                      value: reservationsCount.toDouble(),
                      title: category['name'],
                      color: colors[index % colors.length],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherEarningsChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Öğretmen Kazanç Analizi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 5000),
                        const FlSpot(1, 5200),
                        const FlSpot(2, 4800),
                        const FlSpot(3, 5500),
                        const FlSpot(4, 6000),
                        const FlSpot(5, 5800),
                        const FlSpot(6, 6200),
                      ],
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingCategories() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trend Kategoriler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.trending_up, color: Colors.green),
              title: Text('Matematik'),
              subtitle: Text('+25% artış bu hafta'),
            ),
            const ListTile(
              leading: Icon(Icons.trending_up, color: Colors.blue),
              title: Text('İngilizce'),
              subtitle: Text('+18% artış bu hafta'),
            ),
            const ListTile(
              leading: Icon(Icons.trending_down, color: Colors.red),
              title: Text('Fizik'),
              subtitle: Text('-5% düşüş bu hafta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakHoursChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yoğun Saatler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  barGroups: List.generate(24, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: (index >= 9 && index <= 17) ? 100.0 : 30.0,
                          color: (index >= 9 && index <= 17) ? Colors.green : Colors.grey,
                          width: 8,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonalTrendsChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mevsimsel Trendler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 100),
                        const FlSpot(1, 120),
                        const FlSpot(2, 110),
                        const FlSpot(3, 130),
                        const FlSpot(4, 140),
                        const FlSpot(5, 125),
                        const FlSpot(6, 115),
                        const FlSpot(7, 105),
                        const FlSpot(8, 95),
                        const FlSpot(9, 85),
                        const FlSpot(10, 90),
                        const FlSpot(11, 100),
                      ],
                      isCurved: true,
                      color: Colors.purple,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(String title, String message) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Icon(
              Icons.bar_chart,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
