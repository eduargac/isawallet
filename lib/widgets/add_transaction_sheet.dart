import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../database_helper.dart';
import '../models/transaccion.dart';

class AddTransactionSheet extends StatefulWidget {
  final VoidCallback onTransactionAdded;
  final VoidCallback onCancel;
  final String initialTipo;
  final Transaccion? transaccionAEditar;

  const AddTransactionSheet({
    super.key,
    required this.onTransactionAdded,
    required this.onCancel,
    this.initialTipo = 'egreso',
    this.transaccionAEditar,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _notaController = TextEditingController();

  late String _tipo;
  late String _categoria;
  DateTime _fechaSeleccionada = DateTime.now();

  final Map<String, List<Map<String, dynamic>>> _categoriasPorTipo = {
    'egreso': [
      {'nombre': 'Alimentación', 'icono': Icons.restaurant_rounded},
      {'nombre': 'Transporte', 'icono': Icons.directions_bus_rounded},
      {'nombre': 'Servicios', 'icono': Icons.receipt_long_rounded},
      {'nombre': 'Ocio', 'icono': Icons.sports_esports_rounded},
      {'nombre': 'Salud', 'icono': Icons.local_hospital_rounded},
      {'nombre': 'Educación', 'icono': Icons.school_rounded},
      {'nombre': 'Otros', 'icono': Icons.more_horiz_rounded},
    ],
    'ingreso': [
      {'nombre': 'Salario', 'icono': Icons.account_balance_wallet_rounded},
      {'nombre': 'Inversiones', 'icono': Icons.trending_up_rounded},
      {'nombre': 'Ventas', 'icono': Icons.storefront_rounded},
      {'nombre': 'Regalo', 'icono': Icons.card_giftcard_rounded},
      {'nombre': 'Otros', 'icono': Icons.attach_money_rounded},
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.transaccionAEditar != null) {
      final t = widget.transaccionAEditar!;
      _tipo = t.tipo;
      _categoria = t.categoria;
      _fechaSeleccionada = t.fecha;
      _montoController.text = t.monto.toStringAsFixed(2);
      _notaController.text = t.nota ?? '';
    } else {
      _tipo = widget.initialTipo;
      _categoria = _categoriasPorTipo[_tipo]!.first['nombre'] as String;
    }
  }

  void _cambiarTipo(String nuevoTipo) {
    setState(() {
      _tipo = nuevoTipo;
      _categoria = _categoriasPorTipo[_tipo]!.first['nombre'] as String;
    });
  }

  double? _parseMonto(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final cleaned = raw.trim().replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF000000),
              onPrimary: Colors.white,
              onSurface: Color(0xFF000000),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _fechaSeleccionada = picked;
      });
    }
  }

  Future<void> _guardarTransaccion() async {
    if (!_formKey.currentState!.validate()) return;

    final monto = _parseMonto(_montoController.text);
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un monto válido.'),
          backgroundColor: Color(0xFF000000),
        ),
      );
      return;
    }

    final transaccion = Transaccion(
      id: widget.transaccionAEditar?.id,
      monto: monto,
      categoria: _categoria,
      tipo: _tipo,
      fecha: _fechaSeleccionada,
      nota: _notaController.text.trim().isNotEmpty
          ? _notaController.text.trim()
          : null,
    );

    try {
      if (widget.transaccionAEditar != null) {
        await DatabaseHelper.instance.updateTransaccion(transaccion);
      } else {
        await DatabaseHelper.instance.insertTransaccion(transaccion);
      }
      widget.onTransactionAdded();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.transaccionAEditar != null
                  ? '¡Transacción actualizada!'
                  : (_tipo == 'ingreso' ? '¡Ingreso guardado!' : '¡Egreso guardado!'),
            ),
            backgroundColor: const Color(0xFF0F4B8E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la transacción: $e'),
            backgroundColor: Colors.black,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F4B8E);
    final esEdicion = widget.transaccionAEditar != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  esEdicion ? 'Editar Registro' : 'Nuevo Registro',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF000000),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF000000)),
                  onPressed: widget.onCancel,
                  tooltip: 'Cerrar formulario',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Segmented Button para Ingreso / Egreso
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'egreso',
                  label: Text('Egreso'),
                  icon: Icon(Icons.arrow_upward_rounded, color: Color(0xFF000000)),
                ),
                ButtonSegment(
                  value: 'ingreso',
                  label: Text('Ingreso'),
                  icon: Icon(Icons.arrow_downward_rounded, color: Color(0xFF0F4B8E)),
                ),
              ],
              selected: {_tipo},
              onSelectionChanged: (Set<String> newSelection) {
                _cambiarTipo(newSelection.first);
              },
            ),
            const SizedBox(height: 16),
            // Campo de Monto
            TextFormField(
              controller: _montoController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF000000),
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                hintText: '0.00',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF0F4F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Ingresa el monto';
                }
                final parsed = _parseMonto(val);
                if (parsed == null || parsed <= 0) {
                  return 'Monto inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Categorías
            const Text(
              'Categoría',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF000000),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categoriasPorTipo[_tipo]!.map((cat) {
                final nombre = cat['nombre'] as String;
                final icono = cat['icono'] as IconData;
                final selected = _categoria == nombre;

                return ChoiceChip(
                  avatar: Icon(
                    icono,
                    size: 18,
                    color: selected ? Colors.white : const Color(0xFF000000),
                  ),
                  label: Text(nombre),
                  selected: selected,
                  selectedColor: const Color(0xFF000000),
                  backgroundColor: const Color(0xFFF0F4F8),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF000000),
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (bool isSelected) {
                    if (isSelected) {
                      setState(() {
                        _categoria = nombre;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Fecha y Nota
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _seleccionarFecha,
                    icon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF0F4B8E)),
                    label: Text(
                      DateFormat('dd/MM/yyyy').format(_fechaSeleccionada),
                      style: const TextStyle(color: Color(0xFF000000)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF0F4B8E)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notaController,
              style: const TextStyle(color: Color(0xFF000000)),
              decoration: InputDecoration(
                labelText: 'Nota (opcional)',
                labelStyle: const TextStyle(color: Color(0xFF64748B)),
                prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF0F4B8E)),
                filled: true,
                fillColor: const Color(0xFFF0F4F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Botones de Acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF000000)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'CANCELAR',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _guardarTransaccion,
                    icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                    label: Text(
                      esEdicion
                          ? 'ACTUALIZAR'
                          : (_tipo == 'ingreso' ? 'REGISTRAR INGRESO' : 'REGISTRAR EGRESO'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF000000),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
