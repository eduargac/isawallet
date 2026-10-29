import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models/transaccion.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/backup_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Transaccion> _transacciones = [];
  double _totalIngresos = 0.0;
  double _totalEgresos = 0.0;
  double _balance = 0.0;
  bool _isLoading = true;
  bool _mostrarFormulario = false;
  String _tipoFormulario = 'egreso';
  Transaccion? _transaccionAEditar;

  String _filtroActivo = 'todos'; // 'todos', 'ingreso', 'egreso'
  String _filtroFecha = 'todo'; // 'todo', 'este_mes', 'mes_pasado'
  String _busquedaQuery = '';
  int _selectedBottomNav = 0;
  String _simboloMoneda = '\$';

  final TextEditingController _searchController = TextEditingController();

  final Map<String, IconData> _iconosCategoria = {
    'Alimentación': Icons.restaurant_rounded,
    'Transporte': Icons.directions_bus_rounded,
    'Servicios': Icons.receipt_long_rounded,
    'Ocio': Icons.sports_esports_rounded,
    'Salud': Icons.local_hospital_rounded,
    'Educación': Icons.school_rounded,
    'Salario': Icons.account_balance_wallet_rounded,
    'Inversiones': Icons.trending_up_rounded,
    'Ventas': Icons.storefront_rounded,
    'Regalo': Icons.card_giftcard_rounded,
    'Otros': Icons.category_rounded,
  };

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getTransacciones();
    final balanceMap = await DatabaseHelper.instance.getBalance();

    if (mounted) {
      setState(() {
        _transacciones = list;
        _totalIngresos = balanceMap['ingresos'] ?? 0.0;
        _totalEgresos = balanceMap['egresos'] ?? 0.0;
        _balance = balanceMap['balance'] ?? 0.0;
        _isLoading = false;
      });
    }
  }

  void _alternarFormulario([String tipo = 'egreso', Transaccion? item]) {
    setState(() {
      if (item != null) {
        _transaccionAEditar = item;
        _tipoFormulario = item.tipo;
        _mostrarFormulario = true;
      } else if (_mostrarFormulario && _tipoFormulario == tipo && _transaccionAEditar == null) {
        _mostrarFormulario = false;
      } else {
        _transaccionAEditar = null;
        _mostrarFormulario = true;
        _tipoFormulario = tipo;
      }
    });
  }

  void _abrirRespaldoDrive() {
    showDialog(
      context: context,
      builder: (_) => BackupDialog(
        onBackupRestored: _cargarDatos,
      ),
    );
  }

  Future<void> _eliminarTransaccion(Transaccion transaccion) async {
    if (transaccion.id != null) {
      await DatabaseHelper.instance.deleteTransaccion(transaccion.id!);
      _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transacción eliminada'),
            backgroundColor: Color(0xFF000000),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _exportarCSV() async {
    final csv = await DatabaseHelper.instance.exportarACSV();
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Exportación CSV', style: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: SelectableText(
              csv,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF000000)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CERRAR', style: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  List<Transaccion> get _transaccionesFiltradas {
    final now = DateTime.now();

    return _transacciones.where((t) {
      if (_filtroActivo == 'ingreso' && !t.esIngreso) return false;
      if (_filtroActivo == 'egreso' && !t.esEgreso) return false;

      if (_filtroFecha == 'este_mes') {
        if (t.fecha.month != now.month || t.fecha.year != now.year) return false;
      } else if (_filtroFecha == 'mes_pasado') {
        final mesPasado = DateTime(now.year, now.month - 1);
        if (t.fecha.month != mesPasado.month || t.fecha.year != mesPasado.year) return false;
      }

      if (_busquedaQuery.trim().isNotEmpty) {
        final query = _busquedaQuery.trim().toLowerCase();
        final catMatches = t.categoria.toLowerCase().contains(query);
        final notaMatches = t.nota?.toLowerCase().contains(query) ?? false;
        final montoMatches = t.monto.toString().contains(query);
        return catMatches || notaMatches || montoMatches;
      }

      return true;
    }).toList();
  }

  NumberFormat get _currencyFormat => NumberFormat.currency(
        symbol: _simboloMoneda,
        decimalDigits: 2,
        locale: 'es_CO',
      );

  Widget _buildPillOption(String value, String label, {bool isFecha = false}) {
    final isSelected = isFecha ? _filtroFecha == value : _filtroActivo == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isFecha) {
            _filtroFecha = value;
          } else {
            _filtroActivo = value;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF000000) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF000000),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 68,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.grid_view_rounded, 'Inicio'),
          _buildNavItem(1, Icons.history_rounded, 'Historial'),
          _buildNavItem(2, Icons.analytics_outlined, 'Estadísticas'),
          _buildNavItem(3, Icons.settings_rounded, 'Ajustes'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedBottomNav == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBottomNav = index;
        });
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFF000000) : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 5 : 0,
              height: isSelected ? 5 : 0,
              decoration: const BoxDecoration(
                color: Color(0xFF0F4B8E),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticasView() {
    final Map<String, double> totalesEgresos = {};
    double totalEgresosSum = 0.0;

    for (var t in _transacciones) {
      if (t.esEgreso) {
        totalesEgresos[t.categoria] = (totalesEgresos[t.categoria] ?? 0.0) + t.monto;
        totalEgresosSum += t.monto;
      }
    }

    final sortedCat = totalesEgresos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Desglose por Categoría',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 16),
          if (sortedCat.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text('No hay egresos registrados para analizar.'),
              ),
            )
          else
            Column(
              children: sortedCat.map((entry) {
                final pct = totalEgresosSum > 0 ? (entry.value / totalEgresosSum) : 0.0;
                final pctText = (pct * 100).toStringAsFixed(1);
                final icono = _iconosCategoria[entry.key] ?? Icons.category_rounded;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(icono, color: const Color(0xFF0F4B8E), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF000000),
                              ),
                            ),
                          ),
                          Text(
                            _currencyFormat.format(entry.value),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFF0F4F8),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F4B8E)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$pctText%',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _exportarCSV,
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              label: const Text('EXPORTAR HISTORIAL A CSV', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000000),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAjustesView() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ajustes de la Aplicación',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.currency_exchange_rounded, color: Color(0xFF0F4B8E)),
                  title: const Text('Símbolo de Moneda', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000000))),
                  subtitle: Text('Moneda actual: $_simboloMoneda'),
                  trailing: DropdownButton<String>(
                    value: _simboloMoneda,
                    items: const [
                      DropdownMenuItem(value: '\$', child: Text('\$ (Pesos / Dólares)')),
                      DropdownMenuItem(value: '€', child: Text('€ (Euros)')),
                      DropdownMenuItem(value: 'S/', child: Text('S/ (Soles)')),
                      DropdownMenuItem(value: 'MXN\$', child: Text('MXN\$ (Pesos MX)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _simboloMoneda = val;
                        });
                      }
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF0F4B8E)),
                  title: const Text('Respaldo en Google Drive', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000000))),
                  subtitle: const Text('Guarda y restaura tu base de datos'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF000000)),
                  onTap: _abrirRespaldoDrive,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0F4B8E),
          onRefresh: _cargarDatos,
          child: CustomScrollView(
            slivers: [
              // Header Superior (Greeting + User Profile Avatar)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Row(
                            children: [
                              Text(
                                'Hola, Isa',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF000000),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text('👋', style: TextStyle(fontSize: 22)),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Explora y gestiona tus finanzas',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _abrirRespaldoDrive,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFF000000),
                            child: Icon(
                              Icons.cloud_sync_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Vista Principal (Tab 0) o Vista Secundaria
              if (_selectedBottomNav == 2)
                SliverToBoxAdapter(child: _buildEstadisticasView())
              else if (_selectedBottomNav == 3)
                SliverToBoxAdapter(child: _buildAjustesView())
              else ...[
                // Campo de Búsqueda ("Search places" design)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Color(0xFF000000)),
                        onChanged: (val) {
                          setState(() {
                            _busquedaQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Buscar movimientos...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF0F4B8E),
                            size: 22,
                          ),
                          suffixIcon: _busquedaQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Color(0xFF000000)),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _busquedaQuery = '';
                                    });
                                  },
                                )
                              : Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F4F8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    size: 18,
                                    color: Color(0xFF000000),
                                  ),
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Tarjeta de Balance Principal (Deep Royal Blue & Navy Gradient)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF051D3B),
                            Color(0xFF0F4B8E),
                            Color(0xFF1565C0),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F4B8E).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Balance Total',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'isaWallet',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currencyFormat.format(_balance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                // Total Ingresos
                                Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _alternarFormulario('ingreso'),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF0F4B8E),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.arrow_downward_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Ingresos',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      _currencyFormat.format(_totalIngresos),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Total Egresos
                                Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _alternarFormulario('egreso'),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF000000),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.arrow_upward_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Egresos',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      _currencyFormat.format(_totalEgresos),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Formulario Integrado (Inline Form)
                if (_mostrarFormulario)
                  SliverToBoxAdapter(
                    child: AddTransactionSheet(
                      initialTipo: _tipoFormulario,
                      transaccionAEditar: _transaccionAEditar,
                      onTransactionAdded: () {
                        _cargarDatos();
                        setState(() {
                          _mostrarFormulario = false;
                          _transaccionAEditar = null;
                        });
                      },
                      onCancel: () {
                        setState(() {
                          _mostrarFormulario = false;
                          _transaccionAEditar = null;
                        });
                      },
                    ),
                  ),

                // Filtro por Fecha (si está en la pestaña Historial)
                if (_selectedBottomNav == 1)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPillOption('todo', 'Todo el historial', isFecha: true),
                            const SizedBox(width: 6),
                            _buildPillOption('este_mes', 'Este mes', isFecha: true),
                            const SizedBox(width: 6),
                            _buildPillOption('mes_pasado', 'Mes pasado', isFecha: true),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Fila de Filtros por Tipo de Movimiento
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Movimientos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000000),
                          ),
                        ),
                        Row(
                          children: [
                            _buildPillOption('todos', 'Todos'),
                            const SizedBox(width: 6),
                            _buildPillOption('ingreso', 'Ingresos'),
                            const SizedBox(width: 6),
                            _buildPillOption('egreso', 'Egresos'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Lista de Transacciones o Estado Vacío
                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF000000)),
                    ),
                  )
                else if (_transaccionesFiltradas.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                size: 50,
                                color: Color(0xFF0F4B8E),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay registros aún',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF000000),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Toca el botón + para registrar tu primer ingreso o egreso',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _transaccionesFiltradas[index];
                          final icono = _iconosCategoria[item.categoria] ?? Icons.category_rounded;
                          final isIngreso = item.esIngreso;
                          final colorMonto = isIngreso
                              ? const Color(0xFF0F4B8E)
                              : const Color(0xFF000000);

                          return Dismissible(
                            key: Key('transaccion_${item.id}_${item.fecha}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF000000),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.centerRight,
                              child: const Icon(Icons.delete_rounded, color: Colors.white),
                            ),
                            onDismissed: (_) => _eliminarTransaccion(item),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                onTap: () => _alternarFormulario(item.tipo, item),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF0F4F8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icono, color: colorMonto, size: 22),
                                ),
                                title: Text(
                                  item.categoria,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF000000),
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.nota != null && item.nota!.isNotEmpty)
                                      Text(
                                        item.nota!,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13,
                                        ),
                                      ),
                                    Text(
                                      DateFormat('dd/MM/yyyy • HH:mm').format(item.fecha),
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${isIngreso ? '+' : '-'} ${_currencyFormat.format(item.monto)}',
                                      style: TextStyle(
                                        color: colorMonto,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF94A3B8)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: _transaccionesFiltradas.length,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _alternarFormulario('egreso'),
        backgroundColor: const Color(0xFF000000),
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        child: Icon(
          _mostrarFormulario ? Icons.close_rounded : Icons.add_rounded,
          size: 28,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
