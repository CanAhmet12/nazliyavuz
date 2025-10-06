import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/reservation.dart';

class ReservationManagementScreen extends StatefulWidget {
  const ReservationManagementScreen({super.key});

  @override
  State<ReservationManagementScreen> createState() => _ReservationManagementScreenState();
}

class _ReservationManagementScreenState extends State<ReservationManagementScreen> {
  final ApiService _apiService = ApiService();
  List<Reservation> _reservations = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'all';
  bool _isLoadingReservations = false; // Prevent multiple calls

  @override
  void initState() {
    super.initState();
    // STOP API CALLS - Only manual refresh allowed
    print('🔍 [RESERVATIONS] initState - NO API CALL');
  }

  Future<void> _loadReservations() async {
    print('🔍 [RESERVATIONS] _loadReservations called');
    
    // STOP ALL API CALLS - Only allow manual refresh
    if (_isLoadingReservations) {
      print('🔍 [RESERVATIONS] Already loading, skipping call');
      return;
    }
    
    // STOP ALL API CALLS - Only allow manual refresh
    if (_reservations.isNotEmpty) {
      print('🔍 [RESERVATIONS] Already loaded, skipping call');
      return;
    }
    
    _isLoadingReservations = true;
    
    setState(() {
      _isLoading = true;
      _error = null;
      _reservations.clear(); // Clear existing reservations
    });

    try {
      final reservations = await _apiService.getTeacherReservations();
      
      print('🔍 [RESERVATIONS] Raw API response: ${reservations.length} reservations');
      for (int i = 0; i < reservations.length; i++) {
        print('🔍 [RESERVATIONS] Raw $i: ID=${reservations[i].id}, Subject=${reservations[i].subject}');
      }
      
      // Ultra strong duplicate check on frontend
      final seenIds = <int>{};
      final uniqueReservations = <Reservation>[];
      
      print('🔍 [RESERVATIONS] Starting duplicate removal process');
      print('🔍 [RESERVATIONS] Input reservations: ${reservations.length}');
      
      // Single pass: collect unique reservations
      for (final reservation in reservations) {
        if (!seenIds.contains(reservation.id)) {
          seenIds.add(reservation.id);
          uniqueReservations.add(reservation);
          print('🔍 [RESERVATIONS] Added unique reservation: ID=${reservation.id}, Subject=${reservation.subject}');
        } else {
          print('🔍 [RESERVATIONS] DUPLICATE FOUND: ID=${reservation.id}, Subject=${reservation.subject}');
        }
      }
      
      print('🔍 [RESERVATIONS] Unique IDs found: ${seenIds.length}');
      print('🔍 [RESERVATIONS] Duplicates removed: ${reservations.length - uniqueReservations.length}');
      
      print('🔍 [RESERVATIONS] After duplicate removal: ${uniqueReservations.length} reservations');
      for (int i = 0; i < uniqueReservations.length; i++) {
        print('🔍 [RESERVATIONS] Unique $i: ID=${uniqueReservations[i].id}, Subject=${uniqueReservations[i].subject}');
      }
      
      // Clear existing reservations first
      _reservations.clear();
      
      setState(() {
        _reservations = List.from(uniqueReservations); // Create new list
        _isLoading = false;
      });
      
      print('🔍 [RESERVATIONS] Final state: ${_reservations.length} reservations in _reservations list');
      print('🔍 [RESERVATIONS] Final reservations IDs: ${_reservations.map((r) => r.id).toList()}');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    } finally {
      _isLoadingReservations = false;
    }
  }

