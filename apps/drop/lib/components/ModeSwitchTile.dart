import '../manage_imports.dart';
import '../screens/DriverApplicationScreen.dart';
import '../service/ModeController.dart';

/// Menu button for the passenger/driver mode.
/// target 'driver' (passenger menu): becomes "Become a driver" until an application exists, then shows its status,
/// then switches once approved. target 'rider' (driver menu): switches back to passenger mode.
class ModeSwitchTile extends StatefulWidget {
  final String target;

  const ModeSwitchTile({Key? key, required this.target}) : super(key: key);

  @override
  State<ModeSwitchTile> createState() => _ModeSwitchTileState();
}

class _ModeSwitchTileState extends State<ModeSwitchTile> {
  bool busy = false;

  bool get toDriver => widget.target == 'driver';

  @override
  void initState() {
    super.initState();
    if (toDriver) _refresh();
  }

  /// Approval can change while the app is open, so ask the server again.
  Future<void> _refresh() async {
    await ModeController.refreshFromServer();
    if (mounted) setState(() {});
  }

  String? _pendingText() {
    switch (ModeController.driverStatus) {
      case 'draft':
        return 'Finish your driver application';
      case 'submitted':
      case 'in_review':
        return 'Driver application under review';
      case 'needs_changes':
        return 'Driver application needs changes';
      case 'rejected':
        return 'Driver application not approved';
      case 'suspended':
        return 'Driver mode is suspended';
    }
    return null;
  }

  void _openApplication() {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => const DriverApplicationScreen()));
  }

  Future<void> _switch() async {
    if (busy) return;
    setState(() => busy = true);
    final err = await ModeController.switchTo(widget.target);
    if (!mounted) return;
    if (err != null) {
      setState(() => busy = false);
      toast(err);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = toDriver && !ModeController.isDriverApproved ? _pendingText() : null;
    final apply = toDriver && ModeController.driverStatus.isEmpty;
    final enabled = !busy;
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: enabled ? (apply || pending != null ? _openApplication : _switch) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? primaryColor : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.swap_horiz, color: enabled ? Colors.white : Colors.grey.shade600),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apply ? 'Become a driver' : (toDriver && pending != null ? 'Driver application' : (toDriver ? 'Switch to driver' : 'Switch to passenger')),
                      style: TextStyle(fontWeight: FontWeight.w600, color: enabled ? Colors.white : Colors.grey.shade700),
                    ),
                    if (apply) Text('Apply online in minutes', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    if (pending != null) Text(pending, style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              if (busy) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }
}
