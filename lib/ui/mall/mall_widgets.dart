import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../state/mall_state.dart';
import '../widgets/common.dart';

/// ───────────────────────── 星光云 · 设计系统 ─────────────────────────
/// 暖白底 + 墨蓝主色 + 香槟金点缀；大圆角、柔和投影、留白充足。
class Sx {
  static const ink = Color(0xFF1B2440); // 主文字 / 主色
  static const inkSoft = Color(0xFF4A5372);
  static const muted = Color(0xFF8A90A6);
  static const line = Color(0xFFEDEAE4);
  static const bg = Color(0xFFF7F5F1);
  static const card = Colors.white;
  static const gold = Color(0xFFC9A063);
  static const goldSoft = Color(0xFFF6EEDF);
  static const mint = Color(0xFF2FA37A); // 清偿 / 成功
  static const mintSoft = Color(0xFFE6F5EE);
  static const coral = Color(0xFFE86A4F); // 价格
  static const blue = Color(0xFF3D6AF2);
  static const blueSoft = Color(0xFFEBF0FE);
  static const r = 18.0;

  static const heroGrad = LinearGradient(colors: [Color(0xFF1B2440), Color(0xFF2C3A66)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const goldGrad = LinearGradient(colors: [Color(0xFFE7C38A), Color(0xFFC9A063)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const mintGrad = LinearGradient(colors: [Color(0xFF3FBF8F), Color(0xFF2A8F6B)], begin: Alignment.topLeft, end: Alignment.bottomRight);

  static List<BoxShadow> shadow([double o = 0.06]) => [BoxShadow(color: const Color(0xFF1B2440).withValues(alpha: o), blurRadius: 24, offset: const Offset(0, 8))];

  static const h1 = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink, height: 1.25, letterSpacing: 0.2);
  static const h2 = TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink);
  static const h3 = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink);
  static const body = TextStyle(fontSize: 13, color: inkSoft, height: 1.55);
  static const small = TextStyle(fontSize: 11, color: muted, height: 1.4);
}

String yuan(num v) => fmtMoney(v);
String fmtDp(num v) => fmtMoney(v); // 清偿金以人民币计（1 元清偿金可核减 1 元账单）

void mallToast(BuildContext context, String msg, {bool ok = true}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: ok ? Sx.ink : const Color(0xFFB4413A),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    content: Row(children: [
      Icon(ok ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: ok ? Sx.gold : Colors.white, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
    ]),
  ));
}

Future<T?> mallRun<T>(BuildContext context, Future<T> Function() fn, {String? success}) async {
  try {
    final r = await fn();
    if (success != null && context.mounted) mallToast(context, success);
    return r;
  } catch (e) {
    if (context.mounted) mallToast(context, e.toString(), ok: false);
    return null;
  }
}

/// 网络图片：默认取 320px 缩略图（@s.webp），大图场景传 full: true
class MallImage extends StatelessWidget {
  final String? src;
  final String emoji;
  final double? width;
  final double? height;
  final double radius;
  final bool full;
  final BoxFit fit;
  final Alignment alignment;
  const MallImage(this.src, {super.key, this.emoji = '🛍️', this.width, this.height, this.radius = 14, this.full = false, this.fit = BoxFit.cover, this.alignment = Alignment.center});
  @override
  Widget build(BuildContext context) {
    var url = mallAsset(src);
    if (url != null && !full && url.endsWith('.webp') && !url.contains('@s')) url = url.replaceFirst(RegExp(r'\.webp$'), '@s.webp');
    final fallback = Container(color: Sx.goldSoft, alignment: Alignment.center, child: Text(emoji, style: TextStyle(fontSize: ((height ?? 60) * 0.4).clamp(14, 48))));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: fit,
                alignment: alignment,
                gaplessPlayback: true,
                frameBuilder: (_, child, frame, sync) => sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 280), child: frame == null ? Container(color: Sx.goldSoft) : child),
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

/// 媒体图（/media/img/{key}.webp）
String mediaImg(String key, {bool small = false}) => '/media/img/$key${small ? '@s' : ''}.webp';

