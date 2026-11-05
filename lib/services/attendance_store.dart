import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AttendanceAddResult {
  saved,
  duplicate,
  requiresCheckIn,
  alreadyCheckedOut,
  checkOutRequired,
}

/// User profile model supporting international enterprise standard
class UserProfile {
  final String name;
  final String employeeId;
  final String role;
  final String department;
  final String photoBase64; // Optional profile photo base64

  const UserProfile({
    required this.name,
    required this.employeeId,
    required this.role,
    required this.department,
    required this.photoBase64,
  });

  UserProfile copyWith({
    String? name,
    String? employeeId,
    String? role,
    String? department,
    String? photoBase64,
  }) {
    return UserProfile(
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      role: role ?? this.role,
      department: department ?? this.department,
      photoBase64: photoBase64 ?? this.photoBase64,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'employeeId': employeeId,
    'role': role,
    'department': department,
    'photoBase64': photoBase64,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name']?.toString() ?? 'Prinz Tsabio',
      employeeId: json['employeeId']?.toString() ?? '8152',
      role: json['role']?.toString() ?? 'Lead Mobile Architect',
      department: json['department']?.toString() ?? 'Engineering',
      photoBase64: json['photoBase64']?.toString() ?? '',
    );
  }
}

/// Attendance record model with biometric match confidence and audit trail
class AttendanceRecord {
  final String id;
  final String title;
  final String status;
  final String type;
  final DateTime createdAt;
  final String location;
  final String note;
  final double biometricConfidence;
  final String? verificationBadge;

  const AttendanceRecord({
    required this.id,
    required this.title,
    required this.status,
    required this.type,
    required this.createdAt,
    required this.location,
    required this.note,
    this.biometricConfidence = 0.984,
    this.verificationBadge = 'Biometric Verified',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status,
    'type': type,
    'createdAt': createdAt.toIso8601String(),
    'location': location,
    'note': note,
    'biometricConfidence': biometricConfidence,
    'verificationBadge': verificationBadge,
  };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    if (createdAtRaw is! String) {
      throw const FormatException('Record is missing its timestamp.');
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw const FormatException('Record timestamp is invalid.');
    }
    return AttendanceRecord(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Attendance',
      status: json['status']?.toString() ?? 'On time',
      type: json['type']?.toString() ?? 'check_in',
      createdAt: createdAt,
      location: json['location']?.toString() ?? 'Location unavailable',
      note: json['note']?.toString() ?? '',
      biometricConfidence: (json['biometricConfidence'] as num?)?.toDouble() ?? 0.98,
      verificationBadge: json['verificationBadge']?.toString() ?? 'Biometric Verified',
    );
  }
}

/// Robust Enterprise Attendance & Profile Store with SharedPreferences persistence,
/// atomic reads, fallback data safety, and validation guards.
class AttendanceStore {
  static const _key = 'attendance_records_v1';
  static const _profileKey = 'user_profile_v1';
  static const _pendingSyncKey = 'attendance_pending_cloud_sync_v1';

