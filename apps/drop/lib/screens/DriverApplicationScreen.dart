import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../service/DriverApplicationApi.dart';
import '../service/ModeController.dart';
import '../utils/Colors.dart';

const _maxUploadBytes = 5 * 1024 * 1024;

String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Online driver registration: intro, three short steps, then a status page.
/// Every step is saved on the server when the person presses Next, so they can leave and continue later.
class DriverApplicationScreen extends StatefulWidget {
  const DriverApplicationScreen({Key? key}) : super(key: key);

  @override
  State<DriverApplicationScreen> createState() => _DriverApplicationScreenState();
}

class _DriverApplicationScreenState extends State<DriverApplicationScreen> {
  bool loading = true;
  bool busy = false;
  String? loadError;

  Map<String, dynamic> req = {};
  Map<String, dynamic> app = {};

  bool started = false; // person pressed "Start" on the intro
  int step = 0; // 0 personal, 1 vehicle, 2 documents

  final firstName = TextEditingController();
  final lastName = TextEditingController();
  String? dob;
  int? serviceId;
  final licenceYears = TextEditingController();
  final make = TextEditingController();
  final model = TextEditingController();
  final colour = TextEditingController();
  final year = TextEditingController();
  final plate = TextEditingController();
  final seats = TextEditingController();
  Map<String, String> fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _load(first: true);
  }

  @override
  void dispose() {
    for (final c in [firstName, lastName, licenceYears, make, model, colour, year, plate, seats]) {
      c.dispose();
    }
    super.dispose();
  }

  String get status => (app['status'] ?? 'not_started').toString();
  bool get editable => app['editable'] == true;
  int get minAge => (req['min_age'] as num?)?.toInt() ?? 19;
  int get minLicence => (req['min_licence_years'] as num?)?.toInt() ?? 1;
  List<Map<String, dynamic>> get vehicles => ((req['vehicles'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<Map<String, dynamic>> get documents => ((app['documents'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _load({bool first = false}) async {
    setState(() {
      loading = first || loading;
      loadError = null;
    });
    try {
      final results = await Future.wait([DriverApplicationApi.requirements(), DriverApplicationApi.application()]);
      req = results[0];
      app = results[1];
      if (first) _prefill();
    } on ApiFailure catch (e) {
      loadError = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  void _prefill() {
    final p = Map<String, dynamic>.from((app['personal'] ?? {}) as Map);
    firstName.text = (p['first_name'] ?? '').toString();
    lastName.text = (p['last_name'] ?? '').toString();
    dob = p['date_of_birth']?.toString();
    final v = app['vehicle'];
    if (v is Map) {
      serviceId = (v['service_id'] as num?)?.toInt();
      licenceYears.text = v['licence_years']?.toString() ?? '';
      make.text = (v['make'] ?? '').toString();
      model.text = (v['model'] ?? '').toString();
      colour.text = (v['colour'] ?? '').toString();
      year.text = (v['year'] ?? '').toString();
      plate.text = (v['plate'] ?? '').toString();
      seats.text = v['seats']?.toString() ?? '';
    }
    if (status != 'not_started' && editable) started = true;
  }

  Future<void> _run(Future<void> Function() job) async {
    if (busy) return;
    setState(() {
      busy = true;
      fieldErrors = {};
    });
    try {
      await job();
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() => fieldErrors = e.fields);
        _say(context, e.message);
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<Uint8List?> _pickBytes({required bool imagesOnly}) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(ctx, 'gallery')),
          if (!imagesOnly) ListTile(leading: const Icon(Icons.insert_drive_file_outlined), title: const Text('Choose a file (PDF or image)'), onTap: () => Navigator.pop(ctx, 'file')),
        ]),
      ),
    );
    if (source == null) return null;
    Uint8List? bytes;
    try {
      if (source == 'file') {
        final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'], withData: true);
        bytes = r?.files.single.bytes;
      } else {
        final x = await ImagePicker().pickImage(source: source == 'camera' ? ImageSource.camera : ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
        bytes = x == null ? null : await x.readAsBytes();
      }
    } catch (_) {
      if (mounted) _say(context, 'Could not open that. Please allow access and try again.');
      return null;
    }
    if (bytes == null) return null;
    if (bytes.length > _maxUploadBytes) {
      if (mounted) _say(context, 'That file is too large (5 MB maximum).');
      return null;
    }
    return bytes;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final latest = DateTime(now.year - minAge, now.month, now.day);
    DateTime initial = latest;
    if (dob != null) {
      final parsed = DateTime.tryParse(dob!);
      if (parsed != null && !parsed.isAfter(latest)) initial = parsed;
    }
    final d = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1930), lastDate: latest, helpText: 'Date of birth');
    if (d != null) setState(() => dob = _fmtDate(d));
  }

  // ---- step actions ----

  Future<void> _changePhoto() async {
    final bytes = await _pickBytes(imagesOnly: true);
    if (bytes == null) return;
    await _run(() async {
      await DriverApplicationApi.uploadPhoto(bytes);
      await _load();
      if (mounted) _say(context, 'Photo saved');
    });
  }

  Future<void> _nextFromPersonal() async {
    if (firstName.text.trim().isEmpty || lastName.text.trim().isEmpty) {
      _say(context, 'Enter your first name and surname.');
      return;
    }
    if (dob == null) {
      _say(context, 'Choose your date of birth.');
      return;
    }
    if ((app['personal'] as Map?)?['has_photo'] != true) {
      _say(context, 'Add a clear photo of your face.');
      return;
    }
    await _run(() async {
      await DriverApplicationApi.savePersonal(firstName: firstName.text.trim(), lastName: lastName.text.trim(), dateOfBirth: dob!);
      await _load();
      if (mounted) setState(() => step = 1);
    });
  }

  Future<void> _nextFromVehicle() async {
    if (serviceId == null) {
      _say(context, 'Choose what you will drive.');
      return;
    }
    final years = int.tryParse(licenceYears.text.trim());
    if (years == null) {
      _say(context, 'Enter how many years you have held your licence.');
      return;
    }
    if (years < minLicence) {
      _say(context, 'You need at least $minLicence year(s) of driving licence.');
      return;
    }
    await _run(() async {
      await DriverApplicationApi.saveVehicle({
        'service_id': serviceId,
        'licence_years': years,
        'make': make.text.trim(),
        'model': model.text.trim(),
        'colour': colour.text.trim(),
        'year': year.text.trim(),
        'plate': plate.text.trim(),
        'seats': int.tryParse(seats.text.trim()) ?? 0,
      });
      await _load();
      if (mounted) setState(() => step = 2);
    });
  }

  Future<void> _uploadDoc(Map<String, dynamic> d) async {
    String? expire;
    if (d['has_expiry_date'] == true) {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 365)),
        firstDate: now.add(const Duration(days: 1)),
        lastDate: now.add(const Duration(days: 365 * 20)),
        helpText: 'Expiry date of ${d['name']}',
      );
      if (picked == null) return;
      expire = _fmtDate(picked);
    }
    final bytes = await _pickBytes(imagesOnly: false);
    if (bytes == null) return;
    await _run(() async {
      await DriverApplicationApi.uploadDocument((d['document_id'] as num).toInt(), bytes, expireDate: expire);
      await _load();
      if (mounted) _say(context, '${d['name']} uploaded');
    });
  }

  bool get documentsComplete {
    for (final d in documents) {
      if (d['required'] != true) continue;
      if (d['uploaded'] != true) return false;
      if (d['has_expiry_date'] == true && d['expire_date'] == null) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    await _run(() async {
      await DriverApplicationApi.submit();
      await _load();
      await ModeController.refreshFromServer();
      if (mounted) {
        setState(() {});
        _say(context, 'Application sent. We will review it shortly.');
      }
    });
  }

  void _help() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('How driver registration works', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('• You must be at least $minAge years old and have held your driving licence for $minLicence year(s) or more.'),
            const SizedBox(height: 6),
            const Text('• Step 1: your name, date of birth and a clear photo of your face.'),
            const SizedBox(height: 6),
            const Text('• Step 2: choose what you drive and enter the vehicle details exactly as on your papers.'),
            const SizedBox(height: 6),
            const Text('• Step 3: upload the documents shown. Photos or PDFs, up to 5 MB each. Make sure all text is readable.'),
            const SizedBox(height: 6),
            const Text('• Your progress is saved every time you press Next. You can leave and continue later.'),
            const SizedBox(height: 6),
            const Text('• After you submit, our team reviews your documents. You will see the result here and can switch to driver mode once approved.'),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it'))),
          ]),
        ),
      ),
    );
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Drive with DROP'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.help_outline), tooltip: 'Help', onPressed: _help)],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _load(first: true), child: const Text('Try again')),
          ]),
        ),
      );
    }
    if (!editable) return _statusView();
    if (!started) return _intro();
    return _wizard();
  }

  Widget _primaryButton(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: busy ? null : onTap,
        child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(label),
      ),
    );
  }

  Widget _intro() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Earn with your car', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('Apply online in about 10 minutes. You keep using DROP as a passenger while we review your application.', style: TextStyle(color: Colors.grey.shade700)),
      const SizedBox(height: 20),
      _bullet(Icons.cake_outlined, 'At least $minAge years old'),
      _bullet(Icons.badge_outlined, 'Driving licence held for $minLicence year(s) or more'),
      _bullet(Icons.directions_car_outlined, 'A vehicle that fits one of our ride types'),
      _bullet(Icons.description_outlined, 'Clear photos or PDFs of your documents'),
      const SizedBox(height: 24),
      _primaryButton('Start application', () => setState(() => started = true)),
    ]);
  }

  Widget _bullet(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [Icon(icon, color: primaryColor), const SizedBox(width: 12), Expanded(child: Text(text))]),
      );

  Widget _stepper() {
    const labels = ['You', 'Vehicle', 'Documents'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(children: [
        for (int i = 0; i < 3; i++) ...[
          Expanded(
            child: Column(children: [
              Container(height: 4, decoration: BoxDecoration(color: i <= step ? primaryColor : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 4),
              Text('${i + 1}. ${labels[i]}', style: TextStyle(fontSize: 12, fontWeight: i == step ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
          if (i < 2) const SizedBox(width: 6),
        ],
      ]),
    );
  }

  Widget _banner() {
    final note = (app['review_note'] ?? '').toString();
    if (note.isEmpty || !(status == 'needs_changes' || status == 'rejected')) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
      child: Text('From our team: $note'),
    );
  }

  Widget _wizard() {
    return Column(children: [
      _stepper(),
      _banner(),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (step == 0) ..._personalStep(),
          if (step == 1) ..._vehicleStep(),
          if (step == 2) ..._documentsStep(),
        ]),
      ),
    ]);
  }

  InputDecoration _dec(String label, {String? field, String? hint}) => InputDecoration(labelText: label, hintText: hint, errorText: field == null ? null : fieldErrors[field], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)));

  List<Widget> _personalStep() {
    final hasPhoto = (app['personal'] as Map?)?['has_photo'] == true;
    return [
      const Text('About you', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      Center(
        child: GestureDetector(
          onTap: busy ? null : _changePhoto,
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Colors.grey.shade200,
            child: Icon(hasPhoto ? Icons.check_circle : Icons.add_a_photo_outlined, size: 36, color: hasPhoto ? Colors.green : Colors.grey.shade700),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Center(child: Text(hasPhoto ? 'Photo added. Tap to change.' : 'Add a clear photo of your face', style: TextStyle(color: Colors.grey.shade700))),
      const SizedBox(height: 20),
      TextField(controller: firstName, textCapitalization: TextCapitalization.words, decoration: _dec('First name', field: 'first_name')),
      const SizedBox(height: 12),
      TextField(controller: lastName, textCapitalization: TextCapitalization.words, decoration: _dec('Surname', field: 'last_name')),
      const SizedBox(height: 12),
      InkWell(
        onTap: _pickDob,
        child: InputDecorator(
          decoration: _dec('Date of birth', field: 'date_of_birth'),
          child: Text(dob ?? 'Choose date', style: TextStyle(color: dob == null ? Colors.grey.shade600 : Colors.black87)),
        ),
      ),
      const SizedBox(height: 24),
      _primaryButton('Next', _nextFromPersonal),
    ];
  }

  List<Widget> _vehicleStep() {
    return [
      const Text('What will you drive?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      if (vehicles.isEmpty) const Text('No ride types are open for registration yet. Please check back soon.'),
      for (final v in vehicles) _vehicleCard(v),
      const SizedBox(height: 12),
      TextField(controller: make, textCapitalization: TextCapitalization.words, decoration: _dec('Make', field: 'make', hint: 'e.g. Toyota')),
      const SizedBox(height: 12),
      TextField(controller: model, textCapitalization: TextCapitalization.words, decoration: _dec('Model', field: 'model', hint: 'e.g. Corolla')),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: year, keyboardType: TextInputType.number, decoration: _dec('Year', field: 'year', hint: 'e.g. 2016'))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: colour, textCapitalization: TextCapitalization.words, decoration: _dec('Colour', field: 'colour'))),
      ]),
      const SizedBox(height: 12),
      TextField(controller: plate, textCapitalization: TextCapitalization.characters, decoration: _dec('Plate number', field: 'plate')),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: seats, keyboardType: TextInputType.number, decoration: _dec('Passenger seats', field: 'seats'))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: licenceYears, keyboardType: TextInputType.number, decoration: _dec('Years with licence', field: 'licence_years', hint: 'min $minLicence'))),
      ]),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: busy ? null : () => setState(() => step = 0), child: const Text('Back'))),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: _primaryButton('Next', _nextFromVehicle)),
      ]),
    ];
  }

  Widget _vehicleCard(Map<String, dynamic> v) {
    final id = (v['id'] as num).toInt();
    final selected = serviceId == id;
    final img = (v['icon_url'] ?? v['photo_url'])?.toString();
    return GestureDetector(
      onTap: busy ? null : () => setState(() => serviceId = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? primaryColor : Colors.grey.shade300, width: selected ? 2 : 1),
          color: selected ? primaryColor.withOpacity(0.06) : Colors.white,
        ),
        child: Row(children: [
          SizedBox(
            width: 56,
            height: 40,
            child: img == null || img.isEmpty ? const Icon(Icons.directions_car_outlined) : Image.network(img, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.directions_car_outlined)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((v['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              if (v['capacity'] != null) Text('Up to ${v['capacity']} passengers', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ]),
          ),
          if (selected) Icon(Icons.check_circle, color: primaryColor),
        ]),
      ),
    );
  }

  List<Widget> _documentsStep() {
    final docs = documents;
    return [
      const Text('Your documents', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Photos or PDFs, up to 5 MB each. Make sure everything is readable.', style: TextStyle(color: Colors.grey.shade700)),
      const SizedBox(height: 12),
      if (docs.isEmpty) const Text('No documents are required for this vehicle type.'),
      for (final d in docs) _docRow(d, canUpload: true),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: busy ? null : () => setState(() => step = 1), child: const Text('Back'))),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: _primaryButton('Submit application', documentsComplete ? _submit : null)),
      ]),
      if (!documentsComplete) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Upload every required document to submit.', style: TextStyle(color: Colors.grey.shade700, fontSize: 12))),
    ];
  }

  Widget _chip(String status) {
    late final Color c;
    late final String t;
    switch (status) {
      case 'approved':
        c = Colors.green;
        t = 'Approved';
        break;
      case 'rejected':
        c = Colors.red;
        t = 'Rejected';
        break;
      case 'pending':
        c = Colors.orange;
        t = 'Waiting for review';
        break;
      default:
        c = Colors.grey;
        t = 'Missing';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(t, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _docRow(Map<String, dynamic> d, {required bool canUpload}) {
    final st = (d['status'] ?? 'missing').toString();
    final note = (d['note'] ?? '').toString();
    final expire = d['expire_date']?.toString();
    final uploaded = d['uploaded'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${d['name']}${d['required'] == true ? '' : ' (optional)'}', style: const TextStyle(fontWeight: FontWeight.w700))),
          _chip(st),
        ]),
        if (expire != null && expire.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Expires $expire', style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
        if (st == 'rejected' && note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note, style: const TextStyle(fontSize: 12, color: Colors.red))),
        if (canUpload && st != 'approved')
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: busy ? null : () => _uploadDoc(d),
              icon: Icon(uploaded ? Icons.refresh : Icons.upload_file, size: 18),
              label: Text(uploaded ? 'Replace' : 'Upload'),
            ),
          ),
      ]),
    );
  }

  Widget _statusView() {
    String title;
    String text;
    switch (status) {
      case 'approved':
        title = 'You are approved';
        text = 'You can now switch to driver mode from the menu and start earning.';
        break;
      case 'suspended':
        title = 'Driver mode is suspended';
        text = 'Please contact DROP support for more information.';
        break;
      default:
        title = 'Application under review';
        text = 'We are checking your details and documents. You will see the result here.';
    }
    final note = (app['review_note'] ?? '').toString();
    return ListView(padding: const EdgeInsets.all(20), children: [
      Icon(status == 'approved' ? Icons.verified : Icons.hourglass_top, size: 56, color: status == 'approved' ? Colors.green : primaryColor),
      const SizedBox(height: 12),
      Center(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
      const SizedBox(height: 8),
      Center(child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700))),
      if (note.isNotEmpty) ...[const SizedBox(height: 12), Text('From our team: $note')],
      const SizedBox(height: 20),
      for (final d in documents) _docRow(d, canUpload: false),
      const SizedBox(height: 12),
      if (status == 'approved')
        _primaryButton('Switch to driver', () async {
          await _run(() async {
            final err = await ModeController.switchTo('driver');
            if (err != null) throw ApiFailure(err);
          });
        }),
      TextButton(onPressed: () => _load(), child: const Text('Refresh status')),
    ]);
  }
}