  Future<void> _updateReservationStatus(Reservation reservation, String status) async {
    try {
      await _apiService.updateReservationStatus(reservation.id, status);
      
      setState(() {
        final index = _reservations.indexWhere((r) => r.id == reservation.id);
        if (index != -1) {
          _reservations[index] = reservation.copyWith(status: status);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rezervasyon durumu "$_getStatusText(status)" olarak güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'accepted':
        return 'Kabul Edildi';
      case 'rejected':
        return 'Reddedildi';
      case 'cancelled':
        return 'İptal Edildi';
      case 'completed':
        return 'Tamamlandı';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  List<Reservation> get _filteredReservations {
    if (_selectedStatus == 'all') {
      return _reservations;
    }
    return _reservations.where((r) => r.status == _selectedStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezervasyon Yönetimi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () {
          print('🔍 [RESERVATIONS] Refresh button pressed');
          // Force refresh by clearing loading state
          _isLoadingReservations = false;
          // Clear existing data first
          setState(() {
            _reservations.clear();
            _isLoading = true;
            _error = null;
          });
          _loadReservations();
        },
      ),
        ],
      ),
      body: Column(
        children: [
          // Durum Filtresi
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusChip('all', 'Tümü'),
                  const SizedBox(width: 8),
                  _buildStatusChip('pending', 'Beklemede'),
                  const SizedBox(width: 8),
                  _buildStatusChip('accepted', 'Kabul Edildi'),
                  const SizedBox(width: 8),
                  _buildStatusChip('rejected', 'Reddedildi'),
                  const SizedBox(width: 8),
                  _buildStatusChip('completed', 'Tamamlandı'),
                ],
              ),
            ),
          ),

          // Rezervasyon Listesi
          Expanded(
            child: _buildReservationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, String label) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = status;
        });
      },
    );
  }

  Widget _buildReservationsList() {
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Bir hata oluştu',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReservations,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_filteredReservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Rezervasyon bulunamadı',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Henüz rezervasyon talebi yok',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Final duplicate check before rendering
    final finalSeenIds = <int>{};
    final finalUniqueReservations = <Reservation>[];
    
    for (final reservation in _filteredReservations) {
      if (!finalSeenIds.contains(reservation.id)) {
        finalSeenIds.add(reservation.id);
        finalUniqueReservations.add(reservation);
      }
    }
    
    print('🔍 [RESERVATIONS] Final rendering check');
    print('🔍 [RESERVATIONS] Original filtered: ${_filteredReservations.length}');
    print('🔍 [RESERVATIONS] Final unique: ${finalUniqueReservations.length}');
    print('🔍 [RESERVATIONS] Final duplicates removed: ${_filteredReservations.length - finalUniqueReservations.length}');
    
    for (int i = 0; i < finalUniqueReservations.length; i++) {
      print('🔍 [RESERVATIONS] Final item $i: ID=${finalUniqueReservations[i].id}, Subject=${finalUniqueReservations[i].subject}');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: finalUniqueReservations.length,
      itemBuilder: (context, index) {
        final reservation = finalUniqueReservations[index];
        print('🔍 [RESERVATIONS] Building card for index $index: ID=${reservation.id}');
        return _buildReservationCard(reservation);
      },
      key: ValueKey('reservations_${finalUniqueReservations.length}'),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      addSemanticIndexes: false,
      cacheExtent: 200,
    );
  }

  Widget _buildReservationCard(Reservation reservation) {
    return Card(
      key: ValueKey('reservation_${reservation.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık ve Durum
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    reservation.subject,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(reservation.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(reservation.status),
                    style: TextStyle(
                      color: _getStatusColor(reservation.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Öğrenci Bilgisi
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  reservation.student?.name ?? 'Bilinmeyen Öğrenci',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tarih ve Saat
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDateTime(reservation.proposedDatetime),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Süre ve Fiyat
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${reservation.durationMinutes} dakika',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.attach_money,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${reservation.price.toStringAsFixed(2)} TL',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // Notlar
            if (reservation.notes != null && reservation.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Öğrenci Notu: ${reservation.notes}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // Aksiyon Butonları
            if (reservation.status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showStatusDialog(reservation, 'accepted'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Kabul Et'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showStatusDialog(reservation, 'rejected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reddet'),
                    ),
                  ),
                ],
              ),
            ],

            // Tamamlandı butonu
            if (reservation.status == 'accepted') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showStatusDialog(reservation, 'completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Tamamlandı Olarak İşaretle'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showStatusDialog(Reservation reservation, String newStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rezervasyon ${_getStatusText(newStatus)}'),
        content: Text(
          'Bu rezervasyonu "${_getStatusText(newStatus)}" olarak işaretlemek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateReservationStatus(reservation, newStatus);
            },
            child: Text(_getStatusText(newStatus)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