/// 可返清偿金徽章
class ReturnBadge extends StatelessWidget {
  final double amount;
  final bool small;
  final bool onImage;
  const ReturnBadge(this.amount, {super.key, this.small = false, this.onImage = false});
  @override
  Widget build(BuildContext context) {
    final text = '返 ${fmtMoney(amount)}';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 7 : 9, vertical: small ? 3 : 4),
      decoration: BoxDecoration(color: onImage ? Colors.white.withValues(alpha: 0.94) : Sx.mintSoft, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.eco_rounded, size: small ? 11 : 13, color: Sx.mint),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(color: Sx.mint, fontSize: small ? 10 : 11.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// 兼容旧调用
class DpBadge extends ReturnBadge {
  const DpBadge(super.amount, {super.key, super.small});
}

class PriceText extends StatelessWidget {
  final double price;
  final double size;
  final double? original;
  const PriceText(this.price, {super.key, this.size = 17, this.original});
  @override
  Widget build(BuildContext context) {
    final s = price.toStringAsFixed(price == price.roundToDouble() ? 0 : (price * 10 == (price * 10).roundToDouble() ? 1 : 2));
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
      Text('¥', style: TextStyle(fontSize: size * 0.68, fontWeight: FontWeight.w800, color: Sx.coral)),
      Text(s, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: Sx.coral, letterSpacing: -0.3)),
      if (original != null && original! > price) ...[
        const SizedBox(width: 5),
        Text('¥${original!.toStringAsFixed(original! == original!.roundToDouble() ? 0 : 1)}', style: TextStyle(fontSize: size * 0.6, color: Sx.muted, decoration: TextDecoration.lineThrough)),
      ],
    ]);
  }
}

/// 卡片
class SCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  const SCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12), this.onTap, this.color, this.gradient});
  @override
  Widget build(BuildContext context) {
    final box = Container(
      margin: margin,
      decoration: BoxDecoration(color: gradient == null ? (color ?? Sx.card) : null, gradient: gradient, borderRadius: BorderRadius.circular(Sx.r), boxShadow: Sx.shadow(0.05)),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Sx.r),
        child: InkWell(borderRadius: BorderRadius.circular(Sx.r), onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
    return box;
  }
}

class SHeader extends StatelessWidget {
  final String title;
  final String? sub;
  final String? action;
  final VoidCallback? onAction;
  const SHeader(this.title, {super.key, this.sub, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Sx.h2),
            if (sub != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub!, style: Sx.small)),
          ])),
          if (action != null)
            InkWell(onTap: onAction, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.all(4), child: Row(children: [Text(action!, style: const TextStyle(fontSize: 12, color: Sx.muted)), const Icon(Icons.chevron_right_rounded, size: 18, color: Sx.muted)]))),
        ]),
      );
}

class SPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color? bg;
  final IconData? icon;
  const SPill(this.text, {super.key, this.color = Sx.inkSoft, this.bg, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg ?? color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
          Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ]),
      );
}

class SButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;
  final bool loading;
  final bool gold;
  const SButton(this.text, {super.key, this.onTap, this.primary = true, this.icon, this.loading = false, this.gold = false});
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final bgc = gold ? null : (primary ? Sx.ink : Colors.white);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(color: bgc, gradient: gold ? Sx.goldGrad : null, borderRadius: BorderRadius.circular(26), border: primary || gold ? null : Border.all(color: Sx.line, width: 1.2)),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: enabled ? onTap : null,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              alignment: Alignment.center,
              child: loading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primary || gold ? Colors.white : Sx.ink))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icon != null) ...[Icon(icon, size: 18, color: primary || gold ? Colors.white : Sx.ink), const SizedBox(width: 6)],
                      Text(text, style: TextStyle(color: primary || gold ? Colors.white : Sx.ink, fontWeight: FontWeight.w800, fontSize: 15)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

class SEmpty extends StatelessWidget {
  final String img;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const SEmpty(this.text, {super.key, this.img = 'orders_empty', this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(40, 36, 40, 24),
        child: Column(children: [
          MallImage(mediaImg(img), width: 140, height: 140, radius: 70),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: Sx.body),
          if (action != null) ...[const SizedBox(height: 14), SizedBox(width: 180, child: SButton(action!, onTap: onAction))],
        ]),
      );
}

/// 连接状态
class MallGate extends StatelessWidget {
  final Widget Function(BuildContext, MallState) builder;
  const MallGate({super.key, required this.builder});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    if (m.ready && m.me != null) return builder(context, m);
    if (m.connecting || m.connectError == null) return const Center(child: CircularProgressIndicator(color: Sx.gold));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 56, color: Sx.muted),
          const SizedBox(height: 12),
          Text(m.connectError!, textAlign: TextAlign.center, style: Sx.body),
          const SizedBox(height: 16),
          SizedBox(width: 160, child: SButton('重新连接', icon: Icons.refresh_rounded, onTap: m.connect)),
        ]),
      ),
    );
  }
}

class Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) builder;
  const Loader({super.key, required this.load, required this.builder});
  @override
  State<Loader<T>> createState() => LoaderState<T>();
}

class LoaderState<T> extends State<Loader<T>> {
  late Future<T> _f;
  T? _last;
  @override
  void initState() {
    super.initState();
    _f = widget.load();
  }

  void reload() => setState(() => _f = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _f,
      builder: (ctx, snap) {
        if (snap.hasData) _last = snap.data;
        if (snap.connectionState != ConnectionState.done && _last == null) return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Sx.gold)));
        if (snap.hasError && _last == null) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${snap.error}', style: const TextStyle(color: Sx.coral)),
            TextButton(onPressed: reload, child: const Text('重试')),
          ])));
        }
        return RefreshIndicator(color: Sx.gold, onRefresh: () async => reload(), child: widget.builder(ctx, _last as T, reload));
      },
    );
  }
}

Color orderColor(int s) => switch (s) {
      10 => Sx.coral,
      20 || 30 => Sx.blue,
      40 => Sx.mint,
      60 => Sx.coral,
      _ => Sx.muted,
    };

Color commissionColor(int? s) => switch (s) {
      0 => Sx.muted,
      1 => Sx.gold,
      2 => Sx.mint,
      _ => Sx.muted,
    };

// ───────────────────────── 视频指引 ─────────────────────────

/// 页面顶部的「看视频 · 30 秒了解」指引条；点击全屏播放
class GuideStrip extends StatelessWidget {
  final String guideKey;
  final EdgeInsets margin;
  final bool dark;
  const GuideStrip(this.guideKey, {super.key, this.margin = const EdgeInsets.fromLTRB(16, 12, 16, 0), this.dark = false});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    final g = m.guide(guideKey);
    if (g == null) return const SizedBox.shrink();
    final watched = m.watchedGuides.contains(g.key);
    final fg = dark ? Colors.white : Sx.ink;
    return Padding(
      padding: margin,
      child: Material(
        color: dark ? Colors.white.withValues(alpha: 0.12) : Sx.goldSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => playGuide(context, g.key),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 44,
                  height: 56,
                  child: Stack(fit: StackFit.expand, children: [
                    MallImage(g.poster, radius: 0, full: true),
                    Container(color: Colors.black26),
                    const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 24)),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(g.badge, style: TextStyle(fontSize: 10.5, color: dark ? Sx.gold : Sx.gold, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  if (watched) Icon(Icons.check_circle_rounded, size: 12, color: dark ? Colors.white70 : Sx.mint),
                ]),
                const SizedBox(height: 2),
                Text(g.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: fg)),
                Text(g.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: dark ? Colors.white70 : Sx.muted)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: dark ? Colors.white : Sx.ink, borderRadius: BorderRadius.circular(20)),
                child: Text(watched ? '再看一遍' : '看视频', style: TextStyle(fontSize: 11, color: dark ? Sx.ink : Colors.white, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 竖版视频卡（用于指引中心/首页横滑）
class GuideCard extends StatelessWidget {
  final Guide g;
  final double width;
  const GuideCard(this.g, {super.key, this.width = 128});
  @override
  Widget build(BuildContext context) {
    final watched = context.watch<MallState>().watchedGuides.contains(g.key);
    return GestureDetector(
      onTap: () => playGuide(context, g.key),
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(fit: StackFit.expand, children: [
              MallImage(g.poster, radius: 0, full: true),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.45, 1], colors: [Colors.transparent, Color(0xDD10162B)]))),
              Positioned(left: 8, top: 8, child: SPill(g.badge, color: Colors.white, bg: Colors.black38)),
              if (watched) const Positioned(right: 8, top: 8, child: Icon(Icons.check_circle_rounded, color: Sx.gold, size: 18)),
              const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40)),
              Positioned(left: 10, right: 10, bottom: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 2),
                Text(g.subtitle, maxLines: 2, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.3)),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 全屏播放；可左右切换上一步/下一步
Future<void> playGuide(BuildContext context, String key) {
  final m = context.read<MallState>();
  final idx = m.guides.indexWhere((g) => g.key == key);
  if (idx < 0) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black,
    pageBuilder: (_, __, ___) => ChangeNotifierProvider.value(value: m, child: _GuidePlayer(start: idx)),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

class _GuidePlayer extends StatefulWidget {
  final int start;
  const _GuidePlayer({required this.start});
  @override
  State<_GuidePlayer> createState() => _GuidePlayerState();
}

class _GuidePlayerState extends State<_GuidePlayer> {
  late int _i = widget.start;
  VideoPlayerController? _c;
  bool _err = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final old = _c;
    _c = null;
    _err = false;
    if (mounted) setState(() {});
    final m = context.read<MallState>();
    await old?.dispose();
    final g = m.guides[_i];
    final c = VideoPlayerController.networkUrl(Uri.parse(mallAsset(g.video)!));
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(() {
        if (!mounted) return;
        final v = c.value;
        if (v.isInitialized && v.position >= v.duration - const Duration(milliseconds: 250) && !v.isPlaying) {
          m.markWatched(g.key);
        }
        setState(() {});
      });
      setState(() => _c = c);
      await c.play();
    } catch (_) {
      if (mounted) setState(() => _err = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  void _go(int d) {
    final n = context.read<MallState>().guides.length;
    final ni = _i + d;
    if (ni < 0 || ni >= n) return;
    _i = ni;
    _open();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    final g = m.guides[_i];
    final c = _c;
    final v = c?.value;
    final done = v != null && v.isInitialized && v.position >= v.duration - const Duration(milliseconds: 250);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  Expanded(child: Column(children: [
                    Text(g.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('${g.badge} · ${_i + 1}/${m.guides.length}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ])),
                  const SizedBox(width: 48),
                ]),
              ),
              // 进度点
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(children: [
                  for (var k = 0; k < m.guides.length; k++)
                    Expanded(child: Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: k < _i ? Sx.gold : (k == _i ? Colors.white : Colors.white24), borderRadius: BorderRadius.circular(2)))),
                ]),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (c == null) return;
                    if (done) {
                      c.seekTo(Duration.zero);
                      c.play();
                    } else {
                      v!.isPlaying ? c.pause() : c.play();
                    }
                  },
                  onHorizontalDragEnd: (d) {
                    final vx = d.primaryVelocity ?? 0;
                    if (vx < -200) _go(1);
                    if (vx > 200) _go(-1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: Stack(fit: StackFit.expand, children: [
                          if (c != null && v!.isInitialized) FittedBox(fit: BoxFit.cover, child: SizedBox(width: v.size.width, height: v.size.height, child: VideoPlayer(c))) else MallImage(g.poster, radius: 0, full: true),
                          if (c == null && !_err) const Center(child: CircularProgressIndicator(color: Colors.white)),
                          if (_err) const Center(child: Text('视频加载失败，请检查网络', style: TextStyle(color: Colors.white))),
                          if (v != null && v.isInitialized && !v.isPlaying && !done) const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 72)),
                          if (done)
                            Container(
                              color: Colors.black54,
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.check_circle_rounded, color: Sx.gold, size: 48),
                                const SizedBox(height: 10),
                                Text('已看完「${g.title}」', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                const SizedBox(height: 18),
                                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  TextButton.icon(onPressed: () { c!.seekTo(Duration.zero); c.play(); }, icon: const Icon(Icons.replay_rounded, color: Colors.white), label: const Text('重播', style: TextStyle(color: Colors.white))),
                                  const SizedBox(width: 10),
                                  if (_i < m.guides.length - 1) FilledButton(style: FilledButton.styleFrom(backgroundColor: Sx.gold), onPressed: () => _go(1), child: Text('下一步：${m.guides[_i + 1].title}')),
                                  if (_i == m.guides.length - 1) FilledButton(style: FilledButton.styleFrom(backgroundColor: Sx.gold), onPressed: () => Navigator.pop(context), child: const Text('开始使用')),
                                ]),
                              ]),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              if (v != null && v.isInitialized)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 22), child: VideoProgressIndicator(c!, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Sx.gold, bufferedColor: Colors.white24, backgroundColor: Colors.white12))),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
                child: Text(g.narration, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.6)),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton.icon(onPressed: _i > 0 ? () => _go(-1) : null, icon: const Icon(Icons.chevron_left_rounded), label: const Text('上一步'), style: TextButton.styleFrom(foregroundColor: Colors.white, disabledForegroundColor: Colors.white24)),
                TextButton.icon(onPressed: _i < m.guides.length - 1 ? () => _go(1) : null, label: const Text('下一步'), icon: const Icon(Icons.chevron_right_rounded), iconAlignment: IconAlignment.end, style: TextButton.styleFrom(foregroundColor: Colors.white, disabledForegroundColor: Colors.white24)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
