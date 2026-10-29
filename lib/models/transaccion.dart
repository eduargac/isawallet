class Transaccion {
  final int? id;
  final double monto;
  final String categoria;
  final String tipo; // 'ingreso' o 'egreso'
  final DateTime fecha;
  final String? nota;

  Transaccion({
    this.id,
    required this.monto,
    required this.categoria,
    required this.tipo,
    required this.fecha,
    this.nota,
  });

  bool get esIngreso => tipo == 'ingreso';
  bool get esEgreso => tipo == 'egreso';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'monto': monto,
      'categoria': categoria,
      'tipo': tipo,
      'fecha': fecha.toIso8601String(),
      'nota': nota,
    };
  }

  factory Transaccion.fromMap(Map<String, dynamic> map) {
    return Transaccion(
      id: map['id'] as int?,
      monto: (map['monto'] as num).toDouble(),
      categoria: map['categoria'] as String? ?? 'Otros',
      tipo: map['tipo'] as String? ?? 'egreso',
      fecha: DateTime.tryParse(map['fecha'] as String? ?? '') ?? DateTime.now(),
      nota: map['nota'] as String?,
    );
  }
}
