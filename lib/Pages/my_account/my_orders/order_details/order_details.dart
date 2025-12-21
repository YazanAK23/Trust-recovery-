import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trust_app_updated/Server/domains/domains.dart';

import 'package:trust_app_updated/Server/functions/functions.dart';
import 'package:trust_app_updated/main.dart';

import '../../../../Components/bottom_bar_widget/bottom_bar_widget.dart';
import '../../../../Components/loading_widget/loading_widget.dart';
import '../../../../Constants/constants.dart';
import '../../../cart/cart.dart';

class OrderDetails extends StatefulWidget {
  int orderID;
  final status;
  OrderDetails({
    Key? key,
    required this.orderID,
    required this.status,
  }) : super(key: key);

  @override
  State<OrderDetails> createState() => _OrderDetailsState();
}

int _currentIndex = 0;

class _OrderDetailsState extends State<OrderDetails> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: MAIN_COLOR,
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
              backgroundColor: MAIN_COLOR,
              centerTitle: true,
              title: Text(
                "#${widget.orderID} | ${widget.status}",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white)),
                    child: Center(
                      child: IconButton(
                          padding: EdgeInsets.all(0),
                          onPressed: () {},
                          icon: Icon(
                            Icons.search_outlined,
                            color: Colors.white,
                            size: 15,
                          )),
                    ),
                  ),
                ),
                SizedBox(
                  width: 20,
                ),
                InkWell(
                  onTap: () {
                    NavigatorPushFunction(context, Cart());
                  },
                  child: FaIcon(
                    FontAwesomeIcons.cartShopping,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                SizedBox(
                  width: 10,
                ),
              ],
              leading: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ))),
          body: Container(
            height: MediaQuery.of(context).size.height,
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/BackGround.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                _isFirstLoadRunning
                    ? LoadingWidget(
                        heightLoading: MediaQuery.of(context).size.height * 0.4,
                      )
                    : AllProducts.length == 0
                        ? Padding(
                            padding: const EdgeInsets.only(top: 50),
                            child: Text(
                              "لا يوجد أي 'طلبية",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Container(
                                width: double.infinity,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 80),
                                  child: ListView.builder(
                                      itemCount: AllProducts.length,
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        // Check if product data is null (deleted product)
                                        bool isProductDeleted = AllProducts[index] == null ||
                                            AllProducts[index]?["product"] == null;
                                        
                                        String imageString = "";
                                        String productName = "";
                                        
                                        if (isProductDeleted) {
                                          // Product has been deleted
                                          productName = locale.toString() == "ar"
                                              ? "المنتج لم يعد متوفراً"
                                              : "Product No Longer Available";
                                        } else {
                                          // Product exists, get image
                                          var tempImage = AllProducts[index]
                                              ?["product"]?["image"];
                                          if (tempImage != null &&
                                              tempImage.toString().startsWith("[") &&
                                              tempImage.toString().endsWith("]")) {
                                            // Remove square brackets and any surrounding double quotes
                                            imageString = tempImage
                                                .toString()
                                                .substring(
                                                    1, tempImage.toString().length - 1)
                                                .replaceAll('"', '');
                                          } else {
                                            imageString = tempImage?.toString() ?? "";
                                          }
                                          
                                          // Get product name
                                          if (locale.toString() == "ar") {
                                            var translations = AllProducts[index]?["product"]
                                                ?["translations"];
                                            if (translations != null &&
                                                translations is List &&
                                                translations.isNotEmpty &&
                                                translations[0] != null) {
                                              productName = translations[0]?["value"]?.toString() ?? "";
                                            }
                                          } else {
                                            productName = AllProducts[index]?["product"]
                                                    ?["name"]?.toString() ??
                                                "";
                                          }
                                        }
                                        
                                        return OrderCard(
                                          name: productName,
                                          image: imageString,
                                          qty: AllProducts[index]?["quantity"] ?? 0,
                                          isDeleted: isProductDeleted,
                                        );
                                      }),
                                )),
                          ),
                // when the _loadMore function is running
                if (_isLoadMoreRunning == true)
                  Padding(
                    padding: EdgeInsets.only(top: 10, bottom: 40),
                    child: Center(
                        child: LoadingWidget(
                      heightLoading: 40,
                    )),
                  ),

                // When nothing else to load
                if (_hasNextPage == false)
                  Container(
                    padding: const EdgeInsets.only(top: 30, bottom: 40),
                    color: MAIN_COLOR,
                    child: const Center(
                      child: Text('You have fetched all of the products'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget OrderCard({int qty = 0, String name = "", String image = "", bool isDeleted = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, right: 25, left: 25),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 220,
                child: isDeleted
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.grey[400]!,
                              Colors.grey[600]!,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 80,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              SizedBox(height: 10),
                              Text(
                                locale.toString() == "ar"
                                    ? "المنتج محذوف"
                                    : "Deleted Product",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : image.isNotEmpty
                        ? Image.network(
                            URLIMAGE + image,
                            fit: BoxFit.cover,
                            height: 250,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: Center(
                                  child: Icon(Icons.broken_image,
                                      size: 50, color: Colors.grey),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: Center(
                              child: Icon(Icons.image_not_supported,
                                  size: 50, color: Colors.grey),
                            ),
                          ),
              ),
              Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color.fromARGB(183, 0, 0, 0),
                        Color.fromARGB(45, 0, 0, 0)
                      ],
                    ),
                  )),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  name,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.cartShopping,
                      size: 20,
                      color: Colors.white,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Text(
                      qty.toString(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  var AllProducts;
  // At the beginning, we fetch the first 20 posts
  int _page = 1;
  // you can change this value to fetch more or less posts per page (10, 15, 5, etc)
  final int _limit = 20;
  // There is next page or not
  bool _hasNextPage = true;
  // Used to display loading indicators when _firstLoad function is running
  bool _isFirstLoadRunning = false;
  // Used to display loading indicators when _loadMore function is running
  bool _isLoadMoreRunning = false;

  void _firstLoad() async {
    setState(() {
      _isFirstLoadRunning = true;
    });
    try {
      var _products = await getSpeceficOrder(widget.orderID);
      setState(() {
        AllProducts = _products;
      });
    } catch (err) {
      if (kDebugMode) {
        print('Something went wrong');
      }
    }

    setState(() {
      _isFirstLoadRunning = false;
    });
  }

  // This function will be triggered whenver the user scroll
  // to near the bottom of the list view
  void _loadMore() async {
    if (_hasNextPage == true &&
        _isFirstLoadRunning == false &&
        _isLoadMoreRunning == false &&
        _controller!.position.extentAfter < 300) {
      setState(() {
        _isLoadMoreRunning = true; // Display a progress indicator at the bottom
      });
      _page += 1; // Increase _page by 1
      try {
        var _products = await getSpeceficOrder(widget.orderID);
        if (_products.isNotEmpty) {
          setState(() {
            AllProducts.addAll(_products);
          });
        } else {
          // This means there is no more data
          // and therefore, we will not send another GET request
          setState(() {
            _hasNextPage = false;
          });
        }
      } catch (err) {
        if (kDebugMode) {
          print("error");
          print(err);
        }
      }

      setState(() {
        _isLoadMoreRunning = false;
      });
    }
  }

  // The controller for the ListView
  ScrollController? _controller;
  @override
  void initState() {
    super.initState();
    _firstLoad();
    _controller = ScrollController()..addListener(_loadMore);
  }

  @override
  void dispose() {
    _controller?.removeListener(_loadMore);
    super.dispose();
  }
}
