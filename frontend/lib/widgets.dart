import 'package:flutter/material.dart';
import 'package:miru/shop.dart';

class StyledDivider extends StatelessWidget {
  final int option;

  const StyledDivider({
    super.key,
    required this.option,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: option == 1 ? 0 : 10,
      thickness: option == 1 ? 1 : 4,
      color: c500,
    );
  }
}

class SpaceBox extends StatelessWidget {
  final double height;
  final double width;

  const SpaceBox({
    super.key,
    required this.height,
    required this.width
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
    );
  }
}