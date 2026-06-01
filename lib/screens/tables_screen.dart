import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/config.dart';
import '../core/api.dart';
import '../models/place.dart';
import 'login_screen.dart';
import 'menu_screen.dart';
import 'setup_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  List<Place> _places  = [];
  List<String> _zones  = [];
  String? _selectedZone;
  String _userName     = '';
  bool _loading        = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _userName = (await AppConfig.getUserName()) ?? '';
    setState(() {});
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await Api.get('places') as List;
      final places = data.map((j) => Place.fromJson(j as Map<String, dynamic>)).toList();
      final zones = places.map((p) => p.zone).where((z) => z.isNotEmpty).toSet().toList()..sort();
      setState(() {
        _places  = places;
        _zones   = zones;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
      if (e.statusCode == 401) _doLogout();
    }
  }

  Future<void> _doLogout() async {
    await AppConfig.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  List<Place> get _filtered {
    if (_selectedZone == null) return _places;
    return _places.where((p) => p.zone == _selectedZone).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.restaurant_menu,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('FoodX',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.textDark)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          if (_userName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_userName,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.textMuted, size: 22),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SetupScreen()),
              );
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout,
                color: AppColors.textMuted, size: 22),
            tooltip: 'Chiqish',
            onPressed: _doLogout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Zone filtri
          if (_zones.length > 1)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _zoneChip('Barchasi', null),
                    ..._zones.map((z) => _zoneChip(z, z)),
                  ],
                ),
              ),
            ),

          // Content
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? _buildError()
                    : _filtered.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _load,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.15,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (ctx, i) =>
                                  _TableCard(place: _filtered[i], onTap: () => _openMenu(_filtered[i])),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _load,
        mini: true,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _zoneChip(String label, String? zone) {
    final selected = _selectedZone == zone;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedZone = zone),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.white : AppColors.textMuted)),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Qayta urinish'),
            ),
          ]),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.table_restaurant_outlined,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('Stollar topilmadi',
              style: TextStyle(color: AppColors.textMuted)),
        ]),
      );

  void _openMenu(Place place) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MenuScreen(place: place)),
    );
    _load();
  }
}

// ── Stol kartochkasi ──────────────────────────────────────────────────────────

class _TableCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;

  const _TableCard({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final busy   = !place.empty;
    final color  = busy ? AppColors.primary : AppColors.success;
    final bgColor = busy ? AppColors.primaryLight : AppColors.successLight;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: busy ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                  busy
                      ? Icons.restaurant
                      : Icons.table_restaurant_outlined,
                  color: color,
                  size: 24),
            ),
            const SizedBox(height: 10),
            Text(place.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            if (busy)
              Text(
                  '${place.activeOrderTotal.toStringAsFixed(0)} so\'m',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.primary,
                      fontWeight: FontWeight.w600))
            else
              Text('Bo\'sh',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.success.withAlpha(200))),
            if (place.zone.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(place.zone,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}