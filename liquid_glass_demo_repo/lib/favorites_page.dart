import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_demo/circles.dart';
import 'package:liquid_glass_demo/home_data.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'dart:math' as math;
import 'dart:ui';

/// The favorites page widget displaying favorited property listings
///
/// This StatefulWidget manages the favorites interface with the same
/// UI structure as the dashboard page, showing only favorited properties.
class FavoritesPage extends StatefulWidget {
  /// List of favorited home IDs
  final Set<int> favoriteIds;

  /// Callback when a favorite is toggled
  final Function(int) onFavoriteToggle;

  const FavoritesPage({
    super.key,
    required this.favoriteIds,
    required this.onFavoriteToggle,
  });

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

/// State management for the favorites page
class _FavoritesPageState extends State<FavoritesPage> {
  /// Controller for the search input field
  final TextEditingController _searchController = TextEditingController();

  /// Focus node for managing search field focus
  final FocusNode _searchFocusNode = FocusNode();

  /// Controller for tracking ListView scroll position
  final ScrollController _scrollController = ScrollController();

  /// Current spacing between navigation tabs (animated based on scroll)
  double _tabSpacing = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Handles scroll events to animate navigation tab spacing
  void _onScroll() {
    final offset = _scrollController.offset;

    // Expand tabs when scrolled beyond 100px threshold
    if (offset > 100) {
      setState(() {
        _tabSpacing = 150;
      });
    } else {
      setState(() {
        _tabSpacing = 0;
      });
    }
  }

  /// Get list of favorite homes
  List<HomeData> get favoriteHomes {
    return sampleHomes
        .asMap()
        .entries
        .where((entry) => widget.favoriteIds.contains(entry.key))
        .map((entry) => entry.value)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.dark,
    ));

    final favorites = favoriteHomes;

    return Scaffold(
      backgroundColor: const Color(0xFF032343),
      body: GestureDetector(
        onTap: () {
          _searchFocusNode.unfocus();
        },
        child: Stack(
          children: [
            const CirclesBackground(),
            if (favorites.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      color: Colors.white60,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No favorites yet',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the heart icon on properties to add them here',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                controller: _scrollController,
                itemCount: favorites.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                padding: const EdgeInsets.only(
                  top: 200,
                  left: 16,
                  right: 16,
                  bottom: 150,
                ),
                itemBuilder: (context, index) {
                  final home = favorites[index];
                  final originalIndex = sampleHomes.indexOf(home);

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: Image(
                            image: AssetImage(home.image),
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(36),
                            bottomRight: Radius.circular(36),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              color: Colors.black.withOpacity(0.3),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          home.name,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => widget
                                              .onFavoriteToggle(originalIndex),
                                          child: Icon(
                                            Icons.favorite_rounded,
                                            color: Colors.red,
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          color: Colors.white60,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          home.location,
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.bed_outlined,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${home.numberOfRooms} Rooms',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.bathroom_outlined,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${home.numberOfBathrooms} Baths',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Spacer(),
                                        Text(
                                          '\$ ${home.pricePerNight.toStringAsFixed(2)}/night',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 240,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF032343).withOpacity(0),
                      Color(0xFF032343),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        LiquidGlass(
                          settings: LiquidGlassSettings(
                            blur: 3,
                            ambientStrength: 0.5,
                            lightAngle: 0.2 * math.pi,
                            glassColor: Colors.white12,
                          ),
                          shape: LiquidRoundedSuperellipse(
                            borderRadius: const Radius.circular(40),
                          ),
                          glassContainsChild: false,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/alex-suprun.jpg',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'James Doe',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.white60,
                                  size: 16,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'New York, NY',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                        const Spacer(),
                        LiquidGlass(
                          settings: LiquidGlassSettings(
                            blur: 3,
                            ambientStrength: 0.5,
                            lightAngle: -0.2 * math.pi,
                            glassColor: Colors.white12,
                          ),
                          shape: LiquidRoundedSuperellipse(
                            borderRadius: const Radius.circular(40),
                          ),
                          glassContainsChild: false,
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: LiquidGlass(
                              settings: LiquidGlassSettings(
                                blur: 4,
                                ambientStrength: 2,
                                lightAngle: 0.4 * math.pi,
                                glassColor: Colors.black12,
                                thickness: 30,
                              ),
                              shape: LiquidRoundedSuperellipse(
                                borderRadius: const Radius.circular(40),
                              ),
                              glassContainsChild: false,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search favorites...',
                                    hintStyle: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 15,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Colors.white60,
                                      size: 22,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      child: LiquidGlassLayer(
                        settings: LiquidGlassSettings(
                          blur: 3,
                          ambientStrength: 0.5,
                          lightAngle: 0.2 * math.pi,
                          glassColor: Colors.white12,
                        ),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LiquidGlass.inLayer(
                                shape: LiquidRoundedSuperellipse(
                                  borderRadius: const Radius.circular(40),
                                ),
                                glassContainsChild: false,
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Hero(
                                          tag: 'home_button',
                                          child: Material(
                                            type: MaterialType.transparency,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.home_outlined,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                  Text(
                                                    'Home',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Hero(
                                        tag: 'favorites_button',
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: LiquidGlass(
                                            settings: LiquidGlassSettings(
                                              blur: 8,
                                              ambientStrength: 0.5,
                                              lightAngle: 0.2 * math.pi,
                                              glassColor: Colors.black26,
                                              thickness: 10,
                                            ),
                                            shape: LiquidRoundedSuperellipse(
                                              borderRadius:
                                                  const Radius.circular(40),
                                            ),
                                            glassContainsChild: false,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Icon(
                                                Icons.favorite_rounded,
                                                color: Colors.red,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                alignment: Alignment.center,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                child: SizedBox(
                                  width: _tabSpacing,
                                  height: 0,
                                ),
                              ),
                              Hero(
                                tag: 'profile_button',
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: LiquidGlass.inLayer(
                                    shape: LiquidRoundedSuperellipse(
                                      borderRadius: const Radius.circular(40),
                                    ),
                                    glassContainsChild: false,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Icon(
                                        Icons.person_outline,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
