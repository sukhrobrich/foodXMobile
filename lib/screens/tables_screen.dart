import 'dart:async';
import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/config.dart';
import '../core/api.dart';
import '../models/place.dart';
import 'login_screen.dart';
import 'menu_screen.dart';
import 'my_orders_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  int    _navIndex = 0;
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = (await AppConfig.getUserRole()) ?? '';
    if (mounted) setState(() => _userRole = role);
  }

  bool get _isKassir => _userRole == 'kassir' || _userRole == 'admin';

  void _onTabTap(int i) {
    setState(() => _navIndex = i);
    if (i == 1) MyOrdersScreen.refreshIfMounted();
    if (i == 2) AllOrdersScreen.refreshIfMounted();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _TablesTab(),
      MyOrdersScreen(key: MyOrdersScreen.instanceKey),
      if (_isKassir) AllOrdersScreen(key: AllOrdersScreen.instanceKey),
    ];

    // Agar rol o'zgarsa va hozirgi index chegaradan chiqib qolsa
    final safeIndex = _navIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: _onTabTap,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.table_restaurant_outlined),
              activeIcon: Icon(Icons.table_restaurant),
              label: 'Stollar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Buyurtmalarim',
            ),
            if (_isKassir)
              const BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_outlined),
                activeIcon: Icon(Icons.list_alt),
                label: 'Barcha buyurtmalar',
              ),
          ],
        ),
      ),
    );
  }
}

// ── Stollar tab ───────────────────────────────────────────────────────────────

class _TablesTab extends StatefulWidget {
  const _TablesTab();

  @override
  State<_TablesTab> createState() => _TablesTabState();
}

class _TablesTabState extends State<_TablesTab> with WidgetsBindingObserver {
  List<Place> _places     = [];
  List<String> _zones     = [];
  String? _selectedZone;

  String _userName    = '';
  String _cafeName    = '';
  String _userRole    = '';
  int    _userId      = 0;
  bool   _anyoneClose = false;

  bool   _loading    = true;   // birinchi yuklash
  bool   _refreshing = false;  // background refresh
  String? _error;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _silentRefresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _silentRefresh();
  }

  Future<void> _init() async {
    _userName = (await AppConfig.getUserName()) ?? '';
    _cafeName = (await AppConfig.getCafeName()) ?? '';
    _userRole = (await AppConfig.getUserRole()) ?? '';
    _userId   = await AppConfig.getUserId();
    try {
      final res = await Api.get('settings/value?key=order_anyone_close');
      _anyoneClose = (res['value'] ?? '') == '1';
    } catch (_) {}
    setState(() {});
    _load();
  }

  // Birinchi/xato holat uchun — loading spinner ko'rsatadi
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    await _fetch();
    if (mounted) setState(() => _loading = false);
  }

  // Background yangilash — UI bloklanmaydi
  Future<void> _silentRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _fetch();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _fetch() async {
    try {
      final data = await Api.get('places') as List;
      final places = data
          .map((j) => Place.fromJson(j as Map<String, dynamic>))
          .toList();
      final zones = places
          .map((p) => p.zone)
          .where((z) => z.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (mounted) {
        setState(() {
          _places = places;
          _zones  = zones;
          _error  = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && _places.isEmpty) {
        setState(() => _error = e.message);
      }
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

  bool _canOpen(Place place) {
    if (place.empty) return true;
    if (_userRole == 'admin' || _userRole == 'kassir') return true;
    if (_anyoneClose) return true;
    return place.activeOrderUserId == null ||
        place.activeOrderUserId == _userId;
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  _cafeName.isNotEmpty ? _cafeName : 'FoodX',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textDark)),
              if (_cafeName.isNotEmpty)
                const Text('Stollar',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          // Avtomatik yangilash indikatori
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            ),
          if (_userName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
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
          if (_zones.length > 1)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
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
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _error != null && _places.isEmpty
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
                                childAspectRatio: 1.05,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (ctx, i) {
                                final p = _filtered[i];
                                return _TableCard(
                                  place: p,
                                  canOpen: _canOpen(p),
                                  onTap: () => _canOpen(p)
                                      ? _openMenu(p)
                                      : _showLockedMsg(p),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _showLockedMsg(Place p) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '🔒 Bu stol "${p.activeOrderUserName.isNotEmpty ? p.activeOrderUserName : 'boshqa ofitsiant'}" tomonidan ochildi'),
      backgroundColor: AppColors.textDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
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
            Text(_error!,
                textAlign: TextAlign.center,
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
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => MenuScreen(place: place)));
    _silentRefresh();
  }
}

// ── Stol kartochkasi ──────────────────────────────────────────────────────────

class _TableCard extends StatelessWidget {
  final Place place;
  final bool canOpen;
  final VoidCallback onTap;

  const _TableCard(
      {required this.place, required this.canOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final busy   = !place.empty;
    final locked = busy && !canOpen;

    final Color borderColor;
    final Color iconColor;
    final Color bgColor;

    if (locked) {
      borderColor = AppColors.textMuted;
      iconColor   = AppColors.textMuted;
      bgColor     = AppColors.bg;
    } else if (busy) {
      borderColor = AppColors.primary;
      iconColor   = AppColors.primary;
      bgColor     = AppColors.primaryLight;
    } else {
      borderColor = AppColors.success;
      iconColor   = AppColors.success;
      bgColor     = AppColors.successLight;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: borderColor, width: (busy && canOpen) ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: borderColor.withAlpha(25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                        locked
                            ? Icons.lock_outline
                            : busy
                                ? Icons.restaurant
                                : Icons.table_restaurant_outlined,
                        color: iconColor,
                        size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(place.name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: locked
                              ? AppColors.textMuted
                              : AppColors.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 3),
                  if (locked)
                    Text(
                        place.activeOrderUserName.isNotEmpty
                            ? place.activeOrderUserName
                            : 'Band',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)
                  else if (busy)
                    Text(
                        '${place.activeOrderTotal.toStringAsFixed(0)} so\'m',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600))
                  else
                    const Text('Bo\'sh',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.success)),
                  if (place.zone.isNotEmpty)
                    Text(place.zone,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (locked)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock,
                      size: 12, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}