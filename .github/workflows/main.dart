import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ftpconnect/ftpconnect.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PS4 FTP',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true)
            .copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark)),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final ip = TextEditingController();
  final port = TextEditingController(text: '2121');
  final path = TextEditingController(text: '/data/pkg');
  FTPConnect? ftp;
  bool connected = false, busy = false;
  double progress = 0;
  String current = '';
  final logs = <String>[];
  List<FTPEntry> entries = [];

  void log(String m) => setState(() => logs.insert(0, m));

  Future<void> connect() async {
    setState(() => busy = true);
    try {
      ftp = FTPConnect(ip.text.trim(),
          port: int.parse(port.text.trim()), user: 'anonymous', pass: '', timeout: 30);
      await ftp!.connect();
      connected = true;
      log('Conectado a ${ip.text}');
      await refresh();
    } catch (e) {
      log('Error al conectar: $e');
    }
    setState(() => busy = false);
  }

  Future<void> disconnect() async {
    try { await ftp?.disconnect(); } catch (_) {}
    setState(() { connected = false; entries = []; });
    log('Desconectado');
  }

  Future<void> goToPath() async {
    await ftp!.changeDirectory('/');
    for (final p in path.text.split('/').where((s) => s.isNotEmpty)) {
      if (!await ftp!.changeDirectory(p)) {
        await ftp!.makeDirectory(p);
        await ftp!.changeDirectory(p);
      }
    }
  }

  Future<void> refresh() async {
    try {
      await goToPath();
      final l = await ftp!.listDirectoryContent();
      setState(() => entries = l);
    } catch (e) {
      log('Error al listar: $e');
    }
  }

  Future<void> upload() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    setState(() => busy = true);
    try {
      await goToPath();
      for (final f in res.files) {
        if (f.path == null) continue;
        setState(() { current = f.name; progress = 0; });
        final ok = await ftp!.uploadFile(File(f.path!),
            sRemoteName: f.name,
            onProgress: (pct, _, __) => setState(() => progress = pct / 100));
        log(ok ? 'Subido: ${f.name}' : 'Falló: ${f.name}');
      }
      await refresh();
    } catch (e) {
      log('Error al subir: $e');
    }
    setState(() { busy = false; current = ''; progress = 0; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PS4 · GoldHEN FTP')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(
              flex: 3,
              child: TextField(
                  controller: ip,
                  enabled: !connected,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'IP de la PS4', hintText: '192.168.1.50'))),
          const SizedBox(width: 12),
          Expanded(
              child: TextField(
                  controller: port,
                  enabled: !connected,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Puerto'))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: path, decoration: const InputDecoration(labelText: 'Carpeta destino')),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: FilledButton(
                  onPressed: busy ? null : (connected ? disconnect : connect),
                  child: Text(connected ? 'Desconectar' : 'Conectar'))),
          if (connected) ...[
            const SizedBox(width: 12),
            Expanded(
                child: FilledButton.tonal(
                    onPressed: busy ? null : upload, child: const Text('Subir archivos'))),
            IconButton(onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh)),
          ]
        ]),
        if (current.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(current, overflow: TextOverflow.ellipsis),
          LinearProgressIndicator(value: progress),
          Text('${(progress * 100).toStringAsFixed(0)}%'),
        ],
        if (entries.isNotEmpty) ...[
          const Divider(height: 32),
          const Text('Contenido', style: TextStyle(fontWeight: FontWeight.bold)),
          ...entries.map((e) => ListTile(
              dense: true,
              leading: Icon(e.type == FTPEntryType.DIR ? Icons.folder : Icons.insert_drive_file),
              title: Text(e.name),
              subtitle: e.size != null ? Text('${(e.size! / 1048576).toStringAsFixed(1)} MB') : null)),
        ],
        const Divider(height: 32),
        const Text('Registro', style: TextStyle(fontWeight: FontWeight.bold)),
        ...logs.take(20).map((l) => Text(l, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}
