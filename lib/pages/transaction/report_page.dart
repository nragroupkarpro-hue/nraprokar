import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/firestore_service.dart';
import '../../services/report_service.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import 'package:intl/intl.dart';

class ReportPage extends StatefulWidget {
  final String? type; // 'pengeluaran' or 'pemasukan' or null for general

  const ReportPage({Key? key, this.type}) : super(key: key);

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final FirestoreService service = FirestoreService();
  List<double> chartData = [];
  Map<String, int>? monthlySummary;

  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    loadChart();
    loadSummary();
  }

  Future<void> loadChart() async {
    final data = await service.getYearlyExpenseChart(selectedYear);
    setState(() {
      chartData = data;
    });
  }

  Future<void> loadSummary() async {
    final summary = await service.getMonthlySummary(
      selectedYear,
      selectedMonth,
    );
    setState(() {
      monthlySummary = summary;
    });
  }

  void _updateAfterSelection() {
    loadChart();
    loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final baseTitle =
        widget.type == null
            ? 'Laporan'
            : widget.type == 'pengeluaran'
            ? 'Laporan Pengeluaran'
            : 'Laporan Pemasukan';
    final title =
        monthlySummary == null
            ? baseTitle
            : '$baseTitle ${DateFormat('MMMM yyyy').format(DateTime(selectedYear, selectedMonth))}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // helper to update both chart and summary after selection

          // selectors for year and month
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<int>(
                  value: selectedMonth,
                  items: List.generate(12, (i) {
                    return DropdownMenuItem(
                      value: i + 1,
                      child: Text(DateFormat.MMMM().format(DateTime(0, i + 1))),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      selectedMonth = val;
                      _updateAfterSelection();
                    }
                  },
                ),
                DropdownButton<int>(
                  value: selectedYear,
                  items: List.generate(5, (i) {
                    final year = DateTime.now().year - i;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      selectedYear = val;
                      _updateAfterSelection();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (monthlySummary != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        'Ringkasan ${DateFormat('MMMM yyyy').format(DateTime(selectedYear, selectedMonth))}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'Pemasukan',
                                style: TextStyle(color: Colors.green),
                              ),
                              Text(
                                NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: 'Rp ',
                                ).format(monthlySummary!['income']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'Pengeluaran',
                                style: TextStyle(color: Colors.red),
                              ),
                              Text(
                                NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: 'Rp ',
                                ).format(monthlySummary!['expense']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            "Grafik Pengeluaran Tahunan $selectedYear",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                barGroups:
                    chartData
                        .asMap()
                        .entries
                        .map(
                          (e) => BarChartGroupData(
                            x: e.key,
                            barRods: [BarChartRodData(toY: e.value)],
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (monthlySummary != null) {
                // fetch matching transactions for report
                final txList = await service.getMonthlyTransactions(
                  selectedYear,
                  selectedMonth,
                  widget.type,
                );
                await generateReport(
                  year: selectedYear,
                  month: selectedMonth,
                  income: monthlySummary!['income']!,
                  expense: monthlySummary!['expense']!,
                  transactions: txList,
                  type: widget.type,
                );
              }
            },
            child: Text(
              "Generate PDF ${DateFormat('MMMM yyyy').format(DateTime(selectedYear, selectedMonth))}",
            ),
          ),

          // If a type is provided, show the filtered transaction list
          if (widget.type != null) ...[
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Detail ${widget.type == 'pengeluaran' ? 'pengeluaran' : 'pemasukan'} ${DateFormat('MMMM yyyy').format(DateTime(selectedYear, selectedMonth))}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<CategoryModel>>(
                      stream: service.getCategories(),
                      builder: (context, catSnap) {
                        final cats = catSnap.data ?? [];
                        final Map<String, CategoryModel> catMap = {
                          for (var c in cats) c.id ?? '': c,
                        };

                        return StreamBuilder<List<TransactionModel>>(
                          stream: service.getTransactions(),
                          builder: (context, trxSnap) {
                            if (!trxSnap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            var tx =
                                (trxSnap.data ?? [])
                                    .where((t) => t.type == widget.type)
                                    .toList();
                            // further restrict to selected month/year
                            tx =
                                tx
                                    .where(
                                      (t) =>
                                          t.date.year == selectedYear &&
                                          t.date.month == selectedMonth,
                                    )
                                    .toList();

                            if (tx.isEmpty) {
                              return Center(
                                child: Text(
                                  widget.type == 'pengeluaran'
                                      ? 'Tidak ada pengeluaran'
                                      : 'Tidak ada pemasukan',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: tx.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final t = tx[i];
                                final cat = catMap[t.categoryId];
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          widget.type == 'pengeluaran'
                                              ? Colors.red.shade100
                                              : Colors.green.shade100,
                                      child: Icon(
                                        widget.type == 'pengeluaran'
                                            ? Icons.arrow_downward
                                            : Icons.arrow_upward,
                                        color:
                                            widget.type == 'pengeluaran'
                                                ? Colors.red
                                                : Colors.green,
                                      ),
                                    ),
                                    title: Text(
                                      t.title.isNotEmpty ? t.title : t.itemName,
                                    ),
                                    subtitle: Text(
                                      '${DateFormat('dd MMM yyyy').format(t.date)} • ${cat?.namaBarang ?? '-'}',
                                    ),
                                    trailing: Text(
                                      NumberFormat.currency(
                                        locale: 'id_ID',
                                        symbol: 'Rp ',
                                      ).format(t.amount),
                                      style: TextStyle(
                                        color:
                                            widget.type == 'pengeluaran'
                                                ? Colors.red
                                                : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
