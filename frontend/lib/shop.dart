import 'package:flutter/material.dart';

import 'package:miru/widgets.dart';
import 'dart:convert';

import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

var toggleIndex = 0;

Color? c50 = Colors.lightGreen[50];

Color? c100 = Colors.lightGreen[100];

Color? c200 = Colors.lightGreen[200];

Color? c300 = Colors.lightGreen[300];

Color? c400 = Colors.lightGreen[400];

Color? c500 = Colors.lightGreen[500];

Color? c600 = Colors.lightGreen[600];

Color? c700 = Colors.lightGreen[700];

Color? c800 = Colors.lightGreen[800];

Color? c900 = Colors.lightGreen[900];

int balance = 0;

typedef PurchaseCallback = Future<void> Function({
  required int token,
  required String itemName,
});

Map<String, bool> purchasedItems = {
  "Ribbon": false,
  "Glasses": false,
  "Sunglasses": false,
  "Mustache": false,
  "Monocle": false,
  "Hat": false,
  "Cap": false,
  "Dirt": true,
  "Grass": false,
  "Sand": false,
  "Rose": false,
  "Daffodil": false,
  "Cornflower": false,
  "Lavender": false,
  "Carnation": false,
  "Chamomile": false,
  "Tree": false,
  "Apple": false,
  "Orange": false,
  "Pear": false,
  "Peach": false,
  "Pond": false,
  //REED!!
  "Reed": false,
  "Lilypad": false,
  "Koi": false,
  "Fountain": false,
  "Tools": false,
  "Wheelbarrow": false,
  "Mushrooms": false,
  "Birdbath": false,
};

class Shop extends StatefulWidget {

  const Shop({
    super.key,
  });

  @override
  State<Shop> createState() => _ShopState();
}

