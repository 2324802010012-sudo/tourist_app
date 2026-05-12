import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/location_model.dart';
import '../services/location_discovery_service.dart';
import '../services/location_service.dart';
import '../services/travel_preference_service.dart';
import 'auth/login_screen.dart';
import 'detail_screen.dart';
import 'favorite_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';

const _vietnamGreen = Color(0xFF1F8A56);
const _lotusRed = Color(0xFFE84A5F);
const _riverBlue = Color(0xFF227C9D);
const _paper = Color(0xFFF7F4EA);
const _surface = Colors.white;
const _ink = Color(0xFF17221B);
const _mutedBorder = Color(0xFFE2E9DC);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final searchController = TextEditingController();
  List<Location> locations = [];
  Set<String> selectedPreferences = {};
  bool isLoading = true;
  bool preferenceOnly = false;
  String selectedProvince = LocationDiscoveryService.allProvincesLabel;
  String? quickPreference;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final loadedLocations = await LocationService.loadLocations();
    final preferences = await TravelPreferenceService.load();

    if (!mounted) return;
    setState(() {
      locations = loadedLocations;
      selectedPreferences = preferences.toSet();
      isLoading = false;
    });
  }

  Future<void> _reloadPreferences() async {
    final preferences = await TravelPreferenceService.load();
    if (!mounted) return;
    setState(() => selectedPreferences = preferences.toSet());
  }

  Set<String> get _activePreferences {
    final quick = quickPreference;
    return {
      ...selectedPreferences,
      ...?(quick == null ? null : [quick]),
    };
  }

  List<Location> get _visibleLocations {
    return LocationDiscoveryService.searchLocations(
      locations,
      query: searchController.text,
      preferences: _activePreferences,
      province: selectedProvince,
      preferenceOnly: preferenceOnly || quickPreference != null,
    );
  }

  List<Location> get _recommendedLocations {
    return LocationDiscoveryService.recommendedLocations(
      locations,
      selectedPreferences,
      limit: 6,
    );
  }

  bool get _isDiscovering {
    return searchController.text.trim().isNotEmpty ||
        selectedProvince != LocationDiscoveryService.allProvincesLabel ||
        preferenceOnly ||
        quickPreference != null;
  }

  void _search(String value) {
    setState(() {});
  }

  void _openLocation(Location location) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(data: location)),
    );
  }

  Future<void> _openProfile() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showLoginDialog();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    await _reloadPreferences();
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cần đăng nhập"),
        content: const Text("Bạn cần đăng nhập để dùng chức năng này."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Để sau"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text("Đăng nhập"),
          ),
        ],
      ),
    );
  }

  void _handleAction(_HomeAction action) {
    switch (action) {
      case _HomeAction.favorite:
        if (FirebaseAuth.instance.currentUser == null) {
          _showLoginDialog();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FavoriteScreen()),
        );
      case _HomeAction.history:
        if (FirebaseAuth.instance.currentUser == null) {
          _showLoginDialog();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        );
      case _HomeAction.scan:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        );
      case _HomeAction.profile:
        _openProfile();
    }
  }

  void _resetDiscovery() {
    searchController.clear();
    setState(() {
      preferenceOnly = false;
      quickPreference = null;
      selectedProvince = LocationDiscoveryService.allProvincesLabel;
    });
  }

  void _selectQuickPreference(String? preference) {
    setState(() {
      quickPreference = preference;
      preferenceOnly = preference != null;
    });
  }

  Future<void> _openFilterSheet() async {
    var draftProvince = selectedProvince;
    var draftPreferenceOnly = preferenceOnly;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final provinces = LocationDiscoveryService.provinces(locations);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Bộ lọc khám phá",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      value: draftPreferenceOnly,
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Ưu tiên gu du lịch"),
                      secondary: const Icon(Icons.auto_awesome),
                      onChanged: (value) {
                        setSheetState(() => draftPreferenceOnly = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Tỉnh / thành",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: provinces.map((province) {
                        final selected = draftProvince == province;
                        return ChoiceChip(
                          label: Text(province),
                          selected: selected,
                          selectedColor: _vietnamGreen,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) {
                            setSheetState(() => draftProvince = province);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _resetDiscovery();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text("Đặt lại"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                selectedProvince = draftProvince;
                                preferenceOnly = draftPreferenceOnly;
                              });
                              Navigator.pop(sheetContext);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text("Áp dụng"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 620;
                    final horizontalPadding = isWide ? 24.0 : 16.0;
                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        14,
                        horizontalPadding,
                        28,
                      ),
                      children: [
                        _homeHeader(),
                        const SizedBox(height: 14),
                        _heroBanner(),
                        const SizedBox(height: 14),
                        _searchBar(),
                        const SizedBox(height: 12),
                        _quickActions(),
                        const SizedBox(height: 14),
                        _quickPreferenceChips(),
                        const SizedBox(height: 20),
                        if (_isDiscovering)
                          _discoveryResults(isWide)
                        else ...[
                          _personalizedSection(isWide),
                          const SizedBox(height: 20),
                          _featuredSection(isWide),
                          const SizedBox(height: 20),
                          _videoSection(),
                        ],
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _homeHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final greetingName = displayName == null || displayName.isEmpty
        ? "Việt Nam"
        : displayName;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Xin chào,",
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              Text(
                greetingName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: "Hồ sơ",
          onPressed: _openProfile,
          icon: const Icon(Icons.person),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: searchController,
      onChanged: _search,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: "Tìm địa điểm, tỉnh thành, trải nghiệm...",
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (searchController.text.isNotEmpty)
              IconButton(
                tooltip: "Xóa tìm kiếm",
                onPressed: () {
                  searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
            IconButton(
              tooltip: "Bộ lọc",
              onPressed: _openFilterSheet,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _quickPreferenceChips() {
    final chips = [null, ...TravelPreferenceService.options];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preference = chips[index];
          final selected = quickPreference == preference;
          final label = preference ?? "Tất cả";
          return ChoiceChip(
            label: Text(label),
            avatar: Icon(
              preference == null ? Icons.apps : _preferenceIcon(preference),
              size: 17,
              color: selected ? Colors.white : _vietnamGreen,
            ),
            selected: selected,
            selectedColor: _vietnamGreen,
            backgroundColor: _surface,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
            onSelected: (_) => _selectQuickPreference(preference),
          );
        },
      ),
    );
  }

  Widget _quickActions() {
    const actions = [
      _ActionItem(_HomeAction.favorite, Icons.favorite_border, "Yêu thích"),
      _ActionItem(_HomeAction.history, Icons.history, "Lịch sử"),
      _ActionItem(_HomeAction.scan, Icons.qr_code_scanner, "Quét AI"),
      _ActionItem(_HomeAction.profile, Icons.person_outline, "Hồ sơ"),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 390 ? 2 : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 76,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _handleAction(action.action),
              child: Ink(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _mutedBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _vietnamGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(action.icon, color: _vietnamGreen, size: 19),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _heroBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/banner.png', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    _riverBlue.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.66),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personalizedSection(bool isWide) {
    final recommendations = _recommendedLocations;
    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          "Dành cho bạn",
          Icons.auto_awesome,
          actionText: "Sửa gu",
          onAction: _openProfile,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 246,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _recommendationCard(recommendations[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _featuredSection(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          "Địa điểm nổi bật",
          Icons.place,
          actionText: "Tất cả",
          onAction: _resetDiscovery,
        ),
        const SizedBox(height: 10),
        _destinationGrid(locations.take(isWide ? 6 : 4).toList(), isWide),
      ],
    );
  }

  Widget _videoSection() {
    final videoLocations = locations
        .where((location) => location.videoUrl.isNotEmpty)
        .toList();
    if (videoLocations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Video giới thiệu", Icons.play_circle, onAction: null),
        const SizedBox(height: 10),
        SizedBox(
          height: 206,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: videoLocations.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final location = videoLocations[index];
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoScreen(
                        videoPath: 'assets/${location.videoUrl}',
                        title: location.name,
                      ),
                    ),
                  );
                },
                child: Ink(
                  width: 196,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _mutedBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              location.thumbnail,
                              height: 118,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              location.province,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _discoveryResults(bool isWide) {
    final results = _visibleLocations;
    final title = searchController.text.trim().isEmpty
        ? "Kết quả khám phá"
        : "Tìm thấy ${results.length} địa điểm";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _activeFilterBar(),
        const SizedBox(height: 14),
        _sectionHeader(
          title,
          Icons.travel_explore,
          actionText: "Đặt lại",
          onAction: _resetDiscovery,
        ),
        const SizedBox(height: 10),
        if (results.isEmpty)
          _emptySearchState()
        else
          _destinationGrid(results, isWide),
      ],
    );
  }

  Widget _activeFilterBar() {
    final filters = <Widget>[];
    if (selectedProvince != LocationDiscoveryService.allProvincesLabel) {
      filters.add(_filterPill(Icons.location_city, selectedProvince));
    }
    if (preferenceOnly && selectedPreferences.isNotEmpty) {
      filters.add(_filterPill(Icons.auto_awesome, "Gu cá nhân"));
    }
    if (quickPreference != null) {
      filters.add(
        _filterPill(_preferenceIcon(quickPreference!), quickPreference!),
      );
    }

    if (filters.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: filters);
  }

  Widget _filterPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8E5D6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _vietnamGreen),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _emptySearchState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off, size: 42, color: Colors.black38),
          SizedBox(height: 10),
          Text(
            "Không tìm thấy địa điểm phù hợp",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _destinationGrid(
    List<Location> items,
    bool isWide, {
    bool compact = false,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = isWide ? 48 : 32;
    final availableWidth = screenWidth - horizontalPadding;
    final crossAxisCount = availableWidth < 360 ? 1 : (isWide ? 3 : 2);
    final isSingleColumn = crossAxisCount == 1;
    final mainAxisExtent = isSingleColumn
        ? 172.0
        : compact
        ? 258.0
        : 286.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: mainAxisExtent,
      ),
      itemBuilder: (context, index) =>
          _destinationCard(items[index], compact, horizontal: isSingleColumn),
    );
  }

  Widget _recommendationCard(Location location) {
    final reasons = LocationDiscoveryService.matchReasons(
      location,
      _activePreferences,
      limit: 1,
    );

    return SizedBox(
      width: 218,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openLocation(location),
        child: Ink(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _mutedBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: Image.asset(
                  location.thumbnail,
                  height: 122,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _locationLine(location.province),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          location.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (reasons.isNotEmpty) _miniTag(reasons.first),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _destinationCard(
    Location location,
    bool compact, {
    required bool horizontal,
  }) {
    final reasons = LocationDiscoveryService.matchReasons(
      location,
      _activePreferences,
      limit: 1,
    );

    if (horizontal) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openLocation(location),
        child: Ink(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _mutedBorder),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
                child: Image.asset(
                  location.thumbnail,
                  width: 132,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _locationLine(location.province),
                      const SizedBox(height: 7),
                      Expanded(
                        child: Text(
                          location.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (reasons.isNotEmpty) _miniTag(reasons.first),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openLocation(location),
      child: Ink(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _mutedBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: Image.asset(
                location.thumbnail,
                height: compact ? 116 : 132,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _locationLine(location.province),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        location.description,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (reasons.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _miniTag(reasons.first),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationLine(String province) {
    return Row(
      children: [
        const Icon(Icons.location_on, size: 15, color: _lotusRed),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            province,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _miniTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _vietnamGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _vietnamGreen,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _sectionHeader(
    String title,
    IconData icon, {
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Icon(icon, size: 19, color: _vietnamGreen),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        if (actionText != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionText)),
      ],
    );
  }

  IconData _preferenceIcon(String preference) {
    return switch (preference) {
      "Di sản lịch sử" => Icons.account_balance,
      "Thiên nhiên" => Icons.landscape,
      "Check-in" => Icons.photo_camera,
      "Ẩm thực" => Icons.restaurant,
      "Gia đình" => Icons.family_restroom,
      "Trải nghiệm tiết kiệm" => Icons.savings,
      _ => Icons.explore,
    };
  }
}

enum _HomeAction { favorite, history, scan, profile }

class _ActionItem {
  final _HomeAction action;
  final IconData icon;
  final String label;

  const _ActionItem(this.action, this.icon, this.label);
}

class VideoScreen extends StatefulWidget {
  final String videoPath;
  final String title;

  const VideoScreen({super.key, required this.videoPath, required this.title});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(widget.videoPath);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.setLooping(true);
      _controller.play();
      _controller.pause();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: _controller.value.isInitialized
            ? GestureDetector(
                onTap: togglePlay,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    if (!_controller.value.isPlaying)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
