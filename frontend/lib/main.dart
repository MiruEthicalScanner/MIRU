import 'package:lock_orientation_screen/lock_orientation_screen.dart';

import 'package:flutter/material.dart';
import 'package:miru/history.dart';
import 'package:miru/home.dart';
import 'package:miru/scan.dart';
import 'package:miru/settings.dart';
import 'package:miru/shop.dart';

import 'package:miru/product_info.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/cupertino.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    BetterFeedback(
      theme: FeedbackThemeData(
        background: Colors.white,
        drawColors: [
          Colors.redAccent.shade400,
          Colors.lightGreen.shade800,
          Colors.lightBlue.shade600,
        ],
        activeFeedbackModeColor: c800 ?? Colors.white,
        feedbackSheetColor: c100 ?? Colors.white,
        dragHandleColor: c300 ?? Colors.grey,
        bottomSheetDescriptionStyle: TextStyle(
          color: c800,
          fontFamily: GoogleFonts.poppins().fontFamily,
        ),
        bottomSheetTextInputStyle: TextStyle(
          color: c800,
          fontFamily: GoogleFonts.poppins().fontFamily,
        ),
        colorScheme: ColorScheme.fromSwatch(),
      ),
      child: MainApp()
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: AppBarThemeData(
          backgroundColor: c100,
          titleTextStyle: TextStyle(
          color: Colors.black87,
          fontWeight: .bold,
          fontSize: (25.0),
        ),
        toolbarHeight: 55.0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: c100,
          titleTextStyle: TextStyle(color: Colors.black87, fontFamily: GoogleFonts.poppins().fontFamily, fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: Colors.black87, fontFamily: GoogleFonts.poppins().fontFamily),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: c800,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: c300,
            foregroundColor: Colors.black87,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            backgroundColor: c300,
            foregroundColor: Colors.black87,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: c100,
          foregroundColor: Colors.black87,
          splashColor: c200,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return c300;
            }
            return c600;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return c100;
            }
            return c200;
          }),
        ),
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget{
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

var preIndex = 0;
var index = 0;

class _MainPageState extends State<MainPage> {

  var _bottomNavIndex = 0;

  final iconList = <IconData>[
    CupertinoIcons.home,
    CupertinoIcons.list_bullet,
    CupertinoIcons.cart,
    CupertinoIcons.info
  ];

  // wonkadoodles
  late final pages = <Widget> [
    Home(),
    History(),
    Shop(),
    Settings(),
    MobileScannerSimple(update: _update),
    ProductInformation(),
  ];

  Color? fabColor = c600;

  void _update(
    int page, {
    String? barcodeNumber,
    String? companyName,
    String? productName,
  }) {
    if (!mounted) return;

    setState(() {
      if (page == 5) {
        pages[5] = ProductInformation(
          key: UniqueKey(),
          barcodeNumber: barcodeNumber,
          companyName: companyName,
          productName: productName,
        );
      }
      _bottomNavIndex = page;
    });
  }

  @override
  Widget build(BuildContext context) => LockOrientation(
    child: Scaffold(
      appBar: AppBar(
        title: Text( _bottomNavIndex == 0 ? 'MIRU' :  _bottomNavIndex == 1 ? 'History' :  _bottomNavIndex == 2 ? 'Shop' :  _bottomNavIndex == 3 ? 'Settings' :  _bottomNavIndex == 4 ? 'Scan' : 'Product Information', style: GoogleFonts.poppins()),
        leading: IconButton(
          icon: Icon(_bottomNavIndex == 5 ? Icons.arrow_back_ios : null),
          onPressed: () => setState(() {
            if (_bottomNavIndex == 5) {
              _bottomNavIndex = 4;
            }
          }),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            highlightColor: _bottomNavIndex == 5 ? c300 : Colors.transparent,
          ),
        ),
      ),
      body: pages[_bottomNavIndex], //destination screen
      floatingActionButton: FloatingActionButton(
        foregroundColor: fabColor,
        shape: CircleBorder(),
        child: Icon(CupertinoIcons.barcode_viewfinder),
        onPressed: () => setState(() {
          _bottomNavIndex = 4;
          fabColor = Colors.black87;          
        }),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        backgroundColor: c100,
        itemCount: iconList.length,
        tabBuilder: (int index, bool isActive) {
          return Icon(
            iconList[index],
            size: 24,
            color: isActive ? Colors.black87 : c600,
          );
        },
        activeIndex: _bottomNavIndex,
        gapLocation: GapLocation.center,
        notchSmoothness: NotchSmoothness.defaultEdge,
        leftCornerRadius: 32,
        rightCornerRadius: 32,
        onTap: (index) => setState(() {
          fabColor = c600;
          _bottomNavIndex = index;
        }),
      ),
    )
  );

}
