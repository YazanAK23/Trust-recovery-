import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:trust_app_updated/Components/app_bar_widget/app_bar_widget.dart';
import 'package:trust_app_updated/Pages/offers/offer_full_screen/offer_full_screen.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';
import '../../Components/loading_widget/loading_widget.dart';
import '../../Constants/constants.dart';
import '../../Server/domains/domains.dart';
import '../../Server/functions/functions.dart';

class Offers extends StatefulWidget {
  Offers({super.key});

  @override
  State<Offers> createState() => _OffersState();
}

class _OffersState extends State<Offers> {
  List<dynamic> AllProducts = [];
  ScrollController _controller = ScrollController();
  bool _hasNextPage = true;
  bool _isFirstLoadRunning = false;
  bool _isLoadMoreRunning = false;
  final int _limit = 20;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _firstLoad();
    _controller.addListener(_loadMore);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _firstLoad() async {
    setState(() => _isFirstLoadRunning = true);
    try {
      var _products = await getOffers(_page);
      setState(() => AllProducts = _products);
      print(URLIMAGE + AllProducts[0]["image"]);
    } catch (err) {
      Fluttertoast.showToast(msg: "Something went wrong!");
    }
    setState(() => _isFirstLoadRunning = false);
  }

  void _loadMore() async {
    if (_hasNextPage &&
        !_isFirstLoadRunning &&
        !_isLoadMoreRunning &&
        _controller.position.extentAfter < 300) {
      setState(() => _isLoadMoreRunning = true);
      _page++;
      try {
        var _products = await getOffers(_page);
        if (_products["items"].isNotEmpty) {
          setState(() => AllProducts.addAll(_products["items"]));
        } else {
          _hasNextPage = false;
        }
      } catch (err) {
        Fluttertoast.showToast(msg: "Something went wrong!");
      }
      setState(() => _isLoadMoreRunning = false);
    }
  }

  String _normalizedImage(dynamic raw) {
    if (raw == null) return '';
    var s = raw.toString().trim();
    if (s.startsWith('[') && s.endsWith(']')) {
      // Remove [ ] and quotes, and if multiple, take the first
      s = s.substring(1, s.length - 1).replaceAll('"', '');
      if (s.contains(',')) s = s.split(',').first.trim();
    }
    return s;
  }

  Widget offerWidget(
      {required String name, required String image, required String desc}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      OfferFullScreen(name: name, image: image, desc: desc)));
        },
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Image with gradient overlay
                Positioned.fill(
                  child: (image.isNotEmpty)
                      ? Image.network(
                          URLIMAGE + image,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[300],
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: MAIN_COLOR,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: Image.asset(
                                  "assets/images/logo_red.png",
                                  fit: BoxFit.contain,
                                  height: 80,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Image.asset(
                              "assets/images/logo_red.png",
                              fit: BoxFit.contain,
                              height: 80,
                            ),
                          ),
                        ),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // Content
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name ?? 'No Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 20,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                desc ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: MAIN_COLOR,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: MAIN_COLOR.withOpacity(0.4),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _controller,
        slivers: [
          SliverAppBar(
            backgroundColor: MAIN_COLOR,
            elevation: 4,
            shadowColor: MAIN_COLOR.withOpacity(0.3),
            pinned: true,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MAIN_COLOR,
                      MAIN_COLOR.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
              centerTitle: true,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.local_offer_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.offer,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // **Banner Section**
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                width: double.infinity,
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _isFirstLoadRunning
                      ? Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: CircularProgressIndicator(color: MAIN_COLOR),
                          ),
                        )
                      : AllProducts.isEmpty
                          ? Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: Image.asset(
                                  "assets/images/new_logo.png",
                                  height: 100,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                          : Builder(
                              builder: (_) {
                                final first = AllProducts.first;
                                final bannerImage = _normalizedImage(first["image"]);
                                return Stack(
                                  children: [
                                    bannerImage.isNotEmpty
                                        ? Image.network(
                                            URLIMAGE + bannerImage,
                                            height: 240,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Container(
                                                color: Colors.grey[300],
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    color: MAIN_COLOR,
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded /
                                                            loadingProgress.expectedTotalBytes!
                                                        : null,
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[200],
                                                child: Center(
                                                  child: Image.asset(
                                                    "assets/images/new_logo.png",
                                                    height: 100,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        : Container(
                                            color: Colors.grey[200],
                                            child: Center(
                                              child: Image.asset(
                                                "assets/images/new_logo.png",
                                                height: 100,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                    // Subtle gradient overlay
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.3),
                                            ],
                                            stops: [0.6, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                ),
              ),
            ),
          ),

          // **Title Section**
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: MAIN_COLOR,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.available_offers,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Spacer(),
                  if (!_isFirstLoadRunning && AllProducts.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: MAIN_COLOR.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${AllProducts.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: MAIN_COLOR,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // **Product List**
          _isFirstLoadRunning
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Center(
                      child: CircularProgressIndicator(color: MAIN_COLOR),
                    ),
                  ),
                )
              : AllProducts.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_offer_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.there_is_no_offers,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      var imageString = AllProducts[index]["image"] ?? "";

                      if (imageString.startsWith("[") &&
                          imageString.endsWith("]")) {
                        imageString = imageString
                            .substring(1, imageString.length - 1)
                            .replaceAll('"', '');
                      }
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: Duration(milliseconds: 500),
                        child: SlideAnimation(
                          horizontalOffset: 100.0,
                          child: FadeInAnimation(
                            curve: Curves.easeOut,
                            child: offerWidget(
                              image: imageString,
                              desc: AllProducts[index]["description"] ?? "",
                              name: AllProducts[index]["name"] ?? "",
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: AllProducts.length,
                  ),
                ),

          // **Loading Indicator**
          if (_isLoadMoreRunning)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 10, bottom: 40),
                child:
                    Center(child: CircularProgressIndicator(color: MAIN_COLOR)),
              ),
            ),
        ],
      ),
    );
  }
}
