import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/teacher.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/reservations/create_reservation_screen.dart';
import '../screens/teachers/teacher_detail_screen.dart';

class TeacherCard extends StatelessWidget {
  final Teacher teacher;
  final VoidCallback? onTap;
  final bool showFavoriteButton;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const TeacherCard({
    super.key,
    required this.teacher,
    this.onTap,
    this.showFavoriteButton = true,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 600),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap ?? () {
                  // Default behavior: Navigate to teacher detail
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeacherDetailScreen(teacher: teacher),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Türkiye Kimlik Kartı Tasarımı - Header
                    _buildTurkishIDHeader(),
                    
                    // İçerik Bölümü
                    Padding(
                      padding: const EdgeInsets.all(12), // 16 -> 12
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Eğitimci Bilgileri
                          _buildTeacherInfo(),
                          
                          const SizedBox(height: 8), // 12 -> 8
                          
                          // Kategoriler
                          _buildCategories(),
                          
                          const SizedBox(height: 8), // 12 -> 8
                          
                          // Rating ve Fiyat
                          _buildRatingAndPrice(),
                          
                          const SizedBox(height: 8), // 12 -> 8
                          
                          // Ders Türleri
                          _buildLessonTypes(),
                          
                          const SizedBox(height: 12), // 16 -> 12
                          
                          // Aksiyon Butonları
                          _buildActionButtons(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTurkishIDHeader() {
    return Container(
      height: 160, // Overflow için küçültüldü
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00BFA5), // Türkiye turkuaz rengi
            const Color(0xFF00897B),
            const Color(0xFF00695C),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Türkiye motifleri ve desenler
          _buildTurkishPatterns(),
          
          // Profil fotoğrafı
          Positioned(
            left: 20,
            top: 20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: teacher.user?.profilePhotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: teacher.user!.profilePhotoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.white,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BFA5)),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.white,
                          child: Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: const Color(0xFF00BFA5),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.white,
                        child: Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: const Color(0xFF00BFA5),
                        ),
                      ),
              ),
            ),
          ),
          
          // Online durumu - Sol üst köşe
          Positioned(
            top: 20,
            left: 200,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: teacher.onlineAvailable ? const Color(0xFF4CAF50) : const Color(0xFFFF5722),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    teacher.onlineAvailable ? 'MÜSAİT' : 'MEŞGUL',
                    style: TextStyle(
                      color: teacher.onlineAvailable ? const Color(0xFF4CAF50) : const Color(0xFFFF5722),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Favori butonu - Sağ üst köşe
          if (showFavoriteButton)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavorite ? Colors.red : const Color(0xFF00BFA5),
                    size: 20,
                  ),
                  onPressed: onFavoriteToggle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTurkishPatterns() {
    return Stack(
      children: [
        // Selçuklu çizgileri
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -30,
          left: -30,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
          ),
        ),
        // Türkiye yıldızı motifi
        Positioned(
          top: 50,
          right: 30,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          right: 50,
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teacher.user?.name ?? 'Bilinmeyen Eğitimci',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          (teacher.bio?.isNotEmpty ?? false) ? teacher.bio! : 'Deneyimli Eğitimci',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCategories() {
    if (!(teacher.categories?.isNotEmpty ?? false)) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: teacher.categories!.take(3).map((category) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF00BFA5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF00BFA5).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            category.name,
            style: const TextStyle(
              color: Color(0xFF00BFA5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRatingAndPrice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Rating
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF9800).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  color: const Color(0xFFFF9800),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  teacher.ratingAvg.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Color(0xFFFF9800),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${teacher.ratingCount})',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Fiyat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BFA5).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              '₺${(teacher.priceHour ?? 0).toStringAsFixed(0)}/saat',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonTypes() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_rounded,
                  color: const Color(0xFF4CAF50),
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Yüz Yüze',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF00BFA5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00BFA5).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_call_rounded,
                  color: const Color(0xFF00BFA5),
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Online',
                  style: TextStyle(
                    color: Color(0xFF00BFA5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF9800).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_rounded,
                  color: const Color(0xFFFF9800),
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Ücretsiz',
                  style: TextStyle(
                    color: Color(0xFFFF9800),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42, // 48 -> 42 overflow için
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (teacher.user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          otherUser: teacher.user!,
                        ),
                      ),
                    );
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.message_rounded,
                      color: const Color(0xFF00BFA5),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Mesaj',
                      style: TextStyle(
                        color: Color(0xFF00BFA5),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          flex: 2,
          child: Container(
            height: 42, // 48 -> 42 overflow için
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BFA5).withOpacity(0.3), // 0.4 -> 0.3
                  blurRadius: 8, // 12 -> 8
                  offset: const Offset(0, 4), // 6 -> 4
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  try {
                    if (kDebugMode) {
                      print('🔄 Rezerve Et button tapped for teacher: ${teacher.displayName}');
                      print('🔄 Teacher ID: ${teacher.id}');
                      print('🔄 Teacher User: ${teacher.user?.name}');
                      print('🔄 Context: $context');
                      print('🔄 onTap callback: $onTap');
                    }
                    
                    // Haptic feedback ekle
                    HapticFeedback.lightImpact();
                    
                    if (onTap != null) {
                      if (kDebugMode) {
                        print('🔄 Using custom onTap callback');
                      }
                      onTap!();
                    } else {
                      if (kDebugMode) {
                        print('🔄 Navigating to CreateReservationScreen');
                      }
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateReservationScreen(
                            teacher: teacher,
                          ),
                        ),
                      ).then((result) {
                        if (kDebugMode) {
                          print('🔄 Reservation screen closed with result: $result');
                        }
                      }).catchError((error) {
                        if (kDebugMode) {
                          print('❌ Error navigating to reservation screen: $error');
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Rezervasyon sayfası açılırken hata oluştu: $error'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      });
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print('❌ Exception in reserve button: $e');
                      print('❌ Stack trace: ${StackTrace.current}');
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rezervasyon butonunda hata oluştu: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Rezerve Et',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14, // 16 -> 14
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TeacherGridCard extends StatelessWidget {
  final Teacher teacher;
  final VoidCallback? onTap;
  final bool showFavoriteButton;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const TeacherGridCard({
    super.key,
    required this.teacher,
    this.onTap,
    this.showFavoriteButton = true,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationConfiguration.staggeredGrid(
      position: 0,
      duration: const Duration(milliseconds: 600),
      columnCount: 2,
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap ?? () {
                  // Default behavior: Navigate to teacher detail
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeacherDetailScreen(teacher: teacher),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Türkiye Kimlik Kartı Tasarımı - Grid Header
                    _buildTurkishIDGridHeader(),
                    
                    // İçerik Bölümü
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // İsim ve Unvan
                            _buildNameAndTitle(),
                            
                            const SizedBox(height: 4),
                            
                            // Rating ve Fiyat
                            _buildRatingAndPriceRow(),
                            
                            const SizedBox(height: 10),
                            
                            // Aksiyon Butonu
                            _buildActionButton(context),
                            
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTurkishIDGridHeader() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00BFA5),
            const Color(0xFF00897B),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Türkiye motifleri
          _buildTurkishGridPatterns(),
          
          // Profil fotoğrafı
          Center(
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: teacher.user?.profilePhotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: teacher.user!.profilePhotoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.white,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BFA5)),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.white,
                          child: Icon(
                            Icons.person_rounded,
                            size: 25,
                            color: const Color(0xFF00BFA5),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.white,
                        child: Icon(
                          Icons.person_rounded,
                          size: 25,
                          color: const Color(0xFF00BFA5),
                        ),
                      ),
              ),
            ),
          ),
          
          // Online durumu - Sol üst köşe
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: teacher.onlineAvailable ? const Color(0xFF4CAF50) : const Color(0xFFFF5722),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    teacher.onlineAvailable ? 'MÜSAİT' : 'MEŞGUL',
                    style: TextStyle(
                      color: teacher.onlineAvailable ? const Color(0xFF4CAF50) : const Color(0xFFFF5722),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Favori butonu - Sağ üst köşe
          if (showFavoriteButton)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavorite ? Colors.red : const Color(0xFF00BFA5),
                    size: 16,
                  ),
                  onPressed: onFavoriteToggle,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTurkishGridPatterns() {
    return Stack(
      children: [
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -30,
          left: -30,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameAndTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teacher.user?.name ?? 'Bilinmeyen Eğitimci',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          (teacher.bio?.isNotEmpty ?? false) ? teacher.bio! : 'Deneyimli Eğitimci',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildRatingAndPriceRow() {
    return Row(
      children: [
        // Rating
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFF9800).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                color: const Color(0xFFFF9800),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                teacher.ratingAvg.toStringAsFixed(1),
                style: const TextStyle(
                  color: Color(0xFFFF9800),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Fiyat
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BFA5).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '₺${(teacher.priceHour ?? 0).toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Teacher detail sayfasına git
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherDetailScreen(teacher: teacher),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 28, // Biraz yükseklik artırıldı
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
          ),
          borderRadius: BorderRadius.circular(8), // Biraz daha büyük border radius
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BFA5).withOpacity(0.2),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Detayları Gör',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11, // Font boyutu artırıldı
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}