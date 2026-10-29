import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../database_helper.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleDriveService {
  static final GoogleDriveService instance = GoogleDriveService._init();
  GoogleDriveService._init();

  static const String _backupFileName = 'isawallet_backup.db';
  static const List<String> _scopes = [
    drive.DriveApi.driveAppdataScope,
    drive.DriveApi.driveFileScope,
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      _currentUser ??= await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    _currentUser ??= await _googleSignIn.signInSilently();
    _currentUser ??= await _googleSignIn.signIn();
    if (_currentUser == null) return null;

    final authHeaders = await _currentUser!.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    return drive.DriveApi(client);
  }

  /// Sube la base de datos local SQLite a Google Drive
  Future<bool> subirRespaldo() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception('No hay cuenta de Google conectada o autorizada');

    final dbPath = await DatabaseHelper.instance.getDatabasePath();
    final file = File(dbPath);
    if (!await file.exists()) {
      throw Exception('La base de datos local no existe.');
    }

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName' and trashed = false",
    );

    final media = drive.Media(
      file.openRead(),
      await file.length(),
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final existingFileId = fileList.files!.first.id!;
      final driveFile = drive.File();
      await driveApi.files.update(driveFile, existingFileId, uploadMedia: media);
    } else {
      final driveFile = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'];
      await driveApi.files.create(driveFile, uploadMedia: media);
    }

    return true;
  }

  /// Restaura la base de datos desde Google Drive hacia el almacenamiento local
  Future<bool> restaurarRespaldo() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception('No hay cuenta de Google conectada o autorizada');

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName' and trashed = false",
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      throw Exception('No se encontró ninguna copia de seguridad en Google Drive.');
    }

    final backupFileId = fileList.files!.first.id!;
    final drive.Media media = await driveApi.files.get(
      backupFileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final List<int> dataBytes = [];
    await for (final data in media.stream) {
      dataBytes.addAll(data);
    }

    if (dataBytes.isEmpty) {
      throw Exception('El archivo de respaldo en la nube está vacío.');
    }

    await DatabaseHelper.instance.closeDatabase();

    final dbPath = await DatabaseHelper.instance.getDatabasePath();
    final localFile = File(dbPath);
    await localFile.writeAsBytes(dataBytes, flush: true);

    return true;
  }

  /// Obtiene la fecha del último respaldo guardado en la nube
  Future<DateTime?> obtenerFechaUltimoRespaldo() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName' and trashed = false",
        $fields: 'files(id, name, modifiedTime)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.modifiedTime;
      }
    } catch (_) {}
    return null;
  }
}
