import 'dart:math';
import 'package:flutter/material.dart';
import '../services/gpmai_api_client.dart';

class PointsManagerPage extends StatefulWidget {
  const PointsManagerPage({super.key});

  @override
  State<PointsManagerPage> createState() => _PointsManagerPageState();
}

enum _RangeMode { week, month }

class _SeriesPoint {
  final String key; // YYYY-MM-DD or YYYY-MM
  final double points;
  final int requests;

  const _SeriesPoint({
    required this.key,
    required this.points,
    required this.requests,
  });
}

class _PointsManagerPageState extends State<PointsManagerPage>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _silentLoading = false;
  String? _error;

  Map<String, dynamic>? _me;

  _RangeMode _mode = _RangeMode.week;

  List<_SeriesPoint> _week = const [];
  List<_SeriesPoint> _months = const [];

  int _loadSeq = 0; // ✅ prevents stale results overwriting fresh UI

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ refresh when page opens
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ✅ if user backgrounds & returns while page open -> refresh
    if (state == AppLifecycleState.resumed) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final mySeq = ++_loadSeq;

    if (!silent) {
      setState(() {
        _loading = true;
        _silentLoading = false;
        _error = null;
      });
    } else {
      setState(() {
        _silentLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        GpmaiApiClient.me(),
        GpmaiApiClient.usageDaily(days: 7),
        GpmaiApiClient.usageMonthly(months: 6),
      ]);

      if (!mounted || mySeq != _loadSeq) return;

      final me = results[0] as Map<String, dynamic>;
      final daily = results[1] as Map<String, dynamic>;
      final monthly = results[2] as Map<String, dynamic>;

      final weekSeries = (daily["series"] as List?) ?? const [];
      final monthSeries = (monthly["series"] as List?) ?? const [];

      final weekPts = weekSeries.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return _SeriesPoint(
          key: (m["dayKey"] ?? "").toString(),
          points: (m["pointsSpent"] ?? 0).toDouble(),
          requests: int.tryParse("${m["requests"] ?? 0}") ?? 0,
        );
      }).toList();

      final monthPts = monthSeries.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return _SeriesPoint(
          key: (m["monthKey"] ?? "").toString(),
          points: (m["pointsSpent"] ?? 0).toDouble(),
          requests: int.tryParse("${m["requests"] ?? 0}") ?? 0,
        );
      }).toList();

      setState(() {
        _me = me;
        _week = weekPts;
        _months = monthPts;
        _loading = false;
        _silentLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || mySeq != _loadSeq) return;
      setState(() {
        _loading = false;
        _silentLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final wallet = (_me?["wallet"] is Map)
        ? (_me!["wallet"] as Map).cast<String, dynamic>()
        : null;

    final usage = (_me?["usage"] is Map)
        ? (_me!["usage"] as Map).cast<String, dynamic>()
        : null;

    final today = (usage?["today"] is Map)
        ? (usage!["today"] as Map).cast<String, dynamic>()
        : null;

    final pointsBalance = _asInt(wallet?["pointsBalance"]);
    final bankCap = _asInt(wallet?["bankCap"]);
    final minGate = _asInt(wallet?["minGatePoints"]);
    final nextDailyCreditAt = _asInt(wallet?["nextDailyCreditAt"]);

    final todaySpent = _asInt(today?["pointsSpent"]);
    final todayReq = _asInt(today?["requests"]);

    final activeSeries = _mode == _RangeMode.week ? _week : _months;

    final rolloverRoom = max(0, bankCap - pointsBalance);
    final canStart = pointsBalance >= minGate;

    final resetText = _formatResetLabel(nextDailyCreditAt);
    final resetCountdown = _formatCountdown(nextDailyCreditAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Points Manager"),
        actions: [
          if (_silentLoading)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: "Refresh",
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Wallet",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.account_balance_wallet_outlined, color: cs.primary),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    "$pointsBalance",
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Remaining points",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withOpacity(.72),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          title: "Rollover bank",
                          value: "$pointsBalance / $bankCap",
                          subtitle: "Room left: $rolloverRoom",
                          icon: Icons.savings_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoTile(
                          title: "Resets",
                          value: resetText,
                          subtitle: resetCountdown,
                          icon: Icons.schedule_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: canStart ? Colors.green.withOpacity(.35) : Colors.red.withOpacity(.35),
                      ),
                      color: canStart ? Colors.green.withOpacity(.08) : Colors.red.withOpacity(.08),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          canStart ? Icons.verified_rounded : Icons.warning_amber_rounded,
                          color: canStart ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            canStart ? "OK to start (≥ $minGate)" : "LOW — need at least $minGate to start",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: canStart ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Text(
                        "Today used: ",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface.withOpacity(.75),
                        ),
                      ),
                      Text(
                        "$todaySpent",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface.withOpacity(.92),
                        ),
                      ),
                      Text(
                        "  •  Requests: $todayReq",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface.withOpacity(.75),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Usage graph",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        ),
                      ),
                      const Spacer(),
                      _ModePills(
                        mode: _mode,
                        onChange: (m) => setState(() => _mode = m),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _mode == _RangeMode.week ? "Weekly (last 7 days)" : "Monthly (last 6 months)",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withOpacity(.75),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InteractiveLineChart(points: activeSeries, mode: _mode),
                  const SizedBox(height: 14),
                  _UsageSummary(points: activeSeries, mode: _mode),
                ],
              ),
            ),

            if (_loading) ...[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator()),
            ],

            if (_error != null) ...[
              const SizedBox(height: 18),
              _CardBox(
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: cs.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }
}

