import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/models.dart';

String fmtMoney(num v, {bool sign = false}) {
  final f = NumberFormat('#,##0.00', 'en_US');
  final s = f.format(v.abs());
  if (sign) return v >= 0 ? '+¥$s' : '-¥$s';
  return '¥$s';
}

String fmtInt(num v) => NumberFormat('#,##0', 'en_US').format(v);
String fmtDate(DateTime d) => DateFormat('MM-dd HH:mm').format(d);
String fmtDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// 显示 API 调用结果（统一响应结构）
void showApiResult(BuildContext context, ApiResponse r, {String? successText}) {
  final ok = r.ok;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? XgColors.success : XgColors.danger,
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ok ? (successText ?? 'success') : r.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('code=${r.code} · trace_id=${r.traceId}${r.idempotencyReplay ? ' · Idempotency-Replay' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class Avatar extends StatelessWidget {
  final UserProfile user;
  final double size;
  const Avatar(this.user, {super.key, this.size = 44});
  @override
  Widget build(BuildContext context) {
    final grad = XgColors.agentGradient(user.userId.hashCode % 8);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: grad),
        boxShadow: [BoxShadow(color: grad.first.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      alignment: Alignment.center,
      child: Text(user.initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.42)),
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? bg;
  final IconData? icon;
  const Tag(this.text, {super.key, this.color, this.bg, this.icon});
  @override
  Widget build(BuildContext context) {
    final c = color ?? XgColors.navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg ?? c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 3)],
          Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

Color statusColor(String key) {
  switch (key) {
    case 'success':
    case 'ok':
      return XgColors.success;
    case 'warn':
      return XgColors.warning;
    case 'danger':
      return XgColors.danger;
    case 'info':
      return XgColors.info;
    default:
      return XgColors.textSecondary;
  }
}

Color orderStatusColor(int s) {
  if (s == 80 || s == 60) return XgColors.success;
  if (s == 55 || s == 70 || s == 81 || s == 31) return XgColors.danger;
  if (s == 50 || s == 40) return XgColors.warning;
  return XgColors.info;
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: XgColors.gold, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Row(children: [Text(action!, style: const TextStyle(color: XgColors.textSecondary, fontSize: 12)), const Icon(Icons.chevron_right, size: 16, color: XgColors.textSecondary)]),
            ),
        ],
      ),
    );
  }
}

class XCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  const XCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin = const EdgeInsets.symmetric(horizontal: 16), this.onTap, this.gradient});
  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? Colors.white : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: gradient == null ? Border.all(color: XgColors.divider) : null,
        boxShadow: gradient != null ? [BoxShadow(color: XgColors.navy.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))] : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class KV extends StatelessWidget {
  final String k;
  final String v;
  final Color? vColor;
  final bool bold;
  const KV(this.k, this.v, {super.key, this.vColor, this.bold = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: XgColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(v, style: TextStyle(color: vColor ?? XgColors.textPrimary, fontSize: 13, fontWeight: bold ? FontWeight.w600 : FontWeight.w400))),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final IconData? icon;
  const StatTile({super.key, required this.label, required this.value, this.color, this.icon});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: XgColors.divider)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) Icon(icon, size: 18, color: color ?? XgColors.navy),
            if (icon != null) const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color ?? XgColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// 状态机步骤条
class StateFlow extends StatelessWidget {
  final List<int> steps;
  final int current;
  final String Function(int) label;
  final bool failed;
  const StateFlow({super.key, required this.steps, required this.current, required this.label, this.failed = false});
  @override
  Widget build(BuildContext context) {
    final idx = steps.indexOf(current);
    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= idx ? (failed && i == idx ? XgColors.danger : XgColors.navy) : Colors.white,
                    border: Border.all(color: i <= idx ? Colors.transparent : XgColors.divider, width: 2),
                  ),
                  child: i < idx ? const Icon(Icons.check, size: 13, color: Colors.white) : (i == idx ? Icon(failed ? Icons.close : Icons.circle, size: failed ? 13 : 8, color: Colors.white) : null),
                ),
                const SizedBox(height: 4),
                Text(label(steps[i]), style: TextStyle(fontSize: 9, color: i <= idx ? XgColors.textPrimary : XgColors.textSecondary, fontWeight: i == idx ? FontWeight.w700 : FontWeight.w400), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (i < steps.length - 1) Container(width: 8, height: 2, margin: const EdgeInsets.only(bottom: 16), color: i < idx ? XgColors.navy : XgColors.divider),
        ],
      ],
    );
  }
}

class GradientAvatar extends StatelessWidget {
  final AgentDef agent;
  final double size;
  const GradientAvatar(this.agent, {super.key, this.size = 52});
  @override
  Widget build(BuildContext context) {
    final g = XgColors.agentGradient(agent.gradientIndex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: g.first.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      alignment: Alignment.center,
      child: Text(agent.emoji, style: TextStyle(fontSize: size * 0.45)),
    );
  }
}

/// 简易折线图（赎回轨迹）
class MiniLineChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  const MiniLineChart({super.key, required this.values, this.color = XgColors.gold, this.height = 90});
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _LinePainter(values, color)));
  }
}

class _LinePainter extends CustomPainter {
  final List<double> v;
  final Color c;
  _LinePainter(this.v, this.c);
  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final maxV = v.reduce((a, b) => a > b ? a : b);
    final minV = v.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV) == 0 ? 1 : (maxV - minV);
    final pts = <Offset>[];
    for (int i = 0; i < v.length; i++) {
      final x = i / (v.length - 1) * size.width;
      final y = size.height - ((v[i] - minV) / range) * (size.height - 10) - 5;
      pts.add(Offset(x, y));
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawPath(path, Paint()..color = c..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawCircle(pts.last, 4, Paint()..color = c);
    canvas.drawCircle(pts.last, 7, Paint()..color = c.withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.v != v;
}

class ProgressRing extends StatelessWidget {
  final double pct;
  final double size;
  final Widget child;
  const ProgressRing({super.key, required this.pct, this.size = 120, required this.child});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(width: size, height: size, child: CircularProgressIndicator(value: 1, strokeWidth: 10, color: Colors.white.withValues(alpha: 0.15))),
          SizedBox(width: size, height: size, child: CircularProgressIndicator(value: (pct / 100).clamp(0, 1), strokeWidth: 10, color: XgColors.gold, strokeCap: StrokeCap.round)),
          child,
        ],
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyHint(this.text, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(children: [Icon(icon, size: 48, color: XgColors.divider), const SizedBox(height: 12), Text(text, style: const TextStyle(color: XgColors.textSecondary))]),
    );
  }
}

Future<T?> showXSheet<T>(BuildContext context, Widget child, {String? title}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(color: XgColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: XgColors.divider, borderRadius: BorderRadius.circular(2))),
          if (title != null) Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 4), child: Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge))])),
          Flexible(child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: child)),
        ],
      ),
    ),
  );
}