class _ShopState extends State<Shop> {
  bool _shopReady = false;
  bool _purchaseInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadShop();
    // _resetShopped();
  }

  Future<void> _loadShop() async {
    try {
      await Future.wait([
        _getTokenFromSharedPref(),
        _getShopBooleans(),
      ]);
      if (!mounted) return;
      setState(() => _shopReady = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load the shop. Please reopen it.')),
      );
    }
  }

  Future<void> _resetShopped() async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tokenValue', 1000);
  }

  Future<void> _getTokenFromSharedPref() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      final stored = prefs.get('tokenValue');
      balance = stored is int && stored >= 0 ? stored : 0;
    });
  }

  Future<void> _getShopBooleans() async {
    final prefs = await SharedPreferences.getInstance();

    final storedItems = prefs.get('purchasedItems');
    final defaultItems = <String, bool>{
      "Ribbon": false,
      "Glasses": false,
      "Sunglasses": false,
      "Mustache": false,
      "Monocle": false,
      "Hat": false,
      "Cap": false,
      //the only one that needs to be true!!
      "Dirt": true,
      "Grass": false,
      "Sand": false,
      "Rose": false,
      "Daffodil": false,
      "Cornflower": false,
      "Lavender": false,
      "Carnation": false,
      "Chamomile": false,
      "Tree": false,
      "Apple": false,
      "Orange": false,
      "Pear": false,
      "Peach": false,
      "Pond": false,
      //REED!!
      "Reed": false,
      "Lilypad": false,
      "Koi": false,
      "Fountain": false,
      "Tools": false,
      "Wheelbarrow": false,
      "Mushrooms": false,
      "Birdbath": false,
    };
  
    final resolvedItems = <String, bool>{...defaultItems};
    if (storedItems is String && storedItems.isNotEmpty) {
      try {
        final decoded = json.decode(storedItems);
        if (decoded is Map) {
          for (final name in defaultItems.keys) {
            final value = decoded[name];
            if (value is bool) resolvedItems[name] = value;
          }
        }
      } on FormatException {
        // Keep defaults
      }
    }
    resolvedItems['Dirt'] = true;

    if (!mounted) return;

    setState(() {
      purchasedItems = resolvedItems;
    });
  }

  Future<void> _purchaseItem({required int token, required String itemName}) async {
    if (!_shopReady || _purchaseInProgress || token <= 0 ||
        purchasedItems[itemName] != false) return;
    _purchaseInProgress = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final storedBalance = prefs.get('tokenValue');
      final currentBalance = storedBalance is int && storedBalance >= 0
          ? storedBalance : 0;
      if (currentBalance < token) {
        setState(() => balance = currentBalance);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have enough tokens.')),
        );
        return;
      }

      final nextItems = <String, bool>{...purchasedItems, itemName: true};
      final nextBalance = currentBalance - token;
      if (!await prefs.setInt('tokenValue', nextBalance)) {
        throw StateError('Could not save tokens.');
      }
      try {
        if (!await prefs.setString('purchasedItems', json.encode(nextItems))) {
          throw StateError('Could not save the purchase.');
        }
      } catch (_) {
        await prefs.setInt('tokenValue', currentBalance);
        rethrow;
      }
      if (!mounted) return;
      setState(() {
        balance = nextBalance;
        purchasedItems = nextItems;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the purchase. Please try again.')),
      );
    } finally {
      _purchaseInProgress = false;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$balance",
                          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          " Tokens",
                          style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton.filled(
                  icon: const Icon(CupertinoIcons.info, color: Colors.black),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        scrollable: true,
                        title: Text("Shop"),
                        content: Text('Purchase items for the sunflower and customize it in Home.\n\nExplore Apparel, Ground, Flowers, Trees, Pond, and Garden Objects.\n\nTokens are earned through scanning products to learn more about its company\'s ethicality scores.\n1 Token/Scan.\n\nThe total costs of everything in this shop is 122 Tokens.'),
                        actions: [
                          TextButton(
                            child: Text('OK'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                  },
                )
              ]
            ),
            SizedBox(height: 20, width: 10),
            Expanded(
              child: AbsorbPointer(
                absorbing: !_shopReady,
                child: ToggleShop(
                  onPurchase: _purchaseItem,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ToggleShop extends StatefulWidget {
  final PurchaseCallback onPurchase;

  const ToggleShop({
    super.key,
    required this.onPurchase,
  });

  @override
  State<ToggleShop> createState() => _ToggleShopState();
}

class _ToggleShopState extends State<ToggleShop>
    with TickerProviderStateMixin {
  late PageController _pageViewController;
  late TabController _tabController;
  int _currentPageIndex = 0;

  int value = 5;

  Widget iconBuilder(int value) {
    return Icon(
      value == 0 ? CupertinoIcons.cube_box :
      value == 1 ? CupertinoIcons.drop :
      value == 2 ? CupertinoIcons.tree :
      value == 3 ? CupertinoIcons.asterisk_circle_fill :
      value == 4 ? CupertinoIcons.layers_alt :
      CupertinoIcons.eyeglasses
    );
  }

  @override
  void initState() {
    super.initState();
    _pageViewController = PageController();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _pageViewController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handlePageViewChanged(int currentPageIndex) {
    // debugPrint("executed");
    _tabController.index = currentPageIndex;
    setState(() {
      _currentPageIndex = currentPageIndex;
      // debugPrint("set???");
    });
    updateToggle();
  }

  void updateToggle() {
    if (_currentPageIndex == 5) {
      toggleIndex = 0;
    } else if (_currentPageIndex == 4) {
      toggleIndex = 1;
    } else if (_currentPageIndex == 3) {
      toggleIndex = 2;
    } else if (_currentPageIndex == 2) {
      toggleIndex = 3;
    } else if (_currentPageIndex == 1) {
      toggleIndex = 4;
    } else if (_currentPageIndex == 0) {
      toggleIndex = 5;
    }
    setState(() {value = toggleIndex;});
  }

  void pageControl(int toPage) {
    _pageViewController.animateToPage(
      toPage,
      duration: const Duration(microseconds: 1),
      curve: Curves.linear,
    );
  }

  void updatePageView(int page) {
    if (page == 0) {
      pageControl(5);
    } else if (page == 1) {
      pageControl(4);
    } else if (page == 2) {
      pageControl(3);
    } else if (page == 3) {
      pageControl(2);
    } else if (page == 4) {
      pageControl(1);
    } else if (page == 5) {
      pageControl(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
         SizedBox(
          width: MediaQuery.of(context).size.width,
          height: 50,
          child: OverflowBox(
            maxWidth: MediaQuery.of(context).size.width,
            child: AnimatedToggleSwitch<int>.size(
              textDirection: TextDirection.rtl,
              current: value,
              values: const [0, 1, 2, 3, 4, 5],
              animationDuration: const Duration(microseconds: 1),
              iconOpacity: 0.2,
              indicatorSize: const Size.fromWidth(200),
              iconBuilder: iconBuilder,
              borderWidth: 4.0,
              iconAnimationType: AnimationType.onHover,
              style: ToggleStyle(
                backgroundColor: c100,
                borderColor: Colors.transparent,
                borderRadius: BorderRadius.circular(10.0),
                // borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  const BoxShadow(
                    color: Colors.transparent,
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
              styleBuilder: (i) =>
                  ToggleStyle(indicatorColor: c500),
              onChanged: (i) {
                updatePageView(i);
                setState(() => value = i);
              },
            ),
          ),
        ),
       Expanded(child: Stack(
          alignment: .bottomCenter,
          children: <Widget>[
            PageView(
              controller: _pageViewController,
              onPageChanged: _handlePageViewChanged,
              children: <Widget>[
                Center(
                  child: Apparel(onPurchase: widget.onPurchase)
                ),
                Center(child: Ground(onPurchase: widget.onPurchase)),
                Center(child: Flower(onPurchase: widget.onPurchase)),
                Center(child: Tree(onPurchase: widget.onPurchase)),
                Center(child: Pond(onPurchase: widget.onPurchase)),
                Center(child: Object(onPurchase: widget.onPurchase)),
              ],
            ),
          ],
        )),
      ],
    );
  }
  
}

class ShopItem extends StatelessWidget {
  final String itemName;
  final int cost;
  final String asset; 
  final bool purchased;
  final VoidCallback onPurchase;

  const ShopItem({
    super.key,             
    required this.itemName,
    required this.cost, 
    required this.asset,
    required this.purchased,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;

    return Material(
      color: c200,
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: InkWell(
        splashColor: Colors.lightGreen[200]?.withValues(alpha: 0.35),
        onTap: () {if (purchasedItems[itemName] == false) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(itemName),
              content: balance >= cost
                ? Text(
                  'Purchase for $cost tokens?'
                ) :
                Text(
                  'You do not have enough tokens.'
                ),
              actions: balance >= cost
                ? [
                    TextButton(
                      child: Text('NO'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: Text('YES'),
                      onPressed: () {
                        onPurchase();
                        Navigator.pop(context);
                      },
                    ),
                  ]
                : [
                    TextButton(
                      child: Text('OK'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
            ),
          );
          } else {
            null;
          }
        },
        child: SizedBox(
          width: screenWidth * 0.3,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ink.image(
              image: AssetImage(asset),
              width: screenWidth * 0.3,
              height: screenWidth * 0.3,
              fit: BoxFit.cover,
              child: purchasedItems[itemName] == true
                ? Purchased()
                : null
            ),
            SizedBox(height: 5, width: 5),
            Text(itemName, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0)),
            SizedBox(height: 2, width: 5),
            Text("$cost Tokens"),
            SizedBox(height: 8, width: 5),
          ]
          ),
        ),
      ),
    );
  }
}

class Purchased extends StatelessWidget {
  const Purchased({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [Icon(
        CupertinoIcons.check_mark_circled_solid,
        color: c800,
        size: 24.0,
      ),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text("Purchased", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      ]
    );
  }
}

class Locked extends StatelessWidget {
  const Locked({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        CupertinoIcons.lock,
        color: c900,
        size: 50.0,
      ),
    );
  }
}

class LockedShopItem extends StatelessWidget {
  final String itemName;
  final String needsPurchase;
  final int cost;
  final String asset; 
  final bool purchased;
  final VoidCallback onPurchase;

  const LockedShopItem({
    super.key,
    required this.itemName,
    required this.needsPurchase,
    required this.cost,
    required this.asset,
    required this.purchased,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    // final double screenHeight = MediaQuery.sizeOf(context).height;

    return Material(
      color: c200,
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: InkWell(
        splashColor: Colors.lightGreen[200]?.withValues(alpha: 0.35),
        onTap: () {if (purchasedItems[itemName] == false && purchasedItems[needsPurchase] == true) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(itemName),
              content: balance >= cost
                ? Text(
                  'Purchase for $cost tokens?'
                ) :
                Text(
                  'You do not have enough tokens.'
                ),
              actions: balance >= cost
                ? [
                    TextButton(
                      child: Text('NO'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: Text('YES'),
                      onPressed: () {
                        onPurchase();
                        Navigator.pop(context);
                      },
                    ),
                  ]
                : [
                    TextButton(
                      child: Text('OK'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
            ),
          );
          } else if (purchasedItems[itemName] == false && purchasedItems[needsPurchase] == false) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(itemName),
                content: Text('Please purchase $needsPurchase first.'),
                actions: [
                  TextButton(
                    child: Text('OK'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          }
        },
        child: SizedBox(
          width: screenWidth * 0.3,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ink.image(
              image: AssetImage(asset),
              width: screenWidth * 0.3,
              height: screenWidth * 0.3,
              fit: BoxFit.cover,
              child: purchasedItems[needsPurchase] == false
                ? Locked()
                : purchasedItems[itemName] == true
                ? Purchased()
                : null
            ),
            SizedBox(height: 5, width: 5),
            Text(itemName, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0)),
            SizedBox(height: 2, width: 5),
            Text("$cost Tokens"),
            SizedBox(height: 8, width: 5),
          ]
          ),
        ),
      ),
    );
  }
}

class Apparel extends StatelessWidget {
  final PurchaseCallback onPurchase;

  const Apparel({
    super.key,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double spacewidth = screenWidth * 0.01;

    return ListView(
      scrollDirection: Axis.vertical,
      children: <Widget>[
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(child: Text("Apparel", textAlign: TextAlign.center, style: TextStyle(fontSize: 22.5, fontWeight: FontWeight.bold))),
          ]
        ),
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShopItem(cost: 3, itemName: "Ribbon", asset: "assets/MIRU Catalog/ApparelRibbon.png", purchased: false, onPurchase: () {onPurchase(token: 3, itemName: "Ribbon");}),
            SizedBox(height: 8, width: spacewidth),
            ShopItem(cost: 3, itemName: "Glasses", asset: "assets/MIRU Catalog/ApparelGlass.png", purchased: false, onPurchase: () {onPurchase(token: 3, itemName: "Glasses");}),
            SizedBox(height: 8, width: spacewidth),
            ShopItem(cost: 3, itemName: "Sunglasses", asset: "assets/MIRU Catalog/ApparelSunglass.png", purchased: false, onPurchase: () {onPurchase(token: 3, itemName: "Sunglasses");}),
          ],
        ),
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShopItem(cost: 4, itemName: "Mustache", asset: "assets/MIRU Catalog/ApparelMustache.png", purchased: false, onPurchase: () {onPurchase(token: 4, itemName: "Mustache");}),
            SizedBox(height: 8, width: spacewidth),
            ShopItem(cost: 4, itemName: "Monocle", asset: "assets/MIRU Catalog/ApparelMonocle.png", purchased: false, onPurchase: () {onPurchase(token: 4, itemName: "Monocle");}),
            SizedBox(height: 8, width: spacewidth),
            ShopItem(cost: 5, itemName: "Hat", asset: "assets/MIRU Catalog/ApparelHat.png", purchased: false, onPurchase: () {onPurchase(token: 5, itemName: "Hat");}),
          ],
        ),
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShopItem(cost: 5, itemName: "Cap", asset: "assets/MIRU Catalog/ApparelCap.png", purchased: false, onPurchase: () {onPurchase(token: 5, itemName: "Cap");}),
            SizedBox(height: 8, width: spacewidth * 2 + screenWidth * 0.6),
          ],
        )
      ],
    );
  }
}

