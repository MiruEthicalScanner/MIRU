import 'dart:async';

import 'package:flutter/material.dart';

import 'package:miru/widgets.dart';
import 'package:miru/product_info.dart';
import 'package:miru/scan_history.dart' as scan_history;
import 'package:flutter/cupertino.dart';

Map<String, dynamic> get historyItems => scan_history.historyItems;

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedHistory());
  }

  Future<void> _loadSavedHistory() async {
    try {
      await scan_history.loadScanHistory();
    } catch (error) {
      debugPrint('Could not load scan history: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: scan_history.historyItemsListenable,
      builder: (context, historyItems, child) {
        return Padding(
          padding: const EdgeInsets.all(15.0),
          child: ListView(
            scrollDirection: Axis.vertical,
            children: <Widget>[
              for (var slot = 1; slot <= 5; slot++)
                if (historyItems['Company$slot'] != null)
                  OverallScoresHistory(
                    companyName: historyItems['Company$slot'] as String,
                    animalScore: historyItems['Animal$slot'] as int?,
                    peopleScore: historyItems['People$slot'] as int?,
                    environmentScore: historyItems['Environment$slot'] as int?,
                  ),
              const Text('History is not saved beyond 5 products.'),
              SpaceBox(height: 50, width: 50),
            ],
          ),
        );
      },
    );
  }
}

Color? _historyIconColor(int? score) {
  if (score == null) return Colors.grey;
  return (score < 4)
      ? Colors.red[400]
      : (score < 7)
          ? Colors.yellow[400]
          : Colors.green[400];
}

class OverallScoresHistory extends StatelessWidget {
  final String companyName;
  final int? animalScore;
  final int? peopleScore;
  final int? environmentScore;

  const OverallScoresHistory({
    super.key,
    required this.companyName,
    required this.animalScore,
    required this.peopleScore,
    required this.environmentScore,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < 260 ||
          MediaQuery.textScalerOf(context).scale(17.5) > 26.25;
      final company = Text(companyName, style: const TextStyle(fontSize: 20));
      return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Flex(
          direction: stacked ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: stacked
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: <Widget>[
            if (stacked) company else Expanded(child: company),
            if (stacked)
              const SizedBox(height: 8)
            else
              const Expanded(child: SizedBox()),
            SizedBox(
              width: stacked ? constraints.maxWidth : 200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.paw_solid,
                        color: _historyIconColor(animalScore),
                      ),
                      Expanded(
                        child: StyledSlider(max: ten, score: animalScore),
                      ),
                      Text(
                        animalScore == null ? '—/10' : '$animalScore/10',
                        style: const TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.hand_raised_fill,
                        color: _historyIconColor(peopleScore),
                      ),
                      Expanded(
                        child: StyledSlider(max: ten, score: peopleScore),
                      ),
                      Text(
                        peopleScore == null ? '—/10' : '$peopleScore/10',
                        style: const TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.tree,
                        color: _historyIconColor(environmentScore),
                      ),
                      Expanded(
                        child: StyledSlider(max: ten, score: environmentScore),
                      ),
                      Text(
                        environmentScore == null
                            ? '—/10'
                            : '$environmentScore/10',
                        style: const TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        StyledDivider(option: 2),
        const SizedBox(height: 15),
      ],
      );
    });
  }
}