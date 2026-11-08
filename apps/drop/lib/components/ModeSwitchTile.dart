import '../manage_imports.dart';
import '../service/ModeController.dart';

/// Menu button that switches between rider and driver mode.
/// target 'driver' (shown in passenger menu) or 'rider' (shown in driver menu).
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
    try {
      final id = sharedPref.getInt(USER_ID);
      if (id == null || id == 0) return;
      final res = await getUserDetail(userId: id);
      final u = res.data;
      if (u != null) {
        await ModeController.applyUser(u.roles, u.activeMode, u.driverStatus);
        if (mounted) setState(() {});
      }
    } catch (_) {}
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
    // Rider menu: nothing to show until the person has started a driver application.
    if (toDriver && ModeController.driverStatus.isEmpty) return SizedBox.shrink();
    final pending = toDriver && !ModeController.isDriverApproved ? _pendingText() : null;
    final enabled = pending == null && !busy;
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: enabled ? _switch : null,
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
                      toDriver ? 'Switch to driver' : 'Switch to passenger',
                      style: TextStyle(fontWeight: FontWeight.w600, color: enabled ? Colors.white : Colors.grey.shade700),
                    ),
                    if (pending != null) Text(pending, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
