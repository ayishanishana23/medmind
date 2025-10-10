import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final medicinesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medicines');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Medicine Dashboard"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: medicinesRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final meds = snapshot.data!.docs;
          if (meds.isEmpty) return const Center(child: Text("No medicines added yet."));

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // 🔹 Top-level Pie Chart (Overall Taken vs Missed)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FutureBuilder<List<int>>(
                    future: _calculateTakenMissed(meds),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final taken = snapshot.data![0];
                      final missed = snapshot.data![1];

                      if (taken + missed == 0) {
                        return const Center(child: Text("No doses logged yet."));
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Overall Dose Summary",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sections: [
                                  PieChartSectionData(
                                    value: taken.toDouble(),
                                    color: Colors.green,
                                    title: 'Taken ($taken)',
                                    radius: 50,
                                    titleStyle: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  PieChartSectionData(
                                    value: missed.toDouble(),
                                    color: Colors.red,
                                    title: 'Missed ($missed)',
                                    radius: 50,
                                    titleStyle: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                                sectionsSpace: 2,
                                centerSpaceRadius: 30,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 🔹 Medicine-wise details with Bar Chart
              ...meds.map((med) {
                final medName = med['name'];
                final stock = (med['stock'] is num ? (med['stock'] as num).toInt() : 0);
                final times = List<String>.from(med['times'] ?? []);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(medName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("Remaining Stock: $stock"),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot>(
                          stream: med.reference.collection('logs').snapshots(),
                          builder: (context, logsSnapshot) {
                            if (!logsSnapshot.hasData) return const SizedBox();
                            final logs = logsSnapshot.data!.docs;

                            final takenCount = logs.where((log) => log['status'] == 'taken').length;
                            final missedCount = logs.where((log) => log['status'] == 'missed').length;
                            final snoozedCount = logs.where((log) => log['status'] == 'snoozed').length;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Total Taken: $takenCount"),
                                Text("Total Missed: $missedCount"),
                                Text("Total Snoozed: $snoozedCount"),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  children: logs.map((log) {
                                    final status = log['status'];
                                    final time = (log['scheduledAt'] as Timestamp).toDate();
                                    final formattedTime = DateFormat('dd/MM/yyyy HH:mm').format(time);
                                    Color bgColor;
                                    if (status == 'taken') bgColor = Colors.green.shade200;
                                    else if (status == 'missed') bgColor = Colors.red.shade200;
                                    else bgColor = Colors.orange.shade200;

                                    return Chip(
                                      label: Text("$status\n$formattedTime", textAlign: TextAlign.center),
                                      backgroundColor: bgColor,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                                // 🔹 Bar Chart for this medicine
                                SizedBox(
                                  height: 180,
                                  child: BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: (takenCount > missedCount ? takenCount : missedCount).toDouble() + 2,
                                      barTouchData: BarTouchData(enabled: true),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(showTitles: true),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (double value, meta) {
                                              switch (value.toInt()) {
                                                case 0:
                                                  return const Text('Taken');
                                                case 1:
                                                  return const Text('Missed');
                                                default:
                                                  return const Text('');
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      barGroups: [
                                        BarChartGroupData(
                                          x: 0,
                                          barRods: [BarChartRodData(toY: takenCount.toDouble(), color: Colors.green)],
                                        ),
                                        BarChartGroupData(
                                          x: 1,
                                          barRods: [BarChartRodData(toY: missedCount.toDouble(), color: Colors.red)],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  // 🔹 Calculate overall taken and missed doses across all medicines
  Future<List<int>> _calculateTakenMissed(List<QueryDocumentSnapshot> meds) async {
    int totalTaken = 0;
    int totalMissed = 0;

    for (var med in meds) {
      final logsSnapshot = await med.reference.collection('logs').get();
      final logs = logsSnapshot.docs;

      totalTaken += logs.where((log) => log['status'] == 'taken').length;
      totalMissed += logs.where((log) => log['status'] == 'missed').length;
    }

    return [totalTaken, totalMissed];
  }
}
