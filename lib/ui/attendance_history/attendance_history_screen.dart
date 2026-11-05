
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../attendance_design.dart';


class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  // Mengambil data dari collection Firestore
  final String collectionName = 'attendance';

  CollectionReference get dataCollection =>
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
                          fontSize: 12,
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
                  fontSize: 10,
                  color: Colors.grey.shade500,
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
          color: Colors.grey.shade600,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        centerTitle: true,
      ),
      body: Firebase.apps.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Firebase belum dikonfigurasi untuk platform ini. '
                  'Daftarkan aplikasi Web melalui FlutterFire CLI, lalu '
                  'inisialisasi Firebase dengan FirebaseOptions.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: dataCollection.snapshots(),
              builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Error
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Terjadi kesalahan saat mengambil data.',
              ),
            );
          }

          // Data kosong
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Belum ada riwayat presensi'),
            );
          }

          // Mengurutkan data berdasarkan created_at
          final docs = List<QueryDocumentSnapshot>.from(
            snapshot.data!.docs,
          );

          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;

            final timeA = dataA['created_at'];
            final timeB = dataB['created_at'];

            if (timeA is Timestamp && timeB is Timestamp) {
              return timeB.compareTo(timeA);
            }

            if (timeA is Timestamp) return -1;
            if (timeB is Timestamp) return 1;

            return 0;
          });

          // Menampilkan daftar riwayat
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data =
                  docs[index].data() as Map<String, dynamic>;

              final docId = docs[index].id;
              final name = data['name']?.toString() ?? 'Unknown';
              final address = data['address']?.toString() ?? '-';
              final description =
                  data['description']?.toString() ?? '-';
              final datetime = data['datetime']?.toString() ?? '-';
              final type = data['type']?.toString() ?? 'attendance';

              return _buildAttendanceCard(
                docId,
                name,
                address,
                description,
                datetime,
                type,
              );
            },
          );
              },
            ),
    );
  }
}
