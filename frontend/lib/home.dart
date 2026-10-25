import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:rive/rive.dart' as rive;
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:miru/shop.dart';

int balance = 0;
int barcodesScanned = 0;

typedef DisplayCallback = Future<void> Function({
  required String itemName,
  required String categoryName,
});

typedef PondDisplayCallback = Future<void> Function({
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

Map<String, String> displayedItems = {
  "Apparel": "Empty",
  "Flower": "Empty",
  "Ground": "Dirt",
  "Tree": "Empty",
  "Pond": "Empty",
  "Reed": "Empty",
  "Fountain": "Empty",
  "Lilypad": "Empty",
  "Koi": "Empty",
  "Objects": "Empty",
  "flowerShow" : "Empty",
  "treeShow" : "Empty",
};

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // Create the file loader once for this page.
  final _fileLoader = rive.FileLoader.fromAsset(
    'assets/Rives/mirufinal.riv',
    riveFactory: rive.Factory.rive,
  );
  final _fileLoaderCloud = rive.FileLoader.fromAsset(
    'assets/Rives/clouds.riv',
    riveFactory: rive.Factory.rive,
  );

  @override
  void dispose() {
    _fileLoader.dispose();
    _fileLoaderCloud.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedState();
    // _resetShopped();
  }

  bool _customizationReady = false;

  Future<void> _loadSavedState() async {
    try {
      await Future.wait([
        _getTokenFromSharedPref(),
        _getBarcodesScannedFromSharedPref(),
        _getShopBooleans(),
        _getDisplayedItems(),
      ]);
      if (!mounted) return;
      setState(() => _customizationReady = true);
    } catch (error) {
      debugPrint('Could not load saved home state: $error');
    }
  }

  // Future<void> _resetShopped() async{
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString('purchasedItems', '');
  // }

  Future<void> _getTokenFromSharedPref() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      final stored = prefs.get('tokenValue');
      balance = stored is int && stored >= 0 ? stored : 0;
    });
  }

  Future<void> _getBarcodesScannedFromSharedPref() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      final stored = prefs.get('scannedNumber');
      barcodesScanned = stored is int && stored >= 0 ? stored : 0;
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
          for (final key in defaultItems.keys) {
            if (decoded[key] is bool) resolvedItems[key] = decoded[key] as bool;
          }
        }
      } on FormatException {
        debugPrint('Could not read saved purchases.');
      }
    }
    resolvedItems['Dirt'] = true;

    if (!mounted) return;

    setState(() {
      purchasedItems = resolvedItems;
    });
  }

  Future<void> _getDisplayedItems() async {
    final prefs = await SharedPreferences.getInstance();

    final storedItems = prefs.get('displayedItems');
    final defaultItems = <String, String>{
      "Apparel": "Empty",
      "Flower": "Empty",
      "Ground": "Dirt",
      "Tree": "Empty",
      "Pond": "Empty",
      "Reed": "Empty",
      "Fountain": "Empty",
      "Lilypad": "Empty",
      "Koi": "Empty",
      "Objects": "Empty",
      "flowerShow" : "Empty",
      "treeShow" : "Empty",
    };

    final resolvedItems = <String, String>{...defaultItems};
    if (storedItems is String && storedItems.isNotEmpty) {
      try {
        final decoded = json.decode(storedItems);
        if (decoded is Map) {
          for (final key in defaultItems.keys) {
            if (decoded[key] is String) {
              resolvedItems[key] = decoded[key] as String;
            }
          }
        }
      } on FormatException {
        debugPrint('Could not read saved customization.');
      }
    }

    if (!mounted) return;

    setState(() {
      displayedItems = resolvedItems;
    });
  }

  Future<void> _displayItem({
    required String itemName,
    required String categoryName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    final enumName = switch (categoryName) {
      "Tree" => "enumTreeType",
      "treeShow" => "enumTree",
      "Objects" => "enumObject",
      "Flower" => "enumFlowerType",
      "flowerShow" => "enumFlower",
      _ => "enum$categoryName",
    };

    setState(() {
      displayedItems[categoryName] = itemName;

      if (categoryName != 'Flower' || itemName != 'Empty') {
        final enumerator = viewModel?.enumerator(enumName);
        enumerator?.value = itemName;
      }
    });

    await prefs.setString(
      'displayedItems',
      json.encode(displayedItems),
    );
  }

  Future<void> _displayPondItem({
    required String itemName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      if (displayedItems["Pond"] != "Empty") {
        String originalState = "";

        if (displayedItems[itemName] == "Empty") {
          originalState = "Empty";
          displayedItems[itemName] = "NotEmpty";
        } else if (displayedItems[itemName] == "NotEmpty") {
          originalState = "NotEmpty";
          displayedItems[itemName] = "Empty";
        }

        final boolean = viewModel?.boolean("boolean$itemName");
        if (originalState == "Empty") {
          boolean?.value = true;
        } else if (originalState == "NotEmpty") {
          boolean?.value = false;
        }

      }
    });

    await prefs.setString(
      'displayedItems',
      json.encode(displayedItems),
    );

  }

  Future<void> _displayPond({
    required String itemName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      String originalState = "";

      if (displayedItems["Pond"] == "Empty") {
        originalState = "Empty";
        displayedItems["Pond"] = "NotEmpty";
      } else if (displayedItems["Pond"] == "NotEmpty") {
        originalState = "NotEmpty";
        displayedItems["Pond"] = "Empty";
      }

      final booleanPond = viewModel?.boolean("booleanPond");
      final booleanReed = viewModel?.boolean("booleanReed");
      final booleanFountain = viewModel?.boolean("booleanFountain");
      final booleanLilypad = viewModel?.boolean("booleanLilypad");
      final booleanKoi = viewModel?.boolean("booleanKoi");
      
      
      if (originalState == "NotEmpty") {
        displayedItems["Reed"] = "Empty";
        displayedItems["Fountain"] = "Empty";
        displayedItems["Lilypad"] = "Empty";
        displayedItems["Koi"] = "Empty";
      }

      if (originalState == "Empty") {
        booleanPond?.value = true;
      } else if (originalState == "NotEmpty") {
        booleanPond?.value = false;
        booleanReed?.value = false;
        booleanFountain?.value = false;
        booleanLilypad?.value = false;
        booleanKoi?.value = false;
      }
    });

    await prefs.setString(
      'displayedItems',
      json.encode(displayedItems),
    );
  }

  Future<void> _display({required String itemName, required String categoryName, required Widget? displayFunction}) async {
    setState(() {
      if (displayedItems[categoryName] == itemName) {
        displayFunction = const Displayed();
      // }
      } else if (purchasedItems[itemName] == false) {
        displayFunction = const Locked();
      } else {
        displayFunction = null;
      }
    });
  }

  rive.ViewModelInstance? viewModel;


  @override
  Widget build(BuildContext context) {

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        rive.RiveWidgetBuilder(
          fileLoader: _fileLoaderCloud,

          builder: (context, state) {
            if (state is rive.RiveFailed) {
              return const Text('Could not load the Rive file.');
            }

            if (state is! rive.RiveLoaded) {
              return const CircularProgressIndicator();
            }

            return SizedBox(
              height: 140,
              child: rive.RiveWidget(
                controller: state.controller,
                fit: rive.Fit.contain,
              ),
            );
          },
        ),
        rive.RiveWidgetBuilder(
          fileLoader: _fileLoader,
          dataBind: rive.DataBind.auto(),

          builder: (context, state) {
            if (state is rive.RiveFailed) {
              return const Text('Could not load the Rive file.');
            }

            if (state is! rive.RiveLoaded) {
              return const CircularProgressIndicator();
            }

            viewModel = state.viewModelInstance;

            final flowerShow =
                viewModel?.enumerator('enumFlower');

            final apparel =
                viewModel?.enumerator('enumApparel');

            final ground =
              viewModel?.enumerator('enumGround');
            
            final object =
                viewModel?.enumerator('enumObject');
            
            final treeShow =
                viewModel?.enumerator('enumTree');
            
            final tree =
                viewModel?.enumerator('enumTreeType');
            
            final flower = 
                viewModel?.enumerator('enumFlowerType');
            
            final pond =
                viewModel?.boolean('booleanPond');
            
            final reed =
                viewModel?.boolean('booleanReed');
            
            final fountain =
                viewModel?.boolean('booleanFountain');
            
            final lilypad =
                viewModel?.boolean('booleanLilypad');
            
            final koi =
                viewModel?.boolean('booleanKoi');
            
            apparel?.value = displayedItems["Apparel"] ?? "Empty";

            ground?.value = displayedItems["Ground"] ?? "Dirt";

            flowerShow?.value = displayedItems["flowerShow"] ?? "Empty";

            final selectedFlower = displayedItems["Flower"];
            if (selectedFlower != null && selectedFlower != "Empty") {
              flower?.value = selectedFlower;
            }

            treeShow?.value = displayedItems["treeShow"] ?? "Empty";

            tree?.value = displayedItems["Tree"] ?? "Empty";

            object?.value = displayedItems["Objects"] ?? "Empty";

            pond?.value = displayedItems["Pond"] == "Empty" ? false: true;

            reed?.value = displayedItems["Reed"] == "Empty" ? false: true;

            fountain?.value = displayedItems["Fountain"] == "Empty" ? false: true;

            lilypad?.value = displayedItems["Lilypad"] == "Empty" ? false: true;

            koi?.value = displayedItems["Koi"] == "Empty" ? false: true;

            return SizedBox(
              height: 385,
              child: rive.RiveWidget(
                controller: state.controller,
                fit: rive.Fit.contain,
              ),
            );
          },
        ),
        Padding(
          padding: EdgeInsetsGeometry.all(15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$barcodesScanned",
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)
                      ),
                      Text(
                        " Scans",
                        style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.normal)
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$balance",
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)
                      ),
                      Text(
                        " Tokens",
                        style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.normal)
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: !_customizationReady ? null : () {
                      showDialog(
                        context: context,
                        builder: (context) => 
                        StatefulBuilder(
                          builder: (BuildContext context, StateSetter setState) {
                          return AlertDialog(
                            insetPadding: EdgeInsets.zero, 
                            title: Text("Custom", style: TextStyle(fontSize: 17.5)),
                            content: SizedBox(
                              width: MediaQuery.sizeOf(context).width * 0.8,
                              height: MediaQuery.sizeOf(context).height * 0.8,
                              child: ListView(
                                scrollDirection: Axis.vertical,
                                children: [
                                  Text("Apparel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0)),
                                  SizedBox(height: 5, width: 5),
                                  Row(
                                    children: [
                                      DisplayItem(itemName: "Empty", asset: "assets/MIRU Catalog/Empty.png", categoryName: "Apparel", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      DisplayItem(itemName: "Ribbon", asset: "assets/MIRU Catalog/ApparelRibbon.png", categoryName: "Apparel", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      DisplayItem(itemName: "Glasses", asset: "assets/MIRU Catalog/ApparelGlass.png", categoryName: "Apparel", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      DisplayItem(itemName: "Sunglasses", asset: "assets/MIRU Catalog/ApparelSunglass.png", categoryName: "Apparel", onDisplay: _displayItem, setCheck: setState,),
                                    ],
                                  ),
                                  SizedBox(height: 7.5, width: 5),
                                  Row(
                                    children: [
                                      DisplayItem(itemName: "Mustache", asset: "assets/MIRU Catalog/ApparelMustache.png", categoryName: "Apparel", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      DisplayItem(itemName: "Monocle", asset: "assets/MIRU Catalog/ApparelMonocle.png", categoryName: "Apparel", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      DisplayItem(itemName: "Hat", asset: "assets/MIRU Catalog/ApparelHat.png", categoryName: "Apparel", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      DisplayItem(itemName: "Cap", asset: "assets/MIRU Catalog/ApparelCap.png", categoryName: "Apparel", onDisplay: _displayItem, setCheck: setState,),
                                    ],
                                  ),



                                  SizedBox(height: 25, width: 5),



                                  Text("Ground", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0)),
                                  SizedBox(height: 5, width: 5),
                                  Row(
                                    children: [
                                      DisplayItem(itemName: "Dirt", asset: "assets/MIRU Catalog/GroundDirt.png", categoryName: "Ground", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      DisplayItem(itemName: "Sand", asset: "assets/MIRU Catalog/GroundSand.png", categoryName: "Ground", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      DisplayItem(itemName: "Grass", asset: "assets/MIRU Catalog/GroundGrass.png", categoryName: "Ground", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                    ],
                                  ),



                                  SizedBox(height: 25, width: 5),


                                  Text("Flower", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0)),
                                  SizedBox(height: 5, width: 5),
                                  Row(
                                    children: [
                                      FlowerItem(itemName: "Empty", asset: "assets/MIRU Catalog/Empty.png", categoryName: "Flower", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      FlowerItem(itemName: "Rose", asset: "assets/MIRU Catalog/FlowerRose.png", categoryName: "Flower", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      FlowerItem(itemName: "Daffodil", asset: "assets/MIRU Catalog/FlowerDaffodil.png", categoryName: "Flower", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      FlowerItem(itemName: "Cornflower", asset: "assets/MIRU Catalog/FlowerCornflower.png", categoryName: "Flower", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      // 
                                    ],
                                  ),
                                  SizedBox(height: 7.5, width: 5),
                                  Row(
                                    children: [
                                      FlowerItem(itemName: "Lavender", asset: "assets/MIRU Catalog/FlowerLavender.png", categoryName: "Flower", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      FlowerItem(itemName: "Carnation", asset: "assets/MIRU Catalog/FlowerPetunia.png", categoryName: "Flower", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      FlowerItem(itemName: "Chamomile", asset: "assets/MIRU Catalog/FlowerChamomile.png", categoryName: "Flower", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                    ],
                                  ),



                                  SizedBox(height: 25, width: 5),


                                  Text("Tree", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0)),
                                  SizedBox(height: 5, width: 5),
                                  Row(
                                    children: [
                                      TreeItem(itemName: "Empty", asset: "assets/MIRU Catalog/Empty.png", categoryName: "Tree", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      TreeItem(itemName: "Tree", asset: "assets/MIRU Catalog/Tree.png", categoryName: "Tree", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      TreeItem(itemName: "Apple", asset: "assets/MIRU Catalog/TreeApple.png", categoryName: "Tree", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      TreeItem(itemName: "Orange", asset: "assets/MIRU Catalog/TreeOrange.png", categoryName: "Tree", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      // 
                                    ],
                                  ),
                                  SizedBox(height: 7.5, width: 5),
                                  Row(
                                    children: [
                                      TreeItem(itemName: "Peach", asset: "assets/MIRU Catalog/TreePeach.png", categoryName: "Tree", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      TreeItem(itemName: "Pear", asset: "assets/MIRU Catalog/TreePear.png", categoryName: "Tree", onDisplay: _displayItem, setCheck: setState,),
                                    ],
                                  ),


                                  SizedBox(height: 25, width: 5),


                                  Text("Pond", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0)),
                                  SizedBox(height: 5, width: 5),
                                  Row(
                                    children: [
                                      PondItem(itemName: "Pond", asset: "assets/MIRU Catalog/Pond.png", onPond: _displayPond, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      PondItem(itemName: "Reed", asset: "assets/MIRU Catalog/PondGrass.png", onPond: _displayPondItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      PondItem(itemName: "Lilypad", asset: "assets/MIRU Catalog/PondLily.png", onPond: _displayPondItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      PondItem(itemName: "Koi", asset: "assets/MIRU Catalog/PondKoi.png", onPond: _displayPondItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      // 
                                    ],
                                  ),
                                  SizedBox(height: 7.5, width: 5),
                                  Row(
                                    children: [
                                      PondItem(itemName: "Fountain", asset: "assets/MIRU Catalog/PondFountain.png", onPond: _displayPondItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                    ],
                                  ),



                                  SizedBox(height: 25, width: 5),


                                  Text("Garden Objects", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0)),
                                  SizedBox(height: 5, width: 5),
                                  Row(
                                    children: [
                                      DisplayItem(itemName: "Empty", asset: "assets/MIRU Catalog/Empty.png", categoryName: "Objects", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      DisplayItem(itemName: "Tools", asset: "assets/MIRU Catalog/ObjectGardeningTools.png", categoryName: "Objects", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      DisplayItem(itemName: "Wheelbarrow", asset: "assets/MIRU Catalog/ObjectWheelbarrow.png", categoryName: "Objects", onDisplay: _displayItem, setCheck: setState,),
                                      SizedBox(height: 5, width: MediaQuery.sizeOf(context).width * 0.02),
                                      DisplayItem(itemName: "Mushrooms", asset: "assets/MIRU Catalog/ObjectMushrooms.png", categoryName: "Objects", onDisplay: _displayItem, setCheck: setState,),
                                    ],
                                  ),
                                  SizedBox(height: 7.5, width: 5),
                                  Row(
                                    children: [
                                      DisplayItem(itemName: "Birdbath", asset: "assets/MIRU Catalog/ObjectBirdBath.png", categoryName: "Objects", onDisplay: _displayItem, setCheck: setState,),
                                    ],
                                  ),
                                ],
                              )
                            ),
                            actions: [
                              TextButton(
                                child: Text('OK'),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          );
                        }),
                      );
                    },
                    icon: const Icon(CupertinoIcons.paintbrush),
                    label: const Text('Customize'),
                  ),
                ]
              )
            ]
          ),
        ),
      ]
      ),
    );
  }
}

class DisplayItem extends StatefulWidget {
  final String itemName;
  final String asset;
  final String categoryName;
  final DisplayCallback onDisplay;
  final StateSetter setCheck;

  const DisplayItem({
    super.key,
    required this.itemName,
    required this.asset,
    required this.categoryName,
    required this.onDisplay,
    required this.setCheck,
  });

  @override
  State<DisplayItem> createState() => _DisplayItemState();
}

class _DisplayItemState extends State<DisplayItem> {
  String get itemName => widget.itemName;
  String get asset => widget.asset;
  String get categoryName => widget.categoryName;
  DisplayCallback get onDisplay => widget.onDisplay;
  StateSetter get setCheck => widget.setCheck;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final String itemName = widget.itemName;

    return SizedBox(
      width: screenWidth * 0.18,
      child: Material(
      color: c200,
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: InkWell(
        splashColor: Colors.lightGreen[200]?.withValues(alpha: 0.35),
        onTap: () async {
            if (purchasedItems[itemName] == true || itemName == 'Empty') {
              await onDisplay(categoryName: categoryName, itemName: itemName);
              if (!mounted) return;
              setCheck(() {});
          } else if (purchasedItems[itemName] == false) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Not Available"),
                content: Text('Please purchase the item in Shop to display it.'),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ink.image(
              image: AssetImage(asset),
              width: screenWidth * 0.18,
              height: screenWidth * 0.18,
              fit: BoxFit.cover,
              child: displayedItems[categoryName] == itemName ?
                Displayed() :
                purchasedItems[itemName] == false ?
                Locked() : 
                null,
              // )
            ),
            SizedBox(height: 5, width: 5),
            Text(itemName, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.0)),
            SizedBox(height: 8, width: 5),
          ]
        ),
      ),
      ),
    );
  }
}

class TreeItem extends StatefulWidget {
  final String itemName;
  final String asset;
  final String categoryName;
  final DisplayCallback onDisplay;
  final StateSetter setCheck;

  const TreeItem({
    super.key,
    required this.itemName,
    required this.asset,
    required this.categoryName,
    required this.onDisplay,
    required this.setCheck,
  });

  @override
  State<TreeItem> createState() => _TreeItemState();
}

class _TreeItemState extends State<TreeItem> {

  String get itemName => widget.itemName;
  String get asset => widget.asset;
  String get categoryName => widget.categoryName;
  DisplayCallback get onDisplay => widget.onDisplay;
  StateSetter get setCheck => widget.setCheck;
  final String enumShowName = "treeShow";
  final String showName = "Tree";

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final String itemName = widget.itemName;

    return SizedBox(
      width: screenWidth * 0.18,
      child: Material(
      color: c200,
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: InkWell(
        splashColor: Colors.lightGreen[200]?.withValues(alpha: 0.35),
        onTap: () async { if (displayedItems[categoryName] != itemName && purchasedItems[itemName] == true || itemName == 'Empty') {
            if (itemName != "Empty" && itemName != "Tree" && purchasedItems["Tree"] == true) {
              await onDisplay(categoryName: categoryName, itemName: itemName);
              await onDisplay(categoryName: enumShowName, itemName: showName);
              if (!mounted) return;
              setCheck(() {});
            } else if (itemName == "Tree") {
              await onDisplay(categoryName: categoryName, itemName: "Empty");
              await onDisplay(categoryName: enumShowName, itemName: showName);
              if (!mounted) return;
              setCheck(() {});
            } else if (itemName == "Empty") {
              await onDisplay(categoryName: categoryName, itemName: itemName);
              await onDisplay(categoryName: enumShowName, itemName: "Empty");
              if (!mounted) return;
              setCheck(() {});
            }
          } else if (purchasedItems[itemName] == false) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Not Available"),
                content: Text('Please purchase the item in Shop to display it.'),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ink.image(
              image: AssetImage(asset),
              width: screenWidth * 0.18,
              height: screenWidth * 0.18,
              fit: BoxFit.cover,
              child: itemName != "Empty" && displayedItems[categoryName] == itemName || itemName == "Empty" && displayedItems["treeShow"] == "Empty"?
                Displayed() :
                displayedItems["treeShow"] == "Tree" && itemName == "Tree" && displayedItems[categoryName] == "Empty" ?
                Displayed() :
                purchasedItems[itemName] == false ?
                Locked() : 
                null,
              // )
            ),
            SizedBox(height: 5, width: 5),
            Text(itemName, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.0)),
            SizedBox(height: 8, width: 5),
          ]
        ),
      ),
      ),
    );
  }
}

class FlowerItem extends StatefulWidget {
  final String itemName;
  final String asset;
  final String categoryName;
  final DisplayCallback onDisplay;
  final StateSetter setCheck;

  const FlowerItem({
    super.key,
    required this.itemName,
    required this.asset,
    required this.categoryName,
    required this.onDisplay,
    required this.setCheck,
  });

  @override
  State<FlowerItem> createState() => _FlowerItemState();
}

class _FlowerItemState extends State<FlowerItem> {

  String get itemName => widget.itemName;
  String get asset => widget.asset;
  String get categoryName => widget.categoryName;
  DisplayCallback get onDisplay => widget.onDisplay;
  StateSetter get setCheck => widget.setCheck;
  final String enumShowName = "flowerShow";
  final String showName = "Flower";

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final String itemName = widget.itemName;

    return SizedBox(
      width: screenWidth * 0.18,
      child: Material(
      color: c200,
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: InkWell(
        splashColor: Colors.lightGreen[200]?.withValues(alpha: 0.35),
        onTap: () async { if (displayedItems[categoryName] != itemName && purchasedItems[itemName] == true || itemName == 'Empty') {
            if (itemName != "Empty") {
              await onDisplay(categoryName: categoryName, itemName: itemName);
              await onDisplay(categoryName: enumShowName, itemName: showName);
              if (!mounted) return;
              setCheck(() {});
            } else if (itemName == "Empty") {
              await onDisplay(categoryName: categoryName, itemName: itemName);
              await onDisplay(categoryName: enumShowName, itemName: "Empty");
              if (!mounted) return;
              setCheck(() {});
            }
          } else if (purchasedItems[itemName] == false) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Not Available"),
                content: Text('Please purchase the item in Shop to display it.'),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ink.image(
              image: AssetImage(asset),
              width: screenWidth * 0.18,
              height: screenWidth * 0.18,
              fit: BoxFit.cover,
              child: itemName != "Empty" && displayedItems[categoryName] == itemName && displayedItems["flowerShow"] == "Flower" || itemName == "Empty" && displayedItems["flowerShow"] == "Empty"?
                Displayed() :
                purchasedItems[itemName] == false ?
                Locked() : 
                null,
              // )
            ),
            SizedBox(height: 5, width: 5),
            Text(itemName, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.0)),
            SizedBox(height: 8, width: 5),
          ]
        ),
      ),
      ),
    );
  }
}

class PondItem extends StatefulWidget {
  final String itemName;
  final String asset;
  final PondDisplayCallback onPond;
  final StateSetter setCheck;

  const PondItem({
    super.key,
    required this.itemName,
    required this.asset,
    required this.onPond,
    required this.setCheck,
  });

  @override
  State<PondItem> createState() => _PondItemState();
}

class _PondItemState extends State<PondItem> {

  String get itemName => widget.itemName;
  String get asset => widget.asset;
  PondDisplayCallback get onPond => widget.onPond;
  StateSetter get setCheck => widget.setCheck;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final String itemName = widget.itemName;

    return SizedBox(
      width: screenWidth * 0.18,
      child: Material(
      color: c200,
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: InkWell(
        splashColor: Colors.lightGreen[200]?.withValues(alpha: 0.35),
        onTap: () async { if (purchasedItems[itemName] == true) {
            await onPond(itemName: itemName);
            if (!mounted) return;
            setCheck(() {});
          } else if (purchasedItems[itemName] == false) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Not Available"),
                content: Text('Please purchase the item in Shop to display it.'),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ink.image(
              image: AssetImage(asset),
              width: screenWidth * 0.18,
              height: screenWidth * 0.18,
              fit: BoxFit.cover,
              child: displayedItems[itemName] == "NotEmpty" ?
                Displayed() :
                purchasedItems[itemName] == false ?
                Locked() : 
                null,
              // )
            ),
            SizedBox(height: 5, width: 5),
            Text(itemName, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.0)),
            SizedBox(height: 8, width: 5),
          ]
        ),
      ),
      ),
    );
  }
}

class Displayed extends StatelessWidget {
  const Displayed({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        CupertinoIcons.check_mark,
        color: c900,
        size: 50.0,
      ),
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