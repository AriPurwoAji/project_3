import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

class LocationResult {
  final String address;
  final String city;
  final double latitude;
  final double longitude;

  const LocationResult({
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
  });
}

class LocationSearchField extends StatefulWidget {
  final Function(LocationResult) onSelected;
  final String? initialValue;

  const LocationSearchField({
    super.key,
    required this.onSelected,
    this.initialValue,
  });

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  final _ctrl = TextEditingController();
  final _dio  = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'User-Agent': 'HydroServApp/1.0 (ajiaripurwo@gmail.com)'},
  ));

  Timer? _debounce;
  List<Map<String, dynamic>> _results    = [];
  bool _searching   = false;
  bool _gpsLoading  = false;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) _ctrl.text = widget.initialValue!;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _dio.close();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() { _results = []; _showDropdown = false; });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 600),
      () => _search(value.trim()),
    );
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': '5',
          'countrycodes': 'id',
          'addressdetails': '1',
        },
      );
      if (!mounted) return;
      final data = (res.data as List).cast<Map<String, dynamic>>();
      setState(() {
        _results       = data;
        _showDropdown  = data.isNotEmpty;
        _searching     = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectResult(Map<String, dynamic> item) {
    final address = item['display_name'] as String? ?? '';
    final addr    = (item['address'] as Map?)?.cast<String, dynamic>() ?? {};
    final city    = _extractCity(addr);
    final lat     = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
    final lng     = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;

    _ctrl.text = address;
    setState(() { _results = []; _showDropdown = false; });
    widget.onSelected(LocationResult(
      address: address,
      city: city,
      latitude: lat,
      longitude: lng,
    ));
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _gpsLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': pos.latitude,
          'lon': pos.longitude,
          'format': 'json',
        },
      );

      if (!mounted) return;
      final data    = res.data as Map<String, dynamic>;
      final address = data['display_name'] as String? ?? '';
      final addr    = (data['address'] as Map?)?.cast<String, dynamic>() ?? {};
      final city    = _extractCity(addr);

      _ctrl.text = address;
      setState(() { _results = []; _showDropdown = false; });
      widget.onSelected(LocationResult(
        address: address,
        city: city,
        latitude: pos.latitude,
        longitude: pos.longitude,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mendapatkan lokasi GPS')),
        );
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  String _extractCity(Map<String, dynamic> addr) =>
      (addr['city'] ??
       addr['town'] ??
       addr['municipality'] ??
       addr['county'] ??
       addr['state'] ??
       '').toString();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _ctrl,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Ketik nama tempat atau alamat...',
            prefixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search_outlined, size: 20,
                    color: AppTheme.textTertiary),
            suffixIcon: _gpsLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.my_location_outlined,
                        size: 20, color: AppTheme.primary),
                    tooltip: 'Gunakan lokasi GPS saat ini',
                    onPressed: _useCurrentLocation,
                  ),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Lokasi wajib diisi' : null,
        ),

        // Dropdown hasil pencarian
        if (_showDropdown)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: _results.asMap().entries.map((e) {
                final idx  = e.key;
                final item = e.value;
                final name = item['display_name'] as String? ?? '';
                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined,
                          size: 18, color: AppTheme.primary),
                      title: Text(name,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      onTap: () => _selectResult(item),
                    ),
                    if (idx < _results.length - 1)
                      const Divider(height: 1, indent: 48),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