class Ground extends StatelessWidget {
  final PurchaseCallback onPurchase;

  const Ground({
    super.key,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double spacewidth = screenWidth * 0.01;

    return ListView(
      scrollDirection: Axis.vertical,
      children: <Widget>[
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(child: Text("Ground", textAlign: TextAlign.center, style: TextStyle(fontSize: 22.5, fontWeight: FontWeight.bold))),
          ]
        ),
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShopItem(cost: 5, itemName: "Sand", asset: "assets/MIRU Catalog/GroundSand.png", purchased: false, onPurchase: () {onPurchase(token: 5, itemName: "Sand");}),
            SizedBox(height: 8, width: spacewidth),
            ShopItem(cost: 5, itemName: "Grass", asset: "assets/MIRU Catalog/GroundGrass.png", purchased: false, onPurchase: () {onPurchase(token: 5, itemName: "Grass");}),
            SizedBox(height: 8, width: spacewidth + screenWidth * 0.3),
          ],
        ),
      ],
    );
  }
}

class Flower extends StatelessWidget {
  final PurchaseCallback onPurchase;

  const Flower({
    super.key,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double spacewidth = screenWidth * 0.01;

    return ListView(
      scrollDirection: Axis.vertical,
      children: <Widget>[
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(child: Text("Flower", textAlign: TextAlign.center, style: TextStyle(fontSize: 22.5, fontWeight: FontWeight.bold))),
          ]
        ),
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShopItem(cost: 4, itemName: "Rose", asset: "assets/MIRU Catalog/FlowerRose.png", purchased: false, onPurchase: () {onPurchase(token: 4, itemName: "Rose");}),
            SizedBox(height: 8, width: spacewidth),
            ShopItem(cost: 4, itemName: "Daffodil", asset: "assets/MIRU Catalog/FlowerDaffodil.png", purchased: false, onPurchase: () {onPurchase(token: 4, itemName: "Daffodil");}),
            SizedBox(height: 8, width: spacewidth),
            ShopItem(cost: 4, itemName: "Cornflower", asset: "assets/MIRU Catalog/FlowerCornflower.png", purchased: false, onPurchase: () {onPurchase(token: 4, itemName: "Cornflower");}),
          ],
        ),
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShopItem(cost: 4, itemName: "Lavender", asset: "assets/MIRU Catalog/FlowerLavender.png", purchased: false, onPurchase: () {onPurchase(token: 4, itemName: "Lavender");}),
            SizedBox(height: 8, width: spacewidth),
            ShopItem(cost: 4, itemName: "Carnation", asset: "assets/MIRU Catalog/FlowerPetunia.png", purchased: false, onPurchase: () {onPurchase(token: 4, itemName: "Carnation");}),
            SizedBox(height: 8, width: spacewidth),
            ShopItem(cost: 4, itemName: "Chamomile", asset: "assets/MIRU Catalog/FlowerChamomile.png", purchased: false, onPurchase: () {onPurchase(token: 4, itemName: "Chamomile");}),
          ],
        ),
      ],
    );
  }
}

