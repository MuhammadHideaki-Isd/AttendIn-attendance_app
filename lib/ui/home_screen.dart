import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/attendance_store.dart';
import 'absent/absent_screen.dart';
import 'attendance_design.dart';
import 'attend/attend_screen.dart';
import 'attendance_history/attendance_history_screen.dart';
import 'navigation_shell.dart';

/// Standalone Screen for backward compatibility
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNavigationShell(initialIndex: 0);
  }
}

/// Rich HomeScreen Content with Multi-Card Carousel, Real-time Clock & Live Geofence
class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  bool _loading = true;
  String? _loadError;
  List<AttendanceRecord> _records = const [];
  UserProfile? _profile;
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final records = await AttendanceStore.load();
      final profile = await AttendanceStore.loadProfile();
      if (!mounted) return;
      setState(() {
        _records = records;
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load records: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openAttendance(AttendanceAction action) async {
    final record = await Navigator.push<AttendanceRecord>(
      context,
      SmoothPageRoute(page: AttendScreen(action: action)),
    );
    if (!mounted) return;

    if (record != null) {
      setState(() {
        _records = [record, ..._records.where((item) => item.id != record.id)]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    }
    await _loadData();
    if (record != null && mounted && !_records.any((item) => item.id == record.id)) {
      setState(() => _records = [record, ..._records]);
    }
  }

  Future<void> _openDestination(Widget screen) async {
    await Navigator.push(context, SmoothPageRoute(page: screen));
    if (mounted) await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayRecords = _records
        .where((r) => DateUtils.isSameDay(r.createdAt.toLocal(), now))
        .toList();
    final checkIns = todayRecords.where((r) => r.type == 'check_in');
    final checkOuts = todayRecords.where((r) => r.type == 'check_out');
    final checkInTime = checkIns.isEmpty
        ? '--:--'
        : DateFormat('HH:mm').format(checkIns.first.createdAt.toLocal());
    final checkOutTime = checkOuts.isEmpty
        ? '--:--'
        : DateFormat('HH:mm').format(checkOuts.first.createdAt.toLocal());
    final userName = _profile?.name ?? 'Hideaki Isdianto';

    return SafeArea(bottom: false, child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 116),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AttendanceCard(
          color: AttendanceColors.softAccent,
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ATTENDANCE', style: TextStyle(color: AttendanceColors.accent, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text('Welcome, ${userName.split(' ').first}', style: const TextStyle(color: AttendanceColors.text, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 4),
              Text(DateFormat('EEEE, d MMMM yyyy').format(now), style: const TextStyle(color: AttendanceColors.secondaryText, fontSize: 15, fontWeight: FontWeight.w600)),
            ])),
            CircleAvatar(radius: 25, backgroundColor: Colors.white, child: _profile != null && _profile!.photoBase64.isNotEmpty ? ClipOval(child: Image.memory(base64Decode(_profile!.photoBase64), width: 50, height: 50, fit: BoxFit.cover)) : const Icon(Icons.person_outline_rounded, color: AttendanceColors.text)),
          ]),
        ),
        const SizedBox(height: 24),
        AttendanceCard(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Today's attendance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: _buildTimeSummary('CHECK IN', checkInTime, Icons.login_rounded)), const SizedBox(width: 12), Expanded(child: _buildTimeSummary('CHECK OUT', checkOutTime, Icons.logout_rounded))]),
        ])),
        const SizedBox(height: 24),
        const Text('Attendance actions', style: AttendanceTypography.sectionTitle),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: _buildActionTile(icon: Icons.login_rounded, label: 'CHECK IN', accent: AttendanceColors.accent, onTap: () => _openAttendance(AttendanceAction.checkIn))), const SizedBox(width: 10), Expanded(child: _buildActionTile(icon: Icons.logout_rounded, label: 'CHECK OUT', accent: AttendanceColors.accent, onTap: () => _openAttendance(AttendanceAction.checkOut)))]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _buildActionTile(icon: Icons.free_breakfast_rounded, label: 'BREAK', accent: AttendanceColors.accent, onTap: () => _openAttendance(AttendanceAction.breakAction))), const SizedBox(width: 10), Expanded(child: _buildActionTile(icon: Icons.more_time_rounded, label: 'OVERTIME', accent: AttendanceColors.accent, onTap: () => _openAttendance(AttendanceAction.overtime)))]),
        const SizedBox(height: 24),
        Row(children: [Expanded(child: _buildDestinationCard(context, 'Leave request', 'Send a leave or permission request', Icons.event_note_rounded, const AbsentScreen())), const SizedBox(width: 12), Expanded(child: _buildDestinationCard(context, 'History', 'Review your attendance records', Icons.history_rounded, const AttendanceHistoryScreen()))]),
        const SizedBox(height: 28),
        AttendanceSectionHeading(title: 'Recent activity', trailing: 'View all', onTrailing: () => Navigator.push(context, SmoothPageRoute(page: const AttendanceHistoryScreen()))),
        const SizedBox(height: 12),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator(color: AttendanceColors.text)))
        else if (_loadError != null) Text(_loadError!, style: const TextStyle(color: AttendanceColors.error))
        else if (_records.isEmpty) const AttendanceCard(child: Text('No attendance records yet', style: TextStyle(color: AttendanceColors.secondaryText)))
        else ..._records.take(5).map((record) => Padding(padding: const EdgeInsets.only(bottom: 10), child: AttendanceCard(padding: const EdgeInsets.all(14), child: _buildActivityRow(record)))),
      ]),
    ));
  }

  Widget _buildTimeSummary(String label, String time, IconData icon) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AttendanceColors.page, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 7, offset: Offset(-3, -3)), BoxShadow(color: Color(0x331B5E3B), blurRadius: 7, offset: Offset(3, 3))]),
    child: Row(children: [Icon(icon, color: AttendanceColors.secondaryText, size: 19), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: AttendanceColors.secondaryText, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(time, style: const TextStyle(fontSize: 19, color: AttendanceColors.text, fontWeight: FontWeight.w800))]))]),
  );

  Widget _buildDestinationCard(BuildContext context, String title, String subtitle, IconData icon, Widget screen) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => _openDestination(screen),
    child: AttendanceCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: AttendanceColors.text, size: 22), const SizedBox(height: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: AttendanceColors.secondaryText, fontSize: 13, fontWeight: FontWeight.w600, height: 1.35))])),
  );
  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AttendanceColors.surfaceBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: AttendanceColors.text.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  color: AttendanceColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityRow(AttendanceRecord item) {
    final isCheckIn = item.type == 'check_in';
    final isLeave = item.type == 'leave';

    final Color badgeBg = AttendanceColors.softSurface;
    final Color badgeText = isCheckIn
        ? AttendanceColors.success
        : (isLeave ? AttendanceColors.warning : AttendanceColors.accent);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AttendanceColors.softSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            isCheckIn
                ? Icons.login_rounded
                : (isLeave ? Icons.description_rounded : Icons.logout_rounded),
            color: AttendanceColors.text,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AttendanceColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${DateFormat('HH:mm').format(item.createdAt.toLocal())} - ${item.location}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AttendanceColors.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(AttendanceRadius.pill),
          ),
          child: Text(
            item.status.toUpperCase(),
            style: TextStyle(
              color: badgeText,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
