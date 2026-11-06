
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

import '../attendance_design.dart';
import '../../services/attendance_store.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _LocalHistory {
  final List<AttendanceRecord> records;
  final UserProfile profile;

  const _LocalHistory(this.records, this.profile);
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  late final Future<_LocalHistory> _localHistory = _loadLocalHistory();

  Future<_LocalHistory> _loadLocalHistory() async {
    final recordsFuture = AttendanceStore.load();
    final profileFuture = AttendanceStore.loadProfile();
    return _LocalHistory(await recordsFuture, await profileFuture);
  }

  // Mengambil data dari collection Firestore
  final String collectionName = 'attendance';

  CollectionReference<Map<String, dynamic>> get dataCollection =>
      FirebaseFirestore.instance.collection(collectionName);

  // Membuat card riwayat
  Widget _buildAttendanceCard(
    String docId,
    String name,
    String address,
    String description,
    String datetime,
    String type,
  ) {
    final bool isPermission = type == 'permission';

    final Color statusColor =
        isPermission ? AttendanceColors.secondaryText : AttendanceColors.secondaryText;

    final IconData statusIcon =
        isPermission ? Icons.event_busy : Icons.check_circle;

    final String statusText =
        isPermission ? 'Permission' : 'Attendance';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nama dan status
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 15,
                        color: statusColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Keterangan
            _buildInfoRow(
              Icons.description_outlined,
              'Keterangan',
              description,
            ),

            const SizedBox(height: 8),

            // Tanggal
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Tanggal',
              datetime,
            ),

            const SizedBox(height: 8),

            // Alamat
            _buildInfoRow(
              Icons.location_on_outlined,
              'Alamat',
              address,
            ),

            const SizedBox(height: 10),

            // ID dokumen
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'ID: $docId',
                style: TextStyle(
                  fontSize: 12,
                  color: AttendanceColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Membuat baris informasi
  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AttendanceColors.textMuted,
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 85,
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  DateTime _createdAt(Map<String, dynamic> data) {
    final value = data['created_at'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(data['datetime']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, dynamic>> _mergeRecords(
    _LocalHistory local,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cloudDocs,
  ) {
    final entries = <String, Map<String, dynamic>>{};
    for (final record in local.records) {
      entries[record.id] = {
        '_docId': record.id,
        'name': local.profile.name,
        'address': record.location,
        'description': record.note.isEmpty
            ? record.title
            : '${record.title}: ${record.note}',
        'datetime': DateFormat('dd MMM yyyy, HH:mm').format(record.createdAt),
        'created_at': record.createdAt,
        'type': record.type == 'leave' ? 'permission' : 'attendance',
      };
    }
    for (final doc in cloudDocs) {
      entries[doc.id] = {'_docId': doc.id, ...doc.data()};
    }
    final result = entries.values.toList()
      ..sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));
    return result;
  }

  Widget _buildRecords(
    _LocalHistory local, {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cloudDocs = const [],
    String? errorMessage,
  }) {
    final records = _mergeRecords(local, cloudDocs);
    if (records.isEmpty) {
      return Center(
        child: Text(errorMessage ?? 'Belum ada riwayat presensi'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final data = records[index];
        return _buildAttendanceCard(
          data['_docId']?.toString() ?? '-',
          data['name']?.toString() ?? local.profile.name,
          data['address']?.toString() ?? '-',
          data['description']?.toString() ?? '-',
          data['datetime']?.toString() ?? '-',
          data['type']?.toString() ?? 'attendance',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        centerTitle: true,
      ),
      body: FutureBuilder<_LocalHistory>(
        future: _localHistory,
        builder: (context, localSnapshot) {
          if (!localSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final local = localSnapshot.data!;
          if (Firebase.apps.isEmpty) return _buildRecords(local);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: dataCollection.snapshots(),
            builder: (context, cloudSnapshot) {
              if (cloudSnapshot.hasError) {
                return _buildRecords(
                  local,
                  errorMessage: 'Firebase tidak tersedia. Menampilkan data lokal.',
                );
              }
              if (cloudSnapshot.connectionState == ConnectionState.waiting &&
                  local.records.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildRecords(
                local,
                cloudDocs: cloudSnapshot.data?.docs ?? const [],
              );
            },
          );
        },
      ),
    );
  }
}