class Object extends StatelessWidget {
  final PurchaseCallback onPurchase;

  const Object({
    super.key,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double spacewidth = screenWidth * 0.01;

    return ListView(
      scrollDirection: Axis.vertical,
      children: <Widget>[
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(child: Text("Garden Object", textAlign: TextAlign.center, style: TextStyle(fontSize: 22.5, fontWeight: FontWeight.bold))),
          ]
        ),
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShopItem(cost: 3, itemName: "Tools", asset: "assets/MIRU Catalog/ObjectGardeningTools.png", purchased: false, onPurchase: () {onPurchase(token: 3, itemName: "Tools");}),
            SizedBox(height: 8, width: spacewidth),
            ShopItem(cost: 3, itemName: "Wheelbarrow", asset: "assets/MIRU Catalog/ObjectWheelbarrow.png", purchased: false, onPurchase: () {onPurchase(token: 3, itemName: "Wheelbarrow");}),
            SizedBox(height: 8, width: spacewidth),
            ShopItem(cost: 4, itemName: "Mushrooms", asset: "assets/MIRU Catalog/ObjectMushrooms.png", purchased: false, onPurchase: () {onPurchase(token: 4, itemName: "Mushrooms");}),
          ],
        ),
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShopItem(cost: 12, itemName: "Birdbath", asset: "assets/MIRU Catalog/ObjectBirdBath.png", purchased: false, onPurchase: () {onPurchase(token: 12, itemName: "Birdbath");}),
            SizedBox(height: 8, width: spacewidth*2 + screenWidth * 0.6),
          ],
        ),
      ],
    );
  }
}

