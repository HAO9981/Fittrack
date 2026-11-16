import 'package:flutter/material.dart';
import '../../models/workout.dart';
import 'workout_detail_screen.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);
const _surface = Color(0xFF141B17);
const _border = Color(0xFF27332B);

class WorkoutCalendarScreen extends StatefulWidget {
  const WorkoutCalendarScreen({super.key, required this.workouts});
  final List<Workout> workouts;
  @override
  State<WorkoutCalendarScreen> createState() => _WorkoutCalendarScreenState();
}

class _WorkoutCalendarScreenState extends State<WorkoutCalendarScreen> {
  late DateTime _month;
  late DateTime _selectedDay;
  String _category = 'All';

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  @override
  void initState() {
    super.initState();
    _selectedDay = _day(DateTime.now());
    _month = DateTime(_selectedDay.year, _selectedDay.month);
  }

  String _monthName(DateTime d) {
    const names = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return names[d.month - 1] + ' ' + d.year.toString();
  }

  List<Workout> get _filtered {
    final list = widget.workouts.where((w) => _category == 'All' || w.category == _category).toList();
    list.sort((a,b) => b.date.compareTo(a.date));
    return list;
  }

  List<Workout> _forDay(DateTime day) => _filtered.where((w) => _day(w.date) == day).toList();

  @override
  Widget build(BuildContext context) {
    final categories = <String>{'All', ...widget.workouts.map((w) => w.category)}.toList();
    final monthItems = _filtered.where((w) => w.date.year == _month.year && w.date.month == _month.month).toList();
    final dayItems = _forDay(_selectedDay);
    final monthMinutes = monthItems.fold<int>(0, (sum,w) => sum + w.durationInMinutes);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = DateTime(_month.year, _month.month, 1).weekday - 1;
    final cells = ((offset + days + 6) ~/ 7) * 7;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, foregroundColor: _ink, title: const Text('Workout Calendar')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Expanded(child: Text('Training history', style: TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w800))),
          DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _category, dropdownColor: _surface, style: const TextStyle(color: _ink, fontSize: 12),
            items: categories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _category = v ?? 'All'),
          )),
        ]),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)), child: Column(children: [
          Row(children: [
            IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left, color: _ink)),
            Expanded(child: Text(_monthName(_month), textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right, color: _ink)),
          ]),
          const Row(children: [_Weekday('M'),_Weekday('T'),_Weekday('W'),_Weekday('T'),_Weekday('F'),_Weekday('S'),_Weekday('S')]),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: cells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 5, crossAxisSpacing: 3, childAspectRatio: .85),
            itemBuilder: (context,index) {
              final n = index - offset + 1;
              if (n < 1 || n > days) return const SizedBox.shrink();
              final date = DateTime(_month.year,_month.month,n);
              final count = _forDay(date).length;
              final selected = _day(_selectedDay) == date;
              final today = _day(DateTime.now()) == date;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _selectedDay = date),
                child: Container(
                  decoration: BoxDecoration(color: selected ? _lime : Colors.transparent, borderRadius: BorderRadius.circular(10), border: today && !selected ? Border.all(color: _lime) : null),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(n.toString(), style: TextStyle(color: selected ? _bg : _ink, fontSize: 12, fontWeight: selected || today ? FontWeight.w800 : FontWeight.w500)),
                    const SizedBox(height: 3),
                    Container(width: 5,height: 5,decoration: BoxDecoration(shape: BoxShape.circle,color: count > 0 ? (selected ? _bg : _lime) : Colors.transparent)),
                  ]),
                ),
              );
            },
          ),
          Row(children: [
            const Icon(Icons.circle, color: _lime, size: 8), const SizedBox(width: 6),
            const Text('Workout logged', style: TextStyle(color: _muted, fontSize: 10)), const Spacer(),
            TextButton(onPressed: () => setState(() { _selectedDay = _day(DateTime.now()); _month = DateTime.now(); }), child: const Text('Today', style: TextStyle(color: _lime))),
          ]),
        ])),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _MonthStat(label: 'MONTHLY WORKOUTS', value: monthItems.length.toString(), icon: Icons.fitness_center)),
          const SizedBox(width: 9),
          Expanded(child: _MonthStat(label: 'TRAINING TIME', value: monthMinutes.toString() + ' min', icon: Icons.schedule)),
        ]),
        const SizedBox(height: 20),
        Text(_selectedDay.day.toString() + ' ' + _monthName(_selectedDay).split(' ').first + ' workouts', style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        if (dayItems.isEmpty)
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: _border)), child: const Column(children: [
            Icon(Icons.event_busy, color: _muted, size: 28), SizedBox(height: 8),
            Text('No workouts on this day', style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
            SizedBox(height: 4), Text('Choose another date to view its training history.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 11)),
          ]))
        else
          ...dayItems.map((w) => _WorkoutHistoryTile(workout: w)),
        const SizedBox(height: 18),
        Text(_monthName(_month) + ' history', style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (monthItems.isEmpty)
          const Text('No saved workouts for this month and filter.', style: TextStyle(color: _muted, fontSize: 12))
        else
          ...monthItems.map((w) => _WorkoutHistoryTile(workout: w)),
      ]),
    );
  }
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(child: Center(child: Text(label, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700))));
}

class _MonthStat extends StatelessWidget {
  const _MonthStat({required this.label, required this.value, required this.icon});
  final String label,value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: _border)), child: Row(children: [
    Icon(icon,color: _lime,size: 18), const SizedBox(width: 9),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,style: const TextStyle(color: _ink,fontWeight: FontWeight.w800,fontSize: 17)),
      Text(label,style: const TextStyle(color: _muted,fontSize: 8,fontWeight: FontWeight.w700)),
    ])),
  ]));
}

class _WorkoutHistoryTile extends StatelessWidget {
  const _WorkoutHistoryTile({required this.workout});
  final Workout workout;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: _surface,borderRadius: BorderRadius.circular(14),border: Border.all(color: _border)),
    child: ListTile(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workout: workout))),
      leading: Container(width: 40,height: 40,decoration: BoxDecoration(color: const Color(0xFF25351D),borderRadius: BorderRadius.circular(12)),child: const Icon(Icons.fitness_center,color: _lime,size: 19)),
      title: Text(workout.name,style: const TextStyle(color: _ink,fontSize: 13,fontWeight: FontWeight.w700)),
      subtitle: Text(workout.category + ' · ' + workout.formattedDuration,style: const TextStyle(color: _muted,fontSize: 11)),
      trailing: const Icon(Icons.chevron_right,color: _muted),
    ),
  );
}
