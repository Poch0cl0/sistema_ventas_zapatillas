import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../store/store_repository.dart';

DateTime limaDay(DateTime date) {
  final value = date.toUtc().subtract(const Duration(hours: 5));
  return DateTime.utc(value.year, value.month, value.day);
}

List<({DateTime day, int cents})> salesByDay(
  List<Json> orders,
  int days,
  DateTime now,
) {
  final end = limaDay(now);
  final start = end.subtract(Duration(days: days - 1));
  final totals = <DateTime, int>{};
  for (final order in orders) {
    if (order['isSimulation'] == true || order['paymentStatus'] != 'APROBADO') {
      continue;
    }
    final date = DateTime.tryParse(
      '${order['approvedAt'] ?? order['createdAt']}',
    );
    if (date == null) continue;
    final day = limaDay(date);
    if (day.isBefore(start) || day.isAfter(end)) continue;
    totals[day] = (totals[day] ?? 0) + (order['totalCents'] as int);
  }
  return [
    for (var i = 0; i < days; i++)
      (
        day: start.add(Duration(days: i)),
        cents: totals[start.add(Duration(days: i))] ?? 0,
      ),
  ];
}

class SalesChart extends StatefulWidget {
  const SalesChart(this.orders, {super.key});
  final List<Json> orders;
  @override
  State<SalesChart> createState() => _SalesChartState();
}

class _SalesChartState extends State<SalesChart> {
  int days = 7;
  @override
  Widget build(BuildContext context) {
    final values = salesByDay(widget.orders, days, DateTime.now());
    final total = values.fold<int>(0, (sum, item) => sum + item.cents);
    final maximum = math.max(
      1,
      values.fold<int>(0, (max, item) => math.max(max, item.cents)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final period in [7, 30, 90])
              ChoiceChip(
                label: Text('$period días'),
                selected: days == period,
                onSelected: (_) => setState(() => days = period),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          money(total),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const Text(
          'Pagos reales aprobados · fechas de Perú',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (total == 0)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Sin ventas aprobadas en este período.'),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(MediaQuery.sizeOf(context).width - 80, days * 42.0),
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final item in values)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${item.day.day}/${item.day.month}: ${money(item.cents)}',
                      child: Semantics(
                        label:
                            '${item.day.day}/${item.day.month}, ${money(item.cents)}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: double.infinity,
                                height: math.max(2, item.cents / maximum * 138),
                                decoration: BoxDecoration(
                                  color: item.cents == 0
                                      ? Colors.black12
                                      : const Color(0xFFEE6A35),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${item.day.day}/${item.day.month}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Mantén pulsada una barra para consultar el importe. Los pagos demo se excluyen. En pedidos antiguos sin fecha de aprobación se usa la fecha de creación.',
          style: TextStyle(fontSize: 11, color: muted),
        ),
      ],
    );
  }
}