class Pond extends StatelessWidget {
  final PurchaseCallback onPurchase;

  const Pond({
    super.key,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double spacewidth = screenWidth * 0.01;

    return ListView(
      scrollDirection: Axis.vertical,
      children: <Widget>[
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(child: Text("Object", textAlign: TextAlign.center, style: TextStyle(fontSize: 22.5, fontWeight: FontWeight.bold))),
          ]
        ),
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShopItem(cost: 10, itemName: "Pond", asset: "assets/MIRU Catalog/Pond.png", purchased: false, onPurchase: () {onPurchase(token: 10, itemName: "Pond");}),
            SizedBox(height: 8, width: spacewidth),
            LockedShopItem(cost: 2, itemName: "Reed", asset: "assets/MIRU Catalog/PondGrass.png", purchased: false, needsPurchase: "Pond", onPurchase: () {onPurchase(token: 2, itemName: "Reed");}),
            SizedBox(height: 8, width: spacewidth),
            LockedShopItem(cost: 3, itemName: "Lilypad", asset: "assets/MIRU Catalog/PondLily.png", purchased: false, needsPurchase: "Pond", onPurchase: () {onPurchase(token: 3, itemName: "Lilypad");}),
          ],
        ),
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            LockedShopItem(cost: 5, itemName: "Koi", asset: "assets/MIRU Catalog/PondKoi.png", purchased: false, needsPurchase: "Pond", onPurchase: () {onPurchase(token: 5, itemName: "Koi");}),
            SizedBox(height: 8, width: spacewidth),
            LockedShopItem(cost: 6, itemName: "Fountain", asset: "assets/MIRU Catalog/PondFountain.png", purchased: false, needsPurchase: "Pond", onPurchase: () {onPurchase(token: 6, itemName: "Fountain");}),
            SizedBox(height: 8, width: spacewidth + screenWidth * 0.3),
          ],
        ),
      ],
    );
  }
}

