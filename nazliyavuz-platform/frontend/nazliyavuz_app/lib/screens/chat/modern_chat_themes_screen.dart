import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModernChatThemesScreen extends StatefulWidget {
  const ModernChatThemesScreen({Key? key}) : super(key: key);

  @override
  State<ModernChatThemesScreen> createState() => _ModernChatThemesScreenState();
}

class _ModernChatThemesScreenState extends State<ModernChatThemesScreen> {
  String _selectedTheme = 'default';
  String _selectedColor = 'blue';
  bool _isDarkMode = false;

  final List<Map<String, dynamic>> _themes = [
    {
      'id': 'default',
      'name': 'Varsayılan',
      'preview': 'assets/themes/default_preview.png',
      'colors': ['blue', 'green', 'purple', 'red'],
    },
    {
      'id': 'minimal',
      'name': 'Minimal',
      'preview': 'assets/themes/minimal_preview.png',
      'colors': ['grey', 'black', 'white'],
    },
    {
      'id': 'gradient',
      'name': 'Gradient',
      'preview': 'assets/themes/gradient_preview.png',
      'colors': ['blue', 'purple', 'pink', 'orange'],
    },
    {
      'id': 'dark',
      'name': 'Karanlık',
      'preview': 'assets/themes/dark_preview.png',
      'colors': ['dark', 'blue', 'purple'],
    },
  ];

  final List<Map<String, dynamic>> _colors = [
    {'id': 'blue', 'name': 'Mavi', 'primary': Color(0xFF2196F3), 'secondary': Color(0xFFE3F2FD)},
    {'id': 'green', 'name': 'Yeşil', 'primary': Color(0xFF4CAF50), 'secondary': Color(0xFFE8F5E8)},
    {'id': 'purple', 'name': 'Mor', 'primary': Color(0xFF9C27B0), 'secondary': Color(0xFFF3E5F5)},
    {'id': 'red', 'name': 'Kırmızı', 'primary': Color(0xFFF44336), 'secondary': Color(0xFFFFEBEE)},
    {'id': 'orange', 'name': 'Turuncu', 'primary': Color(0xFFFF9800), 'secondary': Color(0xFFFFF3E0)},
    {'id': 'pink', 'name': 'Pembe', 'primary': Color(0xFFE91E63), 'secondary': Color(0xFFFCE4EC)},
    {'id': 'grey', 'name': 'Gri', 'primary': Color(0xFF607D8B), 'secondary': Color(0xFFECEFF1)},
    {'id': 'black', 'name': 'Siyah', 'primary': Color(0xFF212121), 'secondary': Color(0xFF424242)},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTheme = prefs.getString('chat_theme') ?? 'default';
      _selectedColor = prefs.getString('chat_color') ?? 'blue';
      _isDarkMode = prefs.getBool('chat_dark_mode') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_theme', _selectedTheme);
    await prefs.setString('chat_color', _selectedColor);
    await prefs.setBool('chat_dark_mode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Chat Temaları'),
        backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.white,
        foregroundColor: _isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _resetToDefault,
            icon: const Icon(Icons.refresh),
            tooltip: 'Varsayılana Sıfırla',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dark Mode Toggle
            _buildDarkModeToggle(),
            const SizedBox(height: 24),
            
            // Theme Selection
            _buildThemeSection(),
            const SizedBox(height: 24),
            
            // Color Selection
            _buildColorSection(),
            const SizedBox(height: 24),
            
            // Preview Section
            _buildPreviewSection(),
            const SizedBox(height: 24),
            
            // Advanced Options
            _buildAdvancedOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildDarkModeToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: _isDarkMode ? Colors.amber : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Karanlık Mod',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Karanlık tema kullan',
                  style: TextStyle(
                    fontSize: 14,
                    color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isDarkMode,
            onChanged: (value) {
              setState(() {
                _isDarkMode = value;
              });
              _saveSettings();
            },
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tema Seçimi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _themes.length,
          itemBuilder: (context, index) {
            final theme = _themes[index];
            final isSelected = _selectedTheme == theme['id'];
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTheme = theme['id'];
                });
                _saveSettings();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[50] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey[200]!,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getThemeColor(theme['id']),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getThemeIcon(theme['id']),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      theme['name'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.blue[700] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildColorSection() {
    final selectedTheme = _themes.firstWhere((t) => t['id'] == _selectedTheme);
    final availableColors = selectedTheme['colors'] as List<String>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Renk Seçimi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _colors.length,
          itemBuilder: (context, index) {
            final color = _colors[index];
            final isSelected = _selectedColor == color['id'];
            final isAvailable = availableColors.contains(color['id']);
            
            return GestureDetector(
              onTap: isAvailable ? () {
                setState(() {
                  _selectedColor = color['id'];
                });
                _saveSettings();
              } : null,
              child: Container(
                decoration: BoxDecoration(
                  color: color['primary'],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      )
                    : !isAvailable
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lock,
                              color: Colors.white,
                              size: 16,
                            ),
                          )
                        : null,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Önizleme',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildChatPreview(),
        ),
      ],
    );
  }

  Widget _buildChatPreview() {
    final selectedColor = _colors.firstWhere((c) => c['id'] == _selectedColor);
    
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selectedColor['primary'],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Text(
                  'A',
                  style: TextStyle(
                    color: selectedColor['primary'],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Ahmet',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        // Messages
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // Other user message
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Merhaba!',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // Current user message
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedColor['primary'],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Merhaba! Nasılsın?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gelişmiş Seçenekler',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        
        _buildAdvancedOption(
          icon: Icons.palette,
          title: 'Özel Renk',
          subtitle: 'Kendi renginizi seçin',
          onTap: () => _showColorPicker(),
        ),
        
        _buildAdvancedOption(
          icon: Icons.wallpaper,
          title: 'Arka Plan',
          subtitle: 'Özel arka plan resmi',
          onTap: () => _selectBackground(),
        ),
        
        _buildAdvancedOption(
          icon: Icons.font_download,
          title: 'Yazı Tipi',
          subtitle: 'Yazı tipi boyutu ve stili',
          onTap: () => _showFontSettings(),
        ),
      ],
    );
  }

  Widget _buildAdvancedOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[600], size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Color _getThemeColor(String themeId) {
    switch (themeId) {
      case 'default':
        return Colors.blue;
      case 'minimal':
        return Colors.grey;
      case 'gradient':
        return Colors.purple;
      case 'dark':
        return Colors.black;
      default:
        return Colors.blue;
    }
  }

  IconData _getThemeIcon(String themeId) {
    switch (themeId) {
      case 'default':
        return Icons.chat;
      case 'minimal':
        return Icons.minimize;
      case 'gradient':
        return Icons.gradient;
      case 'dark':
        return Icons.dark_mode;
      default:
        return Icons.chat;
    }
  }

  void _resetToDefault() {
    setState(() {
      _selectedTheme = 'default';
      _selectedColor = 'blue';
      _isDarkMode = false;
    });
    _saveSettings();
  }

  void _showColorPicker() {
    // Implement custom color picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Özel renk seçici yakında eklenecek')),
    );
  }

  void _selectBackground() {
    // Implement background selection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Arka plan seçimi yakında eklenecek')),
    );
  }

  void _showFontSettings() {
    // Implement font settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yazı tipi ayarları yakında eklenecek')),
    );
  }
}