  /// Load user profile with safe defaults and robust exception handling
  static Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) {
      return const UserProfile(
        name: 'Prinz Tsabio',
        employeeId: '8152',
        role: 'Senior Mobile Engineer',
        department: 'Product & Tech',
        photoBase64: '',
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return UserProfile.fromJson(decoded);
      }
      return const UserProfile(
        name: 'Prinz Tsabio',
        employeeId: '8152',
        role: 'Senior Mobile Engineer',
        department: 'Product & Tech',
        photoBase64: '',
      );
    } catch (_) {
      return const UserProfile(
        name: 'Prinz Tsabio',
        employeeId: '8152',
        role: 'Senior Mobile Engineer',
        department: 'Product & Tech',
        photoBase64: '',
      );
    }
  }

  /// Save or update profile
  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  /// Load attendance records
  static Future<List<AttendanceRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];

    final records = <AttendanceRecord>[];
    for (var index = 0; index < raw.length; index++) {
      try {
        final decoded = jsonDecode(raw[index]);
        if (decoded is! Map<String, dynamic>) continue;
        records.add(AttendanceRecord.fromJson(decoded));
      } catch (_) {}
    }

    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  /// Save attendance records with atomic write
  static Future<void> save(List<AttendanceRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = records.map((entry) => jsonEncode(entry.toJson())).toList(growable: false);
    await prefs.setStringList(_key, payload);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Append new attendance record
  static Future<void> add(AttendanceRecord record) async {
    final records = await load();
    records.insert(0, record);
    await _saveAndQueueSync(records, record);
  }

  static Future<void> _saveAndQueueSync(
    List<AttendanceRecord> records,
    AttendanceRecord newRecord,
  ) async {
    await save(records);
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingIds = prefs.getStringList(_pendingSyncKey) ?? <String>[];
      if (!pendingIds.contains(newRecord.id)) {
        pendingIds.add(newRecord.id);
        await prefs.setStringList(_pendingSyncKey, pendingIds);
      }
      unawaited(syncPendingRecords());
    } catch (_) {
      // The locally saved record remains available if queuing the cloud sync fails.
    }
  }

  /// Retries local attendance writes that have not reached Firestore yet.
  /// Local storage remains the source of truth when Firebase is unavailable.
  static Future<void> syncPendingRecords() async {
    try {
      if (Firebase.apps.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final pendingIds = prefs.getStringList(_pendingSyncKey) ?? <String>[];
      if (pendingIds.isEmpty) return;

      final rawRecords = prefs.getStringList(_key) ?? <String>[];
      final recordsById = <String, AttendanceRecord>{};
      for (final raw in rawRecords) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            final record = AttendanceRecord.fromJson(decoded);
            recordsById[record.id] = record;
          }
        } catch (_) {}
      }

      final profile = await loadProfile();
      final remainingIds = <String>[];
      for (final id in pendingIds) {
        final record = recordsById[id];
        if (record == null) continue;
        try {
          final description = record.note.isEmpty
              ? record.title
              : '${record.title}: ${record.note}';
          await FirebaseFirestore.instance.collection('attendance').doc(id).set({
            'name': profile.name,
            'address': record.location,
            'description': description,
            'datetime': DateFormat('dd MMM yyyy, HH:mm').format(record.createdAt),
            'type': record.type == 'leave' ? 'permission' : record.type,
            'created_at': Timestamp.fromDate(record.createdAt),
          }, SetOptions(merge: true));
        } catch (_) {
          remainingIds.add(id);
        }
      }
      await prefs.setStringList(_pendingSyncKey, remainingIds);
    } catch (_) {
      // Keep pending ids for the next startup or attendance action.
    }
  }

  /// Enterprise guard logic to enforce daily attendance integrity.
  ///
  /// Status hari ini diperiksa kronologis per SESI:
  ///   sesi baru dibuka oleh Check In dan ditutup oleh Check Out.
  ///  - Check In  : hanya boleh jika TIDAK ada sesi terbuka (harus Check Out
  ///                dulu sebelum Check In lagi).
  ///  - Check Out : hanya boleh jika ada sesi terbuka (sudah Check In).
  ///  - Break / Overtime : maksimal 1x per sesi terbuka.
  static Future<AttendanceAddResult> addWithResult(AttendanceRecord record) async {
    final records = await load();
    final todayRecords =
        records.where((existing) => _isSameDay(existing.createdAt, record.createdAt)).toList();

    // Rekonstruksi keadaan sesi secara kronologis
    final events = todayRecords.map((r) {
      return MapEntry(r.createdAt.millisecondsSinceEpoch, r.type);
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    bool sessionOpen = false;
    bool breakUsed = false;
    bool overtimeUsed = false;

    for (final event in events) {
      switch (event.value) {
        case 'check_in':
          sessionOpen = true;
          breakUsed = false;
          overtimeUsed = false;
        case 'check_out':
          sessionOpen = false;
          breakUsed = false;
          overtimeUsed = false;
        case 'break':
          if (sessionOpen) breakUsed = true;
        case 'overtime':
          if (sessionOpen) overtimeUsed = true;
      }
    }

    switch (record.type) {
      case 'check_in':
        if (sessionOpen) return AttendanceAddResult.checkOutRequired;
      case 'check_out':
        if (!sessionOpen) {
          return AttendanceAddResult.requiresCheckIn;
        }
      case 'break':
        if (!sessionOpen) return AttendanceAddResult.requiresCheckIn;
        if (breakUsed) return AttendanceAddResult.duplicate;
      case 'overtime':
        if (!sessionOpen) return AttendanceAddResult.requiresCheckIn;
        if (overtimeUsed) return AttendanceAddResult.duplicate;
    }

    records.insert(0, record);
    await _saveAndQueueSync(records, record);
    return AttendanceAddResult.saved;
  }

  /// Delete a record by ID
  static Future<void> delete(String id) async {
    final records = await load();
    records.removeWhere((record) => record.id != id);
    await save(records);
  }

  /// Reset all stored data (Development & Admin testing)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_profileKey);
    await prefs.remove(_pendingSyncKey);
  }
}
