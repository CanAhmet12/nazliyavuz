import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/reservation.dart';
import '../../services/api_service.dart';
import 'payment_success_screen.dart';
import 'payment_failed_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Reservation reservation;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.reservation,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // late WebViewController _webViewController; // Temporarily unused
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _paymentUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // PayTR ödeme URL'si oluştur
      final response = await _apiService.createPayment({
        'reservation_id': widget.reservation.id,
        'amount': widget.amount,
        'currency': 'TRY',
        'description': '${widget.reservation.subject} - ${widget.reservation.teacher?.name}',
      });

      if (response['success']) {
        setState(() {
          _paymentUrl = response['payment_url'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Ödeme başlatılamadı';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ödeme başlatılırken hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ödeme'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        automaticallyImplyLeading: false,
      ),
      body: _buildPaymentContent(),
    );
  }

  Widget _buildPaymentContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Ödeme hazırlanıyor...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Ödeme Hatası',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializePayment,
                child: const Text('Tekrar Dene'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
            ],
          ),
        ),
      );
    }

    if (_paymentUrl == null) {
      return const Center(
        child: Text('Ödeme URL\'si alınamadı'),
      );
    }

    return Column(
      children: [
        _buildPaymentInfo(),
        Expanded(
          child: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..setNavigationDelegate(
                NavigationDelegate(
                  onPageStarted: (String url) {
                    print('Payment page started: $url');
                  },
                  onPageFinished: (String url) {
                    print('Payment page finished: $url');
                    _handlePaymentResult(url);
                  },
                  onNavigationRequest: (NavigationRequest request) {
                    print('Navigation request: ${request.url}');
                    _handlePaymentResult(request.url);
                    return NavigationDecision.navigate;
                  },
                ),
              )
              ..loadRequest(Uri.parse(_paymentUrl!)),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ödeme Detayları',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ders:'),
              Text(
                widget.reservation.subject,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Öğretmen:'),
              Text(
                widget.reservation.teacher?.name ?? 'Bilinmiyor',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Süre:'),
              Text(
                '${widget.reservation.durationMinutes} dakika',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Toplam Tutar:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${widget.amount.toStringAsFixed(2)} ₺',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handlePaymentResult(String url) {
    print('Handling payment result: $url');

    if (url.contains('/payment/success') || url.contains('success=true')) {
      // Ödeme başarılı
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentSuccessScreen(
            reservation: widget.reservation,
            amount: widget.amount,
          ),
        ),
      );
    } else if (url.contains('/payment/fail') || url.contains('fail=true')) {
      // Ödeme başarısız
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentFailedScreen(
            reservation: widget.reservation,
            amount: widget.amount,
          ),
        ),
      );
    }
  }
}
