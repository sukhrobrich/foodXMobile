import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/api.dart';
import '../core/config.dart';
import 'tables_screen.dart';
import 'setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isOffline = false;

  // ── Online ────────────────────────────────────────────
  final _cafeCtrl  = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool    _cafeLoading  = false;
  int?    _tenantId;
  String? _cafeName;
  String? _cafeError;
  bool    _loginLoading = false;
  bool    _obscure      = true;
  String? _loginError;
  String? _warning;

  // ── Offline ───────────────────────────────────────────
  final _ipCtrl   = TextEditingController();
  final _portCtrl = TextEditingController(text: '5050');
  bool    _offLoading   = false;
  String? _offError;
  List<dynamic> _staff  = [];
  int?    _offTenantId;
  String? _connectedUrl;

  @override
  void initState() {
    super.initState();
    _loadSavedCafe();
    _loadSavedIp();
  }

  @override
  void dispose() {
    _cafeCtrl.dispose();
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  // ── Online init ───────────────────────────────────────
  Future<void> _loadSavedCafe() async {
    final code = await AppConfig.getCafeCode();
    final name = await AppConfig.getCafeName();
    if (code != null && code.isNotEmpty) {
      _cafeCtrl.text = code;
      if (name != null && name.isNotEmpty)
        setState(() => _cafeName = name);
    }
  }

  // ── Offline init ──────────────────────────────────────
  Future<void> _loadSavedIp() async {
    final localUrl = await AppConfig.getLocalUrl();
    if (localUrl != null && localUrl.isNotEmpty) {
      final uri = Uri.tryParse(localUrl);
      if (uri != null && uri.host.isNotEmpty)
        _ipCtrl.text = uri.host;
    }
  }

  // ── Online: kafe tekshirish ───────────────────────────
  bool get _cafeFound => _tenantId != null;

  Future<void> _checkCafe() async {
    final q = _cafeCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _cafeLoading = true; _cafeError = null;
      _tenantId = null; _cafeName = null;
      _loginError = null; _warning = null;
      _loginCtrl.clear(); _passCtrl.clear();
    });
    try {
      final primaryUrl = await AppConfig.getBaseUrl();
      Api.resetActiveBase();
      final res      = await Api.get('auth/cafe?q=${Uri.encodeComponent(q)}');
      final tenantId = res['tenantId'] as int;
      final cafeName = (res['cafeName'] ?? '').toString();
      final activeUrl    = Api.activeBaseUrl;
      final usedFallback = activeUrl != null && activeUrl != primaryUrl;
      await AppConfig.saveCafe(q, cafeName);
      setState(() {
        _tenantId = tenantId; _cafeName = cafeName;
        if (usedFallback)
          _warning = 'Asosiy server offline. Mahalliy tarmoq orqali ulandi.';
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) FocusScope.of(context).nextFocus();
      });
    } on ApiException catch (e) {
      final hasLocal = (await AppConfig.getLocalUrl())?.isNotEmpty == true;
      setState(() {
        _cafeError = (e.statusCode == 404)
            ? 'Bunday kafe mavjud emas.'
            : (e.statusCode != null)
                ? e.message
                : hasLocal
                    ? 'Serverga ulanib bo\'lmadi.\nKompyuter bilan bir xil Wi-Fi da bo\'ling.'
                    : 'Serverga ulanib bo\'lmadi.';
      });
    } finally {
      if (mounted) setState(() => _cafeLoading = false);
    }
  }

  // ── Online: login ─────────────────────────────────────
  Future<void> _login() async {
    if (!_cafeFound) return;
    if (_loginCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) return;
    setState(() { _loginLoading = true; _loginError = null; });
    try {
      final res = await Api.post('auth/login', {
        'login':    _loginCtrl.text.trim(),
        'password': _passCtrl.text,
        'tenantId': _tenantId!,
      });
      await AppConfig.setToken(res['token'] as String);
      await AppConfig.setTenantId(_tenantId!);
      final user = res['user'] as Map<String, dynamic>;
      await AppConfig.saveUser(
          _toInt(user['id']),
          (user['name'] ?? '').toString(),
          (user['role'] ?? '').toString());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TablesScreen()));
    } on ApiException catch (e) {
      setState(() => _loginError =
          e.statusCode == 401 ? 'Login yoki parol noto\'g\'ri' : e.message);
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  // ── Offline: ulanish ──────────────────────────────────
  String _buildUrl(String ip) {
    final s    = ip.trim();
    final port = _portCtrl.text.trim().isEmpty ? '5050' : _portCtrl.text.trim();
    if (s.isEmpty) return AppConfig.centralUrl;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return 'http://$s:$port';
  }

  Future<void> _offConnect() async {
    final url = _buildUrl(_ipCtrl.text);
    setState(() {
      _offLoading   = true; _offError = null;
      _staff        = []; _offTenantId = null; _connectedUrl = null;
    });
    try {
      final result = await Api.getStaffList(url);
      final tid    = result['tenantId'];
      setState(() {
        _staff        = result['staff'] as List<dynamic>? ?? [];
        _offTenantId  = (tid is int) ? tid : int.tryParse(tid.toString());
        _connectedUrl = url;
      });
      if (_ipCtrl.text.trim().isNotEmpty)
        await AppConfig.setLocalUrl(url);
    } on ApiException catch (e) {
      setState(() => _offError = e.message);
    } catch (_) {
      setState(() => _offError =
          'Serverga ulanib bo\'lmadi. IP manzilni tekshiring.');
    } finally {
      if (mounted) setState(() => _offLoading = false);
    }
  }

  // ── Offline: ismga bosganda parol so'rash ─────────────
  Future<void> _loginAs(Map<String, dynamic> member) async {
    if (_connectedUrl == null || _offTenantId == null) return;
    final name  = (member['name']  ?? '').toString();
    final login = (member['login'] ?? '').toString();

    final password = await _showPasswordSheet(name);
    if (password == null || password.isEmpty) return;

    setState(() { _offLoading = true; _offError = null; });
    try {
      final res  = await Api.loginDirect(_connectedUrl!, login, password, _offTenantId!);
      final user = res['user'] as Map<String, dynamic>;
      await AppConfig.setToken(res['token'] as String);
      await AppConfig.setTenantId(_offTenantId!);
      await AppConfig.saveUser(
          _toInt(user['id']),
          (user['name'] ?? '').toString(),
          (user['role'] ?? '').toString());
      Api.resetActiveBase();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TablesScreen()));
    } on ApiException catch (e) {
      setState(() => _offError = e.message);
    } finally {
      if (mounted) setState(() => _offLoading = false);
    }
  }

  // ── Parol kiritish bottom sheet ───────────────────────
  Future<String?> _showPasswordSheet(String name) {
    final ctrl   = TextEditingController();
    bool  obscure = true;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.person_outline,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => Navigator.of(ctx).pop(v),
                decoration: InputDecoration(
                  hintText: 'Parol',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: AppColors.textMuted, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                        size: 20),
                    onPressed: () => setSS(() => obscure = !obscure),
                  ),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(ctrl.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Kirish',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _toInt(dynamic v) => (v is int) ? v : int.tryParse(v.toString()) ?? 0;

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Scroll qilinadigan asosiy kontent
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sozlamalar tugmasi
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined,
                            color: AppColors.textMuted),
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SetupScreen())),
                      ),
                    ),

                    // Logo
                    Center(
                      child: Column(children: [
                        Container(
                          width: 76, height: 76,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primary.withAlpha(60),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6))
                            ],
                          ),
                          child: const Icon(Icons.restaurant_menu,
                              color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 14),
                        const Text('FoodX',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark)),
                        const SizedBox(height: 4),
                        const Text('Ofitsiant ilovasi',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted)),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    // Kontent
                    if (!_isOffline)
                      _buildOnlineContent()
                    else
                      _buildOfflineContent(),
                  ],
                ),
              ),
            ),

            // Online / Offline tab bar
            _buildTabBar(),
          ],
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(children: [
        Expanded(child: _tabBtn('Online', Icons.wifi, !_isOffline)),
        const SizedBox(width: 12),
        Expanded(child: _tabBtn('Offline', Icons.wifi_off, _isOffline)),
      ]),
    );
  }

  Widget _tabBtn(String label, IconData icon, bool selected) {
    return GestureDetector(
      onTap: () => setState(() {
        _isOffline  = (label == 'Offline');
        _cafeError  = null;
        _loginError = null;
        _offError   = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  // ── Online kontent ────────────────────────────────────
  Widget _buildOnlineContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kirish',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 20),

          // Kafe nomi
          _label('Kafe nomi'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _cafeCtrl,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _checkCafe(),
                onChanged: (_) => setState(() {
                  _tenantId = null; _cafeName = null;
                  _cafeError = null; _loginError = null; _warning = null;
                }),
                decoration: _inputDec(
                  'Kafe nomi yoki kodi',
                  Icons.store_outlined,
                  suffix: _cafeFound
                      ? const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(Icons.check_circle,
                              color: AppColors.success, size: 20))
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _cafeLoading ? null : _checkCafe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withAlpha(100),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _cafeLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Tekshir',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
              ),
            ),
          ]),

          if (_cafeFound) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.success.withAlpha(80)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Topildi: $_cafeName',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
          if (_cafeError != null) ...[
            const SizedBox(height: 10),
            _errorBox(_cafeError!),
          ],
          if (_warning != null) ...[
            const SizedBox(height: 10),
            _warningBox(_warning!),
          ],
          const SizedBox(height: 20),

          // Login
          _label('Login'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _loginCtrl,
            enabled: _cafeFound,
            textInputAction: TextInputAction.next,
            decoration: _inputDec('login', Icons.person_outline),
          ),
          const SizedBox(height: 16),

          // Parol
          _label('Parol'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passCtrl,
            enabled: _cafeFound,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
            decoration: _inputDec(
              'parol',
              Icons.lock_outline,
              suffix: _cafeFound
                  ? IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          if (_loginError != null) ...[
            _errorBox(_loginError!),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  (_cafeFound && !_loginLoading) ? _login : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withAlpha(60),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _loginLoading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Kirish',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Offline kontent ───────────────────────────────────
  Widget _buildOfflineContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // IP + Port qatori
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _ipCtrl,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _offConnect(),
              decoration: InputDecoration(
                hintText: '192.168.X.X',
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.computer_outlined,
                    color: AppColors.textMuted, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextField(
              controller: _portCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _offConnect(),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '5050',
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _offLoading ? null : _offConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withAlpha(100),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _offLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Kirish',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
            ),
          ),
        ]),

        if (_offError != null) ...[
          const SizedBox(height: 12),
          _errorBox(_offError!),
        ],

        if (_staff.isNotEmpty) ...[
          const SizedBox(height: 24),
          ..._staff
              .map((s) => _staffCard(s as Map<String, dynamic>)),
        ],
      ],
    );
  }

  // ── Ofitsiant kartochkasi ─────────────────────────────
  Widget _staffCard(Map<String, dynamic> member) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _offLoading ? null : () => _loginAs(member),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              const Icon(Icons.person_outline,
                  color: AppColors.textMuted, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (member['name'] ?? '').toString(),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark),
                ),
              ),
              Text(
                (member['role_type'] ?? 'ofitsiant').toString(),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Yordamchi widgetlar ───────────────────────────────
  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted));

  Widget _errorBox(String msg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.danger.withAlpha(80)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.danger, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.danger))),
          ],
        ),
      );

  Widget _warningBox(String msg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFFFFB300).withAlpha(160)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: Color(0xFFFF8F00), size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7B5800),
                        fontWeight: FontWeight.w500))),
          ],
        ),
      );

  InputDecoration _inputDec(String hint, IconData icon,
          {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: AppColors.border.withAlpha(100))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.danger, width: 1.5)),
      );
}