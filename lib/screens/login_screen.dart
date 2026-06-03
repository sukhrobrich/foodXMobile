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
  final _ipCtrl = TextEditingController();

  bool    _loading      = false;
  String? _error;
  List<dynamic> _staff  = [];
  int?    _tenantId;
  String? _cafeName;
  String? _connectedUrl;

  @override
  void initState() {
    super.initState();
    _autoConnect();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoConnect() async {
    final localUrl = await AppConfig.getLocalUrl();
    if (localUrl != null && localUrl.isNotEmpty) {
      final uri = Uri.tryParse(localUrl);
      if (uri != null && uri.host.isNotEmpty) {
        _ipCtrl.text = uri.host;
      }
    }
    await _connect();
  }

  String _buildUrl(String ip) {
    final s = ip.trim();
    if (s.isEmpty) return AppConfig.centralUrl;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return 'http://$s:5050';
  }

  Future<void> _connect() async {
    final url = _buildUrl(_ipCtrl.text);
    setState(() {
      _loading      = true;
      _error        = null;
      _staff        = [];
      _tenantId     = null;
      _connectedUrl = null;
    });

    try {
      final result    = await Api.getStaffList(url);
      final staffList = result['staff'] as List<dynamic>? ?? [];
      final tid       = result['tenantId'];
      final cafeName  = result['cafeName'] as String?;

      setState(() {
        _staff        = staffList;
        _tenantId     = (tid is int) ? tid : int.tryParse(tid.toString());
        _cafeName     = cafeName;
        _connectedUrl = url;
      });

      if (_ipCtrl.text.trim().isNotEmpty) {
        await AppConfig.setLocalUrl(url);
      } else {
        await AppConfig.clearLocalUrl();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Serverga ulanib bo\'lmadi. IP manzilni tekshiring.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginAs(Map<String, dynamic> member) async {
    if (_connectedUrl == null || _tenantId == null) return;
    setState(() { _loading = true; _error = null; });

    try {
      final uid    = member['id'];
      final userId = (uid is int) ? uid : int.parse(uid.toString());

      final res  = await Api.quickLogin(_connectedUrl!, userId, _tenantId!);
      final user = res['user'] as Map<String, dynamic>;

      await AppConfig.setToken(res['token'] as String);
      await AppConfig.setTenantId(_tenantId!);
      await AppConfig.saveUser(
        _toInt(user['id']),
        (user['name'] ?? '').toString(),
        (user['role'] ?? '').toString(),
      );
      Api.resetActiveBase();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TablesScreen()),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _toInt(dynamic v) => (v is int) ? v : int.tryParse(v.toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sozlamalar tugmasi (yuqori o'ng)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SetupScreen()),
                  ),
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
                      boxShadow: [BoxShadow(
                          color: AppColors.primary.withAlpha(60),
                          blurRadius: 16,
                          offset: const Offset(0, 6))],
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
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ]),
              ),
              const SizedBox(height: 28),

              // IP kiritish satrı
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ipCtrl,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _connect(),
                    decoration: InputDecoration(
                      hintText: '192.168.1.100  (mahalliy IP, ixtiyoriy)',
                      hintStyle: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
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
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _connect,
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
                    child: _loading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Ulanish',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                  ),
                ),
              ]),

              // Xato xabari
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.danger.withAlpha(80)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.danger))),
                    ],
                  ),
                ),
              ],

              // Xodimlar ro'yxati
              if (_staff.isNotEmpty) ...[
                const SizedBox(height: 24),
                if (_cafeName != null && _cafeName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_cafeName!,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                  ),
                ..._staff.map(
                    (s) => _staffCard(s as Map<String, dynamic>)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _staffCard(Map<String, dynamic> member) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _loading ? null : () => _loginAs(member),
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
}