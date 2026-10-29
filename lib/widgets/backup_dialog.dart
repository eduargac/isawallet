import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../services/google_drive_service.dart';

class BackupDialog extends StatefulWidget {
  final VoidCallback onBackupRestored;

  const BackupDialog({super.key, required this.onBackupRestored});

  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  bool _isLoading = false;
  String? _statusMessage;
  DateTime? _fechaUltimoRespaldo;

  @override
  void initState() {
    super.initState();
    _cargarInfoRespaldo();
  }

  Future<void> _cargarInfoRespaldo() async {
    setState(() => _isLoading = true);
    try {
      final fecha = await GoogleDriveService.instance.obtenerFechaUltimoRespaldo();
      setState(() => _fechaUltimoRespaldo = fecha);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _iniciarSesion() async {
    setState(() => _isLoading = true);
    try {
      final account = await GoogleDriveService.instance.signIn();
      if (account != null) {
        await _cargarInfoRespaldo();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inicio de sesión cancelado o no completado.'),
              backgroundColor: Colors.black,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al conectar con Google: $e'),
            backgroundColor: Colors.black,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cerrarSesion() async {
    await GoogleDriveService.instance.signOut();
    setState(() {
      _fechaUltimoRespaldo = null;
    });
  }

  Future<void> _subirRespaldo() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Subiendo respaldo a Google Drive...';
    });

    try {
      await GoogleDriveService.instance.subirRespaldo();
      await _cargarInfoRespaldo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Respaldo subido con éxito a Google Drive!'),
            backgroundColor: Color(0xFF0F4B8E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al realizar respaldo: $e'),
            backgroundColor: Colors.black,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _restaurarRespaldo() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Restaurando copia desde Google Drive...';
    });

    try {
      await GoogleDriveService.instance.restaurarRespaldo();
      widget.onBackupRestored();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Base de datos restaurada correctamente!'),
            backgroundColor: Color(0xFF0F4B8E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar respaldo: $e'),
            backgroundColor: Colors.black,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = GoogleDriveService.instance.currentUser;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.cloud_sync_rounded, color: Color(0xFF0F4B8E), size: 28),
          SizedBox(width: 10),
          Text(
            'Respaldo en la Nube',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF000000),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentUser == null) ...[
              const Icon(
                Icons.account_circle_outlined,
                size: 60,
                color: Color(0xFF0F4B8E),
              ),
              const SizedBox(height: 12),
              const Text(
                'Conecta tu cuenta de Google Drive para guardar y recuperar tu información local de forma segura.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF000000)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _iniciarSesion,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Conectar con Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000000),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF0F4B8E),
                  backgroundImage: currentUser.photoUrl != null
                      ? NetworkImage(currentUser.photoUrl!)
                      : null,
                  child: currentUser.photoUrl == null
                      ? Text(
                          currentUser.displayName?[0] ?? 'U',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                title: Text(
                  currentUser.displayName ?? 'Usuario Google',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF000000),
                  ),
                ),
                subtitle: Text(
                  currentUser.email,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFF000000)),
                  onPressed: _cerrarSesion,
                  tooltip: 'Desconectar cuenta',
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 18, color: Color(0xFF0F4B8E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fechaUltimoRespaldo != null
                          ? 'Último respaldo: ${DateFormat('dd/MM/yyyy HH:mm').format(_fechaUltimoRespaldo!)}'
                          : 'No hay respaldos previos en Drive',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_statusMessage != null) ...[
                Text(
                  _statusMessage!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F4B8E)),
                ),
                const SizedBox(height: 8),
              ],
              if (_isLoading)
                const LinearProgressIndicator(color: Color(0xFF0F4B8E))
              else ...[
                ElevatedButton.icon(
                  onPressed: _subirRespaldo,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Crear Copia de Seguridad'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000000),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _restaurarRespaldo,
                  icon: const Icon(Icons.cloud_download_rounded),
                  label: const Text('Restaurar desde Drive'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF000000),
                    side: const BorderSide(color: Color(0xFF000000)),
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cerrar',
            style: TextStyle(
              color: Color(0xFF000000),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
