import 'package:flutter/material.dart';

const _lime = Color(0xFF84E221);
const _ink = Color(0xFF232824);
const _muted = Color(0xFF858C83);
const _bg = Color(0xFFF6F7F4);

class GymFinderScreen extends StatefulWidget {
  const GymFinderScreen({super.key});
  @override State<GymFinderScreen> createState() => _GymFinderScreenState();
}
class _GymFinderScreenState extends State<GymFinderScreen> {
  final _searchController = TextEditingController();
  String _category = 'All';
  static const _categories = ['All', 'Gym', 'Yoga', 'Swimming', 'Sports'];
  @override void dispose() { _searchController.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 28), children: [
      const Text('Gym Finder', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 5),
      const Text('Find a place that fits your routine.', style: TextStyle(fontSize: 13, color: _muted)),
      const SizedBox(height: 18),
      TextField(controller: _searchController, onChanged: (_) => setState(() {}), decoration: InputDecoration(
        hintText: 'Search gyms or activities', prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded)),
      )),
      const SizedBox(height: 14),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _categories.map((category) {
        final selected = _category == category;
        return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
          label: Text(category), selected: selected, onSelected: (_) => setState(() => _category = category),
          selectedColor: _lime, backgroundColor: Colors.white, side: BorderSide.none, showCheckmark: false, shape: const StadiumBorder(),
          labelStyle: TextStyle(color: _ink, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
        ));
      }).toList())),
      const SizedBox(height: 18),
      Container(height: 205, decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(24)), clipBehavior: Clip.antiAlias, child: Stack(children: [
        Positioned(right: -45, top: -70, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _lime.withValues(alpha: 0.25), width: 2)))),
        Positioned(left: -50, bottom: -115, child: Container(width: 230, height: 230, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 2)))),
        const Padding(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.map_outlined, color: _lime, size: 32), SizedBox(height: 12),
          Text('Your next workout is out there.', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
          SizedBox(height: 6), Text('Explore fitness spots around you.', style: TextStyle(color: Color(0xFFD5D9D2), fontSize: 12)),
        ])),
        Positioned(right: 16, bottom: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: _lime, borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.location_searching_rounded, size: 15, color: _ink), SizedBox(width: 5), Text('Nearby', style: TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w800))]))),
      ])),
      const SizedBox(height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Explore places', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
        Text(_category == 'All' ? 'All activities' : _category, style: const TextStyle(fontSize: 11, color: _muted)),
      ]),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: Column(children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(color: const Color(0xFFEAF7D9), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.location_on_outlined, color: _ink, size: 30)),
        const SizedBox(height: 12),
        Text(_searchController.text.trim().isEmpty ? 'Connect to discover nearby gyms' : 'No results for “${_searchController.text.trim()}”', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 7),
        const Text('Live locations will appear here after Google Maps and location permissions are configured. No sample gyms are shown as real places.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.5, color: _muted)),
        const SizedBox(height: 15),
        OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gym Finder needs a Google Maps API key and location setup before it can search real places.'))), icon: const Icon(Icons.info_outline_rounded), label: const Text('Setup required'), style: OutlinedButton.styleFrom(foregroundColor: _ink, side: const BorderSide(color: Color(0xFFE3E7DF)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      ])),
    ])),
  );
}
