import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'burn_engine.dart'; // הקישור למנוע ה-Rust שלנו
import 'package:path/path.dart' as p;

void main() {
  runApp(const NitroBurnApp());
}

class NitroBurnApp extends StatelessWidget {
  const NitroBurnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nitro-Burn',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String? selectedIso;
  String? selectedDevice;

  List<String> availableDrives = ['Scanning...'];

  String partitionScheme = 'GPT';
  String targetSystem = 'UEFI (non CSM)';

  bool isBurning = false;
  double progress = 0.0;
  String statusText = 'Ready';
  String _formatEta(int totalSeconds) {
    if (totalSeconds <= 0) return "00:00";
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _scanRemovableDrives(); // סורק מיד כשהאפליקציה עולה
  }

  // הפונקציה החכמה שסורקת רק כוננים נשלפים בלינוקס
  Future<void> _scanRemovableDrives() async {
    List<String> drives = [];
    final dir = Directory('/sys/block');

    if (await dir.exists()) {
      await for (var entity in dir.list()) {
        final name = entity.path.split('/').last;

        // מסננים רק כונני USB וכרטיסי זיכרון
        if (name.startsWith('sd') || name.startsWith('mmcblk')) {
          try {
            final removableFile = File('${entity.path}/removable');
            if (await removableFile.exists()) {
              final isRemovable = (await removableFile.readAsString()).trim() == '1';

              if (isRemovable) {
                // חישוב הנפח
                final sizeFile = File('${entity.path}/size');
                double sizeGb = 0.0;
                if (await sizeFile.exists()) {
                  final blocks = int.parse((await sizeFile.readAsString()).trim());
                  sizeGb = (blocks * 512) / (1024 * 1024 * 1024);
                }

                // שם המודל
                final modelFile = File('${entity.path}/device/model');
                String modelName = 'USB Drive';
                if (await modelFile.exists()) {
                  modelName = (await modelFile.readAsString()).trim();
                }

                drives.add('/dev/$name - ${sizeGb.toStringAsFixed(1)}GB $modelName');
              }
            }
          } catch (e) {
            // מתעלמים משגיאות הרשאה בקריאת כוננים פנימיים
          }
        }
      }
    }

    setState(() {
      if (drives.isEmpty) {
        availableDrives = ['No USB drives found'];
        selectedDevice = availableDrives.first;
      } else {
        availableDrives = drives;
        selectedDevice = availableDrives.first;
      }
    });
  }

  // בחירת ISO
  Future<void> _pickIso() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['iso', 'img'],
    );

    if (result != null) {
      setState(() {
        selectedIso = result.files.single.path;
      });
    }
  }

  void _startBurn() {
    if (selectedIso == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please select an ISO file first!')),
      );
      return;
    }

    if (selectedDevice == 'Scanning...' || selectedDevice == 'No USB drives found') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please insert a valid USB drive!')),
      );
      return;
    }

    setState(() {
      isBurning = true;
      progress = 0.0;
      statusText = 'Preparing device and starting engine...';
    });

    final actualDevicePath = selectedDevice!.split(' - ').first;
    final exePath = Platform.resolvedExecutable;
    final exeDir = p.dirname(exePath);
    final dynamicLibraryPath = p.join(exeDir, 'libnitro_burn.so');

    BurnEngine.startBurn(
      isoPath: selectedIso!,
      devicePath: actualDevicePath,
      dylibPath: dynamicLibraryPath,
      onProgress: (percent, speedBps, etaSecs) {
        setState(() {
          progress = percent / 100.0;
          double speedMb = speedBps / (1024 * 1024);
          // שימוש בפונקציית הזמן החדשה שלנו!
          statusText = 'Writing... ${percent.toStringAsFixed(1)}% (${speedMb.toStringAsFixed(1)} MB/s) | ETA: ${_formatEta(etaSecs)}';
        });
      },
      onComplete: (success) {
        setState(() {
          isBurning = false;
          progress = success ? 1.0 : 0.0;
          statusText = success ? 'Ready (Completed ✓)' : 'Error: Burn Failed!';
        });

        // הקפצת חלון מפורט למשתמש!
        showDialog(
          context: context,
          barrierDismissible: false, // מכריח את המשתמש ללחוץ על OK
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(success ? '🎉 Burn Complete!' : '❌ Burn Failed'),
              content: Text(success
              ? 'The image was successfully written to the USB drive.\nYou can now safely remove the device.'
              : 'An error occurred during the burn process. Check your permissions and try again.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }









  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nitro-Burn', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Drives',
            onPressed: isBurning ? null : _scanRemovableDrives,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Drive Properties'),
            const SizedBox(height: 8),
            _buildDropdown(
              label: 'Device',
              value: selectedDevice,
              items: availableDrives,
              onChanged: isBurning ? null : (val) => setState(() => selectedDevice = val),
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Boot selection',
                    value: selectedIso ?? 'No ISO selected...',
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isBurning ? null : _pickIso,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('SELECT'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Partition scheme',
                    value: partitionScheme,
                    items: ['MBR', 'GPT'],
                    onChanged: isBurning ? null : (val) => setState(() => partitionScheme = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown(
                    label: 'Target system',
                    value: targetSystem,
                    items: ['BIOS (or UEFI-CSM)', 'UEFI (non CSM)'],
                    onChanged: isBurning ? null : (val) => setState(() => targetSystem = val!),
                  ),
                ),
              ],
            ),

            const Divider(height: 32),
            _buildSectionTitle('Format Options'),
            const SizedBox(height: 8),
            _buildTextField(
              label: 'Volume label',
              value: 'NITRO_BOOT',
              enabled: !isBurning,
            ),
            const SizedBox(height: 16),

            const Spacer(),

            Text(statusText, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 24,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Colors.grey.withOpacity(0.2),
              color: progress == 1.0 ? Colors.green : Colors.blue,
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('Advanced'),
                  onPressed: isBurning ? null : () {},
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: isBurning ? null : () {},
                      child: const Text('CLOSE'),
                    ),
                    const SizedBox(width: 8),

                    ElevatedButton(
                      // אם צורב - הכפתור מנוטרל לגמרי (null) כדי למנוע הריסת הכונן
                      onPressed: isBurning ? null : _startBurn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBurning ? Colors.grey : Colors.blueAccent,
                        foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      // שינוי הטקסט בהתאם למצב
                      child: Text(isBurning ? 'BURNING...' : 'START'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blueGrey),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      value: items.contains(value) ? value : null,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTextField({
    required String label,
    String? value,
    bool readOnly = false,
    bool enabled = true,
  }) {
    return TextFormField(
      key: ValueKey(value),
      initialValue: value,
      readOnly: readOnly,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.withOpacity(0.1) : null,
      ),
    );
  }
}
