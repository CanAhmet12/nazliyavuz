import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/skeleton_loading.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  
  Map<String, dynamic>? _analyticsData;
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = '7d';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadAnalyticsData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final data = await _apiService.getAdminAnalytics();
      
      if (mounted) {
        setState(() {
          _analyticsData = data;
          _isLoading = false;
        });
        
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: SafeArea(
        child: _isLoading
            ? const SkeletonLoading(
                width: double.infinity,
                height: double.infinity,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? _buildErrorState()
                : _buildAnalytics(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Analitik veriler yüklenirken hata oluştu',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Bilinmeyen hata',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.grey600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAnalyticsData,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalytics() {
    final analytics = _analyticsData?['analytics'] ?? {};
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.primaryBlue,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Analitikler',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryBlue,
                        AppTheme.primaryBlue.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.analytics,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  initialValue: _selectedPeriod,
                  onSelected: (value) {
                    setState(() {
                      _selectedPeriod = value;
                    });
                    _loadAnalyticsData();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: '7d',
                      child: Text('Son 7 Gün'),
                    ),
                    const PopupMenuItem(
                      value: '30d',
                      child: Text('Son 30 Gün'),
                    ),
                    const PopupMenuItem(
                      value: '90d',
                      child: Text('Son 90 Gün'),
                    ),
                    const PopupMenuItem(
                      value: '1y',
                      child: Text('Son 1 Yıl'),
                    ),
                  ],
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _getPeriodLabel(_selectedPeriod),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadAnalyticsData,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),

            // User Growth Chart
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kullanıcı Büyümesi',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildUserGrowthChart(analytics['user_growth'] ?? []),
                  ],
                ),
              ),
            ),

            // Reservation Trends
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rezervasyon Trendleri',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildReservationTrendsChart(analytics['reservation_trends'] ?? []),
                  ],
                ),
              ),
            ),

            // Category Popularity
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kategori Popülerliği',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoryPopularityChart(analytics['category_popularity'] ?? []),
                  ],
                ),
              ),
            ),

            // Teacher Performance
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Öğretmen Performansı',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTeacherPerformanceChart(analytics['teacher_performance'] ?? []),
                  ],
                ),
              ),
            ),

            // Bottom spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserGrowthChart(List<dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chart placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 48,
                    color: AppTheme.grey400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kullanıcı Büyüme Grafiği',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.grey600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.length} veri noktası',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.grey500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Summary Stats
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Toplam Kullanıcı',
                  data.isNotEmpty ? data.last['total_users']?.toString() ?? '0' : '0',
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Bu Ay',
                  data.isNotEmpty ? data.last['monthly_new']?.toString() ?? '0' : '0',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReservationTrendsChart(List<dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chart placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event,
                    size: 48,
                    color: AppTheme.grey400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rezervasyon Trendleri',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.grey600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.length} veri noktası',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.grey500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Summary Stats
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Toplam Rezervasyon',
                  data.isNotEmpty ? data.last['total_reservations']?.toString() ?? '0' : '0',
                  Icons.event,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Tamamlanan',
                  data.isNotEmpty ? data.last['completed_reservations']?.toString() ?? '0' : '0',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPopularityChart(List<dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chart placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.pie_chart,
                    size: 48,
                    color: AppTheme.grey400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kategori Dağılımı',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.grey600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.length} kategori',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.grey500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Category List
          if (data.isNotEmpty)
            ...data.take(5).map((category) => _buildCategoryItem(category)).toList()
          else
            const Center(
              child: Text('Kategori verisi bulunamadı'),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    final name = category['name'] ?? 'Bilinmeyen';
    final count = category['reservation_count'] ?? 0;
    final percentage = count > 0 ? (count / (category['total'] ?? 1)) * 100 : 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.grey800,
              ),
            ),
          ),
          Text(
            '$count rezervasyon',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 60,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.grey200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherPerformanceChart(List<dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chart placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 48,
                    color: AppTheme.grey400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Öğretmen Performansı',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.grey600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.length} öğretmen',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.grey500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Top Teachers List
          if (data.isNotEmpty)
            ...data.take(5).map((teacher) => _buildTeacherItem(teacher)).toList()
          else
            const Center(
              child: Text('Öğretmen verisi bulunamadı'),
            ),
        ],
      ),
    );
  }

  Widget _buildTeacherItem(Map<String, dynamic> teacher) {
    final name = teacher['name'] ?? 'Bilinmeyen';
    final rating = teacher['rating_avg'] ?? 0.0;
    final lessons = teacher['total_lessons'] ?? 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grey800,
                  ),
                ),
                Text(
                  '$lessons ders',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.grey800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getPeriodLabel(String period) {
    switch (period) {
      case '7d':
        return '7 Gün';
      case '30d':
        return '30 Gün';
      case '90d':
        return '90 Gün';
      case '1y':
        return '1 Yıl';
      default:
        return '7 Gün';
    }
  }
}