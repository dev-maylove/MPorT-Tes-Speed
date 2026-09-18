import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/security/security_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../server/services/server_service.dart';
import '../../speed_test/models/test_server.dart';

/// Server map — optimized:
/// - Load HTML once (do not reload when switching tabs)
/// - pan via JavaScript
/// - markers merged per coordinate
/// - lightweight tiles + preferCanvas
class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen>
    with AutomaticKeepAliveClientMixin {
  WebViewController? _controller;
  bool _loading = true;
  bool _mapReady = false;
  TestServer? _focus;
  late final List<TestServer> _servers;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _servers = ServerService.instance.servers
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();
    _focus = ServerService.instance.selected;
    // Delay WebView init by 1 frame so other tabs are not blocked
    WidgetsBinding.instance.addPostFrameCallback((_) => _initMap());
  }

  Future<void> _initMap() async {
    if (!mounted || _controller != null) return;

    final lat = _focus?.latitude ?? -6.7487;
    final lon = _focus?.longitude ?? 111.0379;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // required for Leaflet map
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // Block navigation to unexpected external hosts
            if (SecurityConfig.isWebViewUrlAllowed(request.url)) {
              return NavigationDecision.navigate;
            }
            SecurityConfig.log('WebView blocked navigation: ${request.url}');
            return NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _loading = false;
                _mapReady = true;
              });
            }
          },
        ),
      );

    _controller = controller;
    if (mounted) setState(() {});

    await controller.loadHtmlString(_mapHtml(lat, lon));
  }

  /// Merge servers at the same coordinates → fewer markers
  List<Map<String, dynamic>> _clusteredPoints() {
    final map = <String, Map<String, dynamic>>{};
    for (final s in _servers) {
      final lat = s.latitude;
      final lon = s.longitude;
      if (lat == null || lon == null) continue;
      final key = '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';
      if (!map.containsKey(key)) {
        map[key] = {
          'lat': lat,
          'lon': lon,
          'names': <String>[s.name],
          'loc': s.location,
          'km': s.distanceKm,
        };
      } else {
        (map[key]!['names'] as List<String>).add(s.name);
      }
    }
    return map.values.toList();
  }

  String _mapHtml(double lat, double lon) {
    final points = _clusteredPoints();
    final buf = StringBuffer();
    for (final p in points) {
      final names = (p['names'] as List<String>)
          .take(3)
          .map((n) => n.replaceAll("'", r"\'").replaceAll('"', r'\"'))
          .join('<br>');
      final extra = (p['names'] as List).length > 3
          ? '<br>+${(p['names'] as List).length - 3} server'
          : '';
      final loc = (p['loc'] as String).replaceAll("'", r"\'");
      buf.writeln(
        "L.marker([${p['lat']}, ${p['lon']}],{icon:serverIcon})"
        ".addTo(map).bindPopup('<b>$names$extra</b><br>$loc');",
      );
    }

    // Peta gaya original OSM + marker pin (lebih readable)
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"/>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
html,body,#map{margin:0;padding:0;height:100%;background:#e8eef5}
.leaflet-container{background:#e8eef5;font:12px sans-serif}
.leaflet-control-attribution{font-size:9px}
.server-pin{background:transparent;border:none}
.server-pin-inner{
  width:28px;height:28px;border-radius:50% 50% 50% 0;transform:rotate(-45deg);
  background:#00E5A0;border:2px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,.35);
}
.server-pin-inner:after{
  content:'';position:absolute;width:10px;height:10px;background:#fff;border-radius:50%;
  top:7px;left:7px;
}
</style>
</head>
<body>
<div id="map"></div>
<script>
var map=L.map('map',{
  zoomControl:true,
  preferCanvas:true
}).setView([$lat,$lon],10);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{
  attribution:'© OpenStreetMap',
  maxZoom:18
}).addTo(map);
var serverIcon=L.divIcon({
  className:'server-pin',
  html:'<div class="server-pin-inner"></div>',
  iconSize:[28,28],
  iconAnchor:[14,28],
  popupAnchor:[0,-28]
});
__MAP_MARKERS__
window.panTo=function(lat,lon,z){
  map.setView([lat,lon],z||12,{animate:true,duration:0.35});
};
</script>
</body>
</html>
'''.replaceFirst('__MAP_MARKERS__', buf.toString());
  }

  Future<void> _focusServer(TestServer s) async {
    if (s.latitude == null || s.longitude == null) return;
    setState(() => _focus = s);

    // Jangan reload HTML — cukup pan kamera
    if (_mapReady && _controller != null) {
      await _controller!.runJavaScript(
        'window.panTo(${s.latitude},${s.longitude},12);',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        automaticallyImplyLeading: false,
        title: const Text(
          'Server Map',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [appMenuButton(context)],
        iconTheme: const IconThemeData(color: AppColors.greenLight),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                if (_controller != null)
                  WebViewWidget(controller: _controller!)
                else
                  const ColoredBox(color: AppColors.background),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.green),
                  ),
              ],
            ),
          ),
          Container(
            height: 150,
            color: AppColors.surface,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: _servers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final s = _servers[i];
                final active = _focus?.id == s.id;
                return GestureDetector(
                  onTap: () => _focusServer(s),
                  child: Container(
                    width: 170,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active
                            ? AppColors.green
                            : AppColors.green.withValues(alpha: 0.2),
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.location,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          s.distanceKm != null
                              ? '${s.distanceKm} km'
                              : '',
                          style: const TextStyle(
                            color: AppColors.greenDim,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