/* ---------------- Helpers ---------------- */

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v == null) return 0;
  return int.tryParse(v.toString()) ?? 0;
}

String _two(int n) => n < 10 ? "0$n" : "$n";

String _formatResetLabel(int nextMs) {
  if (nextMs <= 0) return "--";
  final dt = DateTime.fromMillisecondsSinceEpoch(nextMs).toLocal();
  return "${_two(dt.hour)}:${_two(dt.minute)}";
}

String _formatCountdown(int nextMs) {
  if (nextMs <= 0) return "—";
  final now = DateTime.now();
  final dt = DateTime.fromMillisecondsSinceEpoch(nextMs).toLocal();
  final diff = dt.difference(now);
  if (diff.inSeconds <= 0) return "resetting soon";
  final h = diff.inHours;
  final m = diff.inMinutes.remainder(60);
  return "in ${h}h ${m}m";
}

/* ---------------- UI bits ---------------- */

class _CardBox extends StatelessWidget {
  final Widget child;
  const _CardBox({required this.child});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF151920),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
      ),
      child: child,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _InfoTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF7F7FA) : const Color(0xFF0F1218),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface.withOpacity(.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModePills extends StatelessWidget {
  final _RangeMode mode;
  final ValueChanged<_RangeMode> onChange;
  const _ModePills({required this.mode, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget pill(String text, bool active, VoidCallback onTap) {
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? cs.primary.withOpacity(.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? cs.primary : cs.onSurface.withOpacity(.15),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: active ? cs.primary : cs.onSurface.withOpacity(.8),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill("Weekly", mode == _RangeMode.week, () => onChange(_RangeMode.week)),
        const SizedBox(width: 8),
        pill("Monthly", mode == _RangeMode.month, () => onChange(_RangeMode.month)),
      ],
    );
  }
}

/* ---------------- Date formatting ---------------- */

const _weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const _months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

String _prettyDay(String yyyyMmDd) {
  final dt = DateTime.tryParse(yyyyMmDd);
  if (dt == null) return yyyyMmDd;
  final wd = _weekdays[(dt.weekday - 1).clamp(0, 6)];
  return "$wd ${dt.day}";
}

String _prettyMonth(String yyyyMm) {
  final parts = yyyyMm.split("-");
  if (parts.length != 2) return yyyyMm;
  final m = int.tryParse(parts[1]) ?? 1;
  final name = _months[(m - 1).clamp(0, 11)];
  return name;
}

/* ---------------- Interactive chart ---------------- */

class _InteractiveLineChart extends StatefulWidget {
  final List<_SeriesPoint> points;
  final _RangeMode mode;

  const _InteractiveLineChart({
    required this.points,
    required this.mode,
  });

  @override
  State<_InteractiveLineChart> createState() => _InteractiveLineChartState();
}

class _InteractiveLineChartState extends State<_InteractiveLineChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _InteractiveLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final len = widget.points.length;
    if (len == 0) {
      _selectedIndex = null;
      return;
    }
    if (_selectedIndex != null) {
      _selectedIndex = _selectedIndex!.clamp(0, len - 1);
    } else {
      _selectedIndex = len - 1;
    }
  }

  int _indexFromX(double x, double width, int count) {
    if (count <= 1) return 0;
    final step = width / (count - 1);
    final raw = (x / step).round();
    return raw.clamp(0, count - 1);
  }

  String _label(String key) {
    return widget.mode == _RangeMode.month ? _prettyMonth(key) : _prettyDay(key);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pts = widget.points;

    if (pts.isEmpty) {
      return SizedBox(
        height: 210,
        child: Center(
          child: Text(
            "No data yet",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withOpacity(.65),
            ),
          ),
        ),
      );
    }

    final maxV = pts.map((e) => e.points).reduce(max);
    final safeMax = maxV <= 0 ? 1.0 : maxV;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = 210.0;

        final safeSel = (_selectedIndex ?? (pts.length - 1)).clamp(0, pts.length - 1);
        final selected = pts[safeSel];

        return SizedBox(
          height: h,
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (d) {
                  final idx = _indexFromX(d.localPosition.dx, w, pts.length);
                  setState(() => _selectedIndex = idx);
                },
                onPanUpdate: (d) {
                  final idx = _indexFromX(d.localPosition.dx, w, pts.length);
                  setState(() => _selectedIndex = idx);
                },
                onTapDown: (d) {
                  final idx = _indexFromX(d.localPosition.dx, w, pts.length);
                  setState(() => _selectedIndex = idx);
                },
                child: CustomPaint(
                  size: Size(w, h),
                  painter: _LineChartPainter(
                    points: pts,
                    maxValue: safeMax,
                    selectedIndex: safeSel,
                    color: cs.primary,
                    axisColor: cs.onSurface.withOpacity(.15),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.primary.withOpacity(.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _label(selected.key),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Points: ${selected.points.toInt()}",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: cs.onSurface.withOpacity(.85),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Req: ${selected.requests}",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: cs.onSurface.withOpacity(.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_SeriesPoint> points;
  final double maxValue;
  final int selectedIndex;
  final Color color;
  final Color axisColor;

  _LineChartPainter({
    required this.points,
    required this.maxValue,
    required this.selectedIndex,
    required this.color,
    required this.axisColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    const topPad = 46.0;
    const bottomPad = 28.0;
    const leftPad = 6.0;
    const rightPad = 6.0;

    final chartH = h - topPad - bottomPad;
    final chartW = w - leftPad - rightPad;

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(leftPad, topPad + chartH),
      Offset(leftPad + chartW, topPad + chartH),
      axisPaint,
    );

    final count = points.length;
    final step = count <= 1 ? 0 : chartW / (count - 1);

    final path = Path();
    final dotPaint = Paint()..color = color;
    final linePaint = Paint()
      ..color = color.withOpacity(.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final xy = <Offset>[];
    for (int i = 0; i < count; i++) {
      final p = points[i];
      final x = leftPad + step * i;
      final y = topPad + chartH - ((p.points / maxValue).clamp(0, 1) * chartH);
      xy.add(Offset(x, y));
    }

    for (int i = 0; i < xy.length; i++) {
      if (i == 0) {
        path.moveTo(xy[i].dx, xy[i].dy);
      } else {
        path.lineTo(xy[i].dx, xy[i].dy);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(leftPad + chartW, topPad + chartH)
      ..lineTo(leftPad, topPad + chartH)
      ..close();

    final fillPaint = Paint()
      ..color = color.withOpacity(.10)
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (final p in xy) {
      canvas.drawCircle(p, 3.5, dotPaint);
    }

    final p = xy[selectedIndex];
    final vPaint = Paint()
      ..color = color.withOpacity(.35)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(p.dx, topPad),
      Offset(p.dx, topPad + chartH),
      vPaint,
    );

    canvas.drawCircle(p, 7.0, Paint()..color = color.withOpacity(.20));
    canvas.drawCircle(p, 5.0, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.color != color ||
        oldDelegate.axisColor != axisColor;
  }
}

/* ---------------- Usage summary ---------------- */

class _UsageSummary extends StatelessWidget {
  final List<_SeriesPoint> points;
  final _RangeMode mode;
  const _UsageSummary({required this.points, required this.mode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (points.isEmpty) {
      return Text(
        "No usage yet.",
        style: TextStyle(
          color: cs.onSurface.withOpacity(.7),
          fontWeight: FontWeight.w800,
        ),
      );
    }

    double total = 0;
    int totalReq = 0;
    double peak = -1;
    String peakKey = "";

    for (final p in points) {
      total += p.points;
      totalReq += p.requests;
      if (p.points > peak) {
        peak = p.points;
        peakKey = p.key;
      }
    }

    final avg = total / points.length;
    final peakLabel = mode == _RangeMode.month ? _prettyMonth(peakKey) : _prettyDay(peakKey);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withOpacity(.12)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _SummaryChip(label: "Total points", value: total.toInt().toString()),
          _SummaryChip(label: "Avg", value: avg.toInt().toString()),
          _SummaryChip(label: "Total requests", value: totalReq.toString()),
          _SummaryChip(label: "Peak", value: "${peak.toInt()} ( $peakLabel )"),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.primary.withOpacity(.08),
        border: Border.all(color: cs.primary.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withOpacity(.85),
            ),
          ),
        ],
      ),
    );
  }
}
