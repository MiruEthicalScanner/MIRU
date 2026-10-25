// ignore: unused_import
// ignore_for_file: unused_import

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/cupertino.dart';
// import 'package:miru/main.dart';

// ignore: unused_import
import 'package:miru/widgets.dart';
import 'package:miru/shop.dart';
import 'package:miru/product_info.dart';

import 'package:google_fonts/google_fonts.dart';

// String barcodeNum = "0";

// String companyName = "";
// String productName = "";

/// Implementation of Mobile Scanner example with simple configuration
class MobileScannerSimple extends StatefulWidget {
  final void Function(
    int page, {
    String? barcodeNumber,
    String? companyName,
    String? productName,
  }) update;

  const MobileScannerSimple({
    super.key,
    required this.update,
  });

  @override
  State<MobileScannerSimple> createState() => _MobileScannerSimpleState();
}

class _MobileScannerSimpleState extends State<MobileScannerSimple> {
  Barcode? _barcode;
  final _company = TextEditingController();
  final _product = TextEditingController();
  bool _busy = false;

  // @override
  // void dispose() {
  //   _company.dispose();
  //   super.dispose();
  // }

  @override
  void dispose() {
    _company.dispose();
    _product.dispose();
    super.dispose();
  }

  // Widget _barcodePreview(Barcode? value) {
  //   if (value == null) {
  //     return Text(
  //       'Scan a Barcode to MIRU its Ethicality',
  //       overflow: TextOverflow.fade,
  //       style: TextStyle(color: c900, fontSize: 20.0),
  //     );
  //   }

  //   return Text(
  //     value.displayValue ?? 'Barcode Not Found',
  //     overflow: TextOverflow.fade,
  //     style: TextStyle(color: c900),
  //   );
  // }

  // void _handleBarcode(BarcodeCapture barcodes) {
  //   if (mounted) {
  //     setState(() {
  //       _barcode = barcodes.barcodes.firstOrNull;
  //     });
  //     if (_barcode != null) {
  //       barcodeNum = _barcode?.rawValue ?? "0";
  //       // dispose();
  //       widget.update(5);
  //       _incrementScanned();
  //       _incrementToken();
  //     }
  //   }
  // }

  void _handleBarcode(BarcodeCapture barcodes) {
    if (!mounted || _busy) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;

    final barcode = barcodes.barcodes
        .where((barcode) => barcode.rawValue?.trim().isNotEmpty ?? false)
        .firstOrNull;
    final value = barcode?.rawValue?.trim();
    if (value == null || value.isEmpty) return;

    setState(() {
      _busy = true;
      _barcode = barcode;
    });

    FocusScope.of(context).unfocus();
    widget.update(5, barcodeNumber: value);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
        children: <Widget>[
          SpaceBox(height: 5, width: 5),
          Text("Scan a Barcode to MIRU its Ethicality", style: TextStyle(fontSize: 20.0)),
          SpaceBox(height: 5, width: 5),
          Expanded(
            child: SizedBox(
              height: 180,
              child: MobileScanner(
                onDetect: _handleBarcode,
                errorBuilder: (context, error) => ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        error.errorCode == MobileScannerErrorCode.permissionDenied
                            ? 'Camera access is off. You can search below, or '
                                'enable Camera for MIRU in Settings and reopen Scan.'
                            : 'Camera unavailable. Please use the search below.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SpaceBox(height: 20, width: 5),
          Text("Search for a Company", style: TextStyle(fontSize: 20.0)),
          SpaceBox(height: 5, width: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SpaceBox(height: 5, width: 5),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _company,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: 'Enter COMPANY name',
                        border: const OutlineInputBorder(),
                        labelStyle: const TextStyle(color: Colors.black, fontSize: 15.0),
                        hintStyle: const TextStyle(color: Colors.black, fontSize: 15.0),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: c600 ?? Colors.black, width: 1.0),
                        ),
                        // Border color when the text field IS focused
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: c600 ?? Colors.black, width: 2.0),
                        ),
                      ),
                      cursorColor: c600 ?? Colors.black,
                    ),
                    SpaceBox(height: 5, width: 5),
                    TextField(
                      controller: _product,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: 'Enter PRODUCT name',
                        border: const OutlineInputBorder(),
                        labelStyle: const TextStyle(color: Colors.black, fontSize: 15.0),
                        hintStyle: const TextStyle(color: Colors.black, fontSize: 15.0),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: c600 ?? Colors.black, width: 1.0),
                        ),
                        // Border color when the text field IS focused
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: c600 ?? Colors.black, width: 2.0),
                        ),
                      ),
                      cursorColor: c600 ?? Colors.black,
                    ),
                  ],
                ),
              ),
              SpaceBox(height: 5, width: 5),
              IconButton(
                icon: const Icon(CupertinoIcons.search, size: 25.0),
                tooltip: 'Search for Ethicality',
                // onPressed: () {
                //   companyName = _company.text;
                //   productName = _product.text;
                //   if (companyName != "" && productName != "") {
                //     widget.update(5);
                //     _incrementScanned();
                //     _incrementToken();
                //   }
                // },
                onPressed: () {
                  if (!mounted || _busy) return;

                  final company = _company.text.trim();
                  final product = _product.text.trim();

                  if (company.isEmpty || product.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter both a product and company name.'),
                      ),
                    );
                    return;
                  }

                  setState(() => _busy = true);
                  FocusScope.of(context).unfocus();

                  widget.update(
                    5,
                    companyName: company,
                    productName: product,
                  );
                },
                style: IconButton.styleFrom(
                  fixedSize: const Size(75, 115),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0), // Lower value = less rounded/sharper edges
                  ),
                ),
              ),
              SpaceBox(height: 5, width: 5),
            ]
          ),
          SpaceBox(height: 20, width: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SpaceBox(height: 5, width: 10),
              Flexible(child: AlertButton()),
            ]
          ),
          SpaceBox(height: 5, width: 5)
        ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AlertButton extends StatelessWidget{
  const AlertButton({super.key});

  @override
  Widget build(BuildContext context ) {
    return ElevatedButton.icon(
      label: Text('Accuracy Note'),
      icon: const Icon(CupertinoIcons.exclamationmark_circle),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text("Note on Accuracy"),
            content: Text(
              'The ethicality scores may be innacurate for small-scale companies due to lack of information available on the internet.'
            ),
            actions: [
              // TextButton(
              //   child: Text('CANCEL'),
              //   onPressed: () => Navigator.pop(context),
              // ),
              TextButton(
                child: Text('OK'),
                onPressed: () => Navigator.pop(context),
              )
            ]
          ),
        );
      }
    );
  }
}
