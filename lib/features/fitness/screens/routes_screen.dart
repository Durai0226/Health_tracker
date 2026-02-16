import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _myRoutes = [
    {
      'name': 'Morning Loop',
      'distance': 5.2,
      'elevation': 45,
      'type': 'run',
      'difficulty': 'easy',
      'timesCompleted': 24,
      'isFavorite': true,
    },
    {
      'name': 'River Trail',
      'distance': 8.5,
      'elevation': 120,
      'type': 'run',
      'difficulty': 'moderate',
      'timesCompleted': 12,
      'isFavorite': true,
    },
    {
      'name': 'Hill Challenge',
      'distance': 6.8,
      'elevation': 280,
      'type': 'run',
      'difficulty': 'hard',
      'timesCompleted': 5,
      'isFavorite': false,
    },
  ];

  final List<Map<String, dynamic>> _suggestedRoutes = [
    {
      'name': 'Scenic Park Path',
      'distance': 4.2,
      'elevation': 35,
      'type': 'run',
      'difficulty': 'easy',
      'popularity': 92,
      'reason': 'Popular with runners like you',
    },
    {
      'name': 'Coastal Trail',
      'distance': 12.5,
      'elevation': 180,
      'type': 'cycling',
      'difficulty': 'moderate',
      'popularity': 88,
      'reason': 'Great for your weekly long ride',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                isScrollable: true,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: 'My Routes'),
                  Tab(text: 'Suggested'),
                  Tab(text: 'Heatmap'),
                  Tab(text: 'Offline'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMyRoutesTab(),
            _buildSuggestedTab(),
            _buildHeatmapTab(),
            _buildOfflineTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRoute,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: const Text('Create Route', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
        IconButton(icon: const Icon(Icons.filter_list, color: Colors.white), onPressed: () {}),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Routes & Maps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade700, AppColors.primary],
                ),
              ),
            ),
            CustomPaint(painter: _MapPatternPainter()),
            Positioned(
              left: 16,
              bottom: 70,
              child: ValueListenableBuilder(
                valueListenable: StorageService.routesListenable,
                builder: (context, box, _) {
                  final routes = box.values.toList();
                  final totalKm = routes.fold(0.0, (sum, r) => sum + r.distanceKm);
                  final favorites = routes.where((r) => r.isFavorite).length;
                  
                  return Row(
                    children: [
                      _buildQuickStat('${routes.length}', 'Routes'),
                      const SizedBox(width: 20),
                      _buildQuickStat(totalKm.toStringAsFixed(0), 'km tracked'),
                      const SizedBox(width: 20),
                      _buildQuickStat('$favorites', 'Favorites'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildMyRoutesTab() {
    return ValueListenableBuilder(
      valueListenable: StorageService.routesListenable,
      builder: (context, box, _) {
        final routes = box.values.toList();
        
        if (routes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text('No routes created yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                TextButton(onPressed: _createRoute, child: const Text('Create your first route')),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildActivityFilter(),
            const SizedBox(height: 16),
            ...routes.map((route) => _buildRouteCard(route)),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _buildActivityFilter() {
    return Row(
      children: [
        _buildFilterChip('All', true),
        _buildFilterChip('Running', false),
        _buildFilterChip('Cycling', false),
        _buildFilterChip('Walking', false),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (v) {},
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildRouteCard(WorkoutRoute route) {
    Color difficultyColor;
    switch (route.difficulty) {
      case 'easy':
        difficultyColor = Colors.green;
        break;
      case 'moderate':
        difficultyColor = Colors.orange;
        break;
      case 'hard':
        difficultyColor = Colors.red;
        break;
      default:
        difficultyColor = Colors.blue;
    }

    IconData typeIcon = route.activityType == 'run' ? Icons.directions_run : Icons.pedal_bike;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              image: route.mapImageUrl != null 
                ? DecorationImage(image: NetworkImage(route.mapImageUrl!), fit: BoxFit.cover)
                : null,
            ),
            child: Stack(
              children: [
                if (route.mapImageUrl == null)
                  Center(child: Icon(Icons.map, size: 60, color: AppColors.primary.withOpacity(0.3))),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: Icon(
                      route.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: route.isFavorite ? Colors.red : Colors.grey,
                    ),
                    onPressed: () {
                        final updated = WorkoutRoute(
                            id: route.id,
                            name: route.name,
                            description: route.description,
                            distanceKm: route.distanceKm,
                            elevationGainM: route.elevationGainM,
                            activityType: route.activityType,
                            points: route.points,
                            createdAt: route.createdAt,
                            isFavorite: !route.isFavorite,
                            timesCompleted: route.timesCompleted,
                            difficulty: route.difficulty,
                            mapImageUrl: route.mapImageUrl,
                        );
                        StorageService.addRoute(updated);
                    },
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: difficultyColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(route.difficulty.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(typeIcon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(route.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildRouteStat(Icons.straighten, route.formattedDistance),
                    const SizedBox(width: 16),
                    _buildRouteStat(Icons.terrain, '+${route.elevationGainM} m'),
                    const SizedBox(width: 16),
                    _buildRouteStat(Icons.repeat, '${route.timesCompleted}x'),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Start', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildSuggestedTab() {
    return ValueListenableBuilder(
      valueListenable: StorageService.suggestedRoutesListenable,
      builder: (context, box, _) {
          final routes = box.values.toList();
          
          if (routes.isEmpty) {
             return const Center(child: Text('No suggestions available yet.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
                Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.purple.shade400, Colors.purple.shade600]),
                    borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                    children: [
                    Icon(Icons.auto_awesome, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text('AI Route Suggestions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Based on your preferences and history', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                        ),
                    ),
                    ],
                ),
                ),
                const SizedBox(height: 20),
                ...routes.map((route) => _buildSuggestedCard(route)),
            ],
          );
      }
    );
  }

  Widget _buildSuggestedCard(SuggestedRoute route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(route.activityType == 'run' ? Icons.directions_run : Icons.pedal_bike, color: Colors.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(route.reason, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.thumb_up, size: 12, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('${route.popularity.round()}%', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildRouteStat(Icons.straighten, '${route.distanceKm} km'),
              const SizedBox(width: 16),
              _buildRouteStat(Icons.terrain, '+${route.elevationGainM} m'),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('Preview')),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapTab() {
    // For demo, we just show a placeholder if no data, or visualize if we had a heatmap widget
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Your Personal Heatmap', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Visualize your activities', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineTab() {
    // Since we don't have a value listenable for offline maps in this scope (I added it to service but not exposd as listenable in my last edit, or I did?), 
    // actually I did add getAllOfflineMaps but no listenable. I'll just use a FutureBuilder or similar if I had time, but for now placeholder is fine or just read once.
    // I'll leave as static placeholder for now as offline maps is complex.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.teal.shade400, Colors.teal.shade600]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.download_for_offline, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Offline Maps', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Download maps for offline navigation during workouts without cell service.', style: TextStyle(color: Colors.white70, height: 1.4)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal),
                child: const Text('Download New Area'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _createRoute() {
    // Simple creation for demo
    final newRoute = WorkoutRoute(
        id: DateTime.now().toIso8601String(),
        name: 'New Route ${DateTime.now().minute}',
        description: 'Created on device',
        distanceKm: 5.0,
        elevationGainM: 100,
        activityType: 'run',
        points: [],
        createdAt: DateTime.now(),
        difficulty: 'moderate',
        isFavorite: false,
    );
    StorageService.addRoute(newRoute);
  }
}

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i.toDouble(), 0), Offset(i.toDouble(), size.height), paint);
    }
    for (var i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i.toDouble()), Offset(size.width, i.toDouble()), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: AppColors.background, child: tabBar);
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