class Tree extends StatelessWidget {
  final PurchaseCallback onPurchase;

  const Tree({
    super.key,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double spacewidth = screenWidth * 0.01;

    return ListView(
      scrollDirection: Axis.vertical,
      children: <Widget>[
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(child: Text("Object", textAlign: TextAlign.center, style: TextStyle(fontSize: 22.5, fontWeight: FontWeight.bold))),
          ]
        ),
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShopItem(cost: 8, itemName: "Tree", asset: "assets/MIRU Catalog/Tree.png", purchased: false, onPurchase: () {onPurchase(token: 8, itemName: "Tree");}),
            SizedBox(height: 8, width: spacewidth),
            LockedShopItem(cost: 3, itemName: "Apple", asset: "assets/MIRU Catalog/TreeApple.png", purchased: false, needsPurchase: "Tree", onPurchase: () {onPurchase(token: 3, itemName: "Apple");}),
            SizedBox(height: 8, width: spacewidth),
            LockedShopItem(cost: 3, itemName: "Orange", asset: "assets/MIRU Catalog/TreeOrange.png", purchased: false, needsPurchase: "Tree", onPurchase: () {onPurchase(token: 3, itemName: "Orange");}),
          ],
        ),
        SpaceBox(height: 15, width: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            LockedShopItem(cost: 3, itemName: "Pear", asset: "assets/MIRU Catalog/TreePear.png", purchased: false, needsPurchase: "Tree", onPurchase: () {onPurchase(token: 3, itemName: "Pear");}),
            SizedBox(height: 8, width: spacewidth),
            LockedShopItem(cost: 3, itemName: "Peach", asset: "assets/MIRU Catalog/TreePeach.png", purchased: false, needsPurchase: "Tree", onPurchase: () {onPurchase(token: 3, itemName: "Peach");}),
            SizedBox(height: 8, width: spacewidth + screenWidth * 0.3),
          ],
        ),
      ],
    );
  }
}
