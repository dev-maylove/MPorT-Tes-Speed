import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../server/services/server_service.dart';
import '../../speed_test/models/test_server.dart';

/// Peta server — dioptimalkan:
/// - 1x load HTML (tidak reload saat ganti fokus)
/// - pan via JavaScript
/// - marker digabung per koordinat
/// - tile ringan + preferCanvas
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
    // Delay init WebView 1 frame agar tab lain tidak terblokir
    WidgetsBinding.instance.addPostFrameCallback((_) => _initMap());
  }

  Future<void> _initMap() async {
    if (!mounted || _controller != null) return;

    final lat = _focus?.latitude ?? -6.7487;
    final lon = _focus?.longitude ?? 111.0379;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
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

  /// Gabungkan server di koordinat yang sama → lebih sedikit marker
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
        "L.circleMarker([${p['lat']}, ${p['lon']}],{"
        "radius:7,color:'#00E5A0',fillColor:'#5CFFC9',fillOpacity:0.85,weight:1"
        "}).addTo(map).bindPopup('<b>$names$extra</b><br>$loc');",
      );
    }

    // HTML ringkas: Leaflet dari CDN, preferCanvas, tanpa shadow marker
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"/>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
html,body,#map{margin:0;padding:0;height:100%;background:#06080F}
.leaflet-container{background:#0a0e17;font:12px sans-serif}
.leaflet-control-attribution{font-size:9px;background:rgba(0,0,0,.5)!important;color:#5CFFC9!important}
</style>
</head>
<body>
<div id="map"></div>
<script>
var map=L.map('map',{
  zoomControl:true,
  preferCanvas:true,
  fadeAnimation:false,
  zoomAnimation:true,
  markerZoomAnimation:false
}).setView([$lat,$lon],10);
L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',{
  attribution:'©OSM ©CARTO',
  maxZoom:16,
  maxNativeZoom:16,
  updateWhenIdle:true,
  keepBuffer:1
}).addTo(map);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Peta Server',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
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
