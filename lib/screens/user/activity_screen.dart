import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _isLoading = true;
  double _overallAdherence = 0.0;
  Map<String, double> _monthlyAdherence = {};
  List<Map<String, dynamic>> _perMedicineStats = [];
  List<Map<String, dynamic>> _completedCourses = [];
  List<Map<String, dynamic>> _ongoingCourses = [];

  @override
  void initState() {
    super.initState();
    _fetchAdherenceData();
  }

  Future<void> _fetchAdherenceData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(user.uid);

    // Get all profiles under this user
    final profiles = await userDoc.collection('profiles').get();

    int totalDoses = 0;
    int takenDoses = 0;
    Map<String, int> monthlyTaken = {};
    Map<String, int> monthlyTotal = {};
    List<Map<String, dynamic>> perMedicineStats = [];
    List<Map<String, dynamic>> completedCourses = [];
    List<Map<String, dynamic>> ongoingCourses = [];

    for (var profile in profiles.docs) {
      final medsRef = profile.reference.collection('medicines');
      final medicineDocs = await medsRef.get();

      for (var medDoc in medicineDocs.docs) {
        final data = medDoc.data();
        final medName = data['name'] ?? 'Unnamed';
        final dosage = data['dosage'] ?? '';
        final startDate = data['startDate']?.toDate();
        final endDate = data['endDate']?.toDate();

        final logs = await medDoc.reference.collection('logs').get();

        int medTaken = 0;
        int medTotal = logs.docs.length;

        for (var log in logs.docs) {
          final taken = log['taken'] ?? false;
          final timestamp = log['timestamp']?.toDate() ?? DateTime.now();
          final monthKey = "${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}";

          monthlyTotal[monthKey] = (monthlyTotal[monthKey] ?? 0) + 1;
          if (taken) {
            medTaken++;
            monthlyTaken[monthKey] = (monthlyTaken[monthKey] ?? 0) + 1;
          }
        }

        totalDoses += medTotal;
        takenDoses += medTaken;

        final adherencePercent = medTotal > 0 ? (medTaken / medTotal) * 100 : 0.0;

        perMedicineStats.add({
          'medName': medName,
          'dosage': dosage,
          'taken': medTaken,
          'missed': medTotal - medTaken,
          'total': medTotal,
          'percent': adherencePercent,
        });

        if (endDate != null && DateTime.now().isAfter(endDate)) {
          completedCourses.add({
            'medName': medName,
            'dosage': dosage,
            'taken': medTaken,
            'missed': medTotal - medTaken,
            'percent': adherencePercent,
          });
        } else {
          ongoingCourses.add({
            'medName': medName,
            'dosage': dosage,
            'taken': medTaken,
            'missed': medTotal - medTaken,
            'percent': adherencePercent,
          });
        }
      }
    }

    final overallAdherence =
    totalDoses > 0 ? (takenDoses / totalDoses) * 100 : 0.0;

    Map<String, double> monthlyAdherence = {};
    monthlyTotal.forEach((month, total) {
      final taken = monthlyTaken[month] ?? 0;
      monthlyAdherence[month] = total > 0 ? (taken / total) * 100 : 0.0;
    });

    setState(() {
      _overallAdherence = overallAdherence;
      _monthlyAdherence = monthlyAdherence;
      _perMedicineStats = perMedicineStats;
      _completedCourses = completedCourses;
      _ongoingCourses = ongoingCourses;
      _isLoading = false;
    });
  }


  Widget _buildProgressBar(double percent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        value: percent / 100,
        backgroundColor: Colors.grey.shade200,
        valueColor: AlwaysStoppedAnimation<Color>(
          percent >= 80
              ? Colors.green
              : percent >= 50
              ? Colors.orange
              : Colors.red,
        ),
        minHeight: 8,
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon ?? Icons.analytics_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> med) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication_outlined, color: Colors.teal, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${med['medName']} (${med['dosage']})",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("Taken: ${med['taken']} | Missed: ${med['missed']}",
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 8),
            _buildProgressBar(med['percent']),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "${med['percent'].toStringAsFixed(1)}%",
                style: TextStyle(
                    color: med['percent'] >= 80
                        ? Colors.green
                        : med['percent'] >= 50
                        ? Colors.orange
                        : Colors.red,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdherenceCard(double percent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.9),
            AppColors.primary.withOpacity(0.7)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text("Overall Adherence",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 90,
                width: 90,
                child: CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 8,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  backgroundColor: Colors.white24,
                ),
              ),
              Text(
                "${percent.toStringAsFixed(1)}%",
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Activity & Adherence"),
        backgroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchAdherenceData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdherenceCard(_overallAdherence),
              const SizedBox(height: 20),

              if (_monthlyAdherence.isNotEmpty) ...[
                _buildSectionTitle("Monthly Adherence", icon: Icons.calendar_today_outlined),
                ..._monthlyAdherence.entries.map(
                      (e) => _buildMedicineCard({
                    'medName': DateFormat('MMM yyyy').format(DateTime.parse("${e.key}-01")),
                    'dosage': '',
                    'taken': (e.value).round(),
                    'missed': 0,
                    'percent': e.value,
                  }),
                ),
              ],

              const SizedBox(height: 20),
              _buildSectionTitle("Per Medicine Adherence", icon: Icons.medication_liquid),
              ..._perMedicineStats.map(_buildMedicineCard),

              if (_completedCourses.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSectionTitle("Completed Courses", icon: Icons.check_circle_outline),
                ..._completedCourses.map(_buildMedicineCard),
              ],

              if (_ongoingCourses.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSectionTitle("Ongoing Courses", icon: Icons.schedule_outlined),
                ..._ongoingCourses.map(_buildMedicineCard),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
