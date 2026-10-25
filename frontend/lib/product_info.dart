import 'dart:async';

import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:miru/api_service.dart'
    show ScoreApi, ScoreApiException, apiBaseUrl;
import 'package:miru/scan_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _miruApiBaseUrl = apiBaseUrl;

// Shared latest result, kept for existing history and score widgets.
final scoreResult = ValueNotifier<Map<String, dynamic>?>(null);
String? scoreBarcode;
const five = 5.0;
const ten = 10.0;

Map<String, dynamic> _map(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

Map<String, dynamic> dimensionData(String dimension) =>
    _map(scoreResult.value?[dimension]);

int? _number(dynamic value, int maximum) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > maximum ||
      value != value.round()) {
    return null;
  }
  return value.toInt();
}

String get brandName => scoreResult.value?['company_name']?.toString() ?? '';
String get productName => scoreResult.value?['product_name']?.toString() ?? '';
int? get animalScore => _number(dimensionData('animal_welfare')['score'], 10);
int? get laborScore => _number(dimensionData('ethical_labor')['score'], 10);
int? get environmentScore => _number(dimensionData('sustainability')['score'], 10);

int? categoryScore(String dimension, String category) =>
    _number(_map(dimensionData(dimension)['breakdown'])[category], 5);

const _labels = <String, String>{
  'water': 'Water',
  'materials': 'Materials',
  'emissions': 'Emissions',
  'renewability': 'Renewability',
  'deforestation': 'Deforestation',
  'waste': 'Waste',
  'chemicals': 'Chemicals',
  'transparency': 'Transparency',
  'animal_testing': 'Animal Testing',
  'animal_derived_materials': 'Ingredients',
  'animal_treatment': 'Welfare',
  'supplier_accountability': 'Accountability',
  'living_conditions': 'Living Conditions',
  'procedures': 'Procedures',
  'transport': 'Transport',
  'slaughter': 'Slaughter',
  'forced_labor': 'Forced Labor',
  'child_labor': 'Child Labor',
  'wages_and_benefits': 'Wages',
  'health_and_safety': 'Health & Safety',
  'association': 'Association',
  'grievances': 'Grievances',
  'working_hours_and_job_security': 'Hours & Security',
  'equality_and_harassment': 'Equality',
};

const _environmentOrder = [
  'water',
  'materials',
  'emissions',
  'renewability',
  'deforestation',
  'waste',
  'chemicals',
  'transparency',
];
const _laborOrder = [
  'forced_labor',
  'child_labor',
  'wages_and_benefits',
  'health_and_safety',
  'association',
  'grievances',
  'working_hours_and_job_security',
  'equality_and_harassment',
  'transparency',
];
const _nonAnimalOrder = [
  'animal_testing',
  'animal_derived_materials',
  'animal_treatment',
  'supplier_accountability',
];
const _animalProductOrder = [
  'living_conditions',
  'procedures',
  'transport',
  'slaughter',
];

List<String> _categories(
  String dimension,
  Map<String, dynamic> data, {
  String? animalRubricType,
}) {
  final returned = <String>{
    ..._map(data['breakdown']).keys,
    ..._map(data['evidence']).keys,
  };
  final List<String> order;
  if (dimension == 'sustainability') {
    order = _environmentOrder;
  } else if (dimension == 'ethical_labor') {
    order = _laborOrder;
  } else {
    order = animalRubricType == 'animal_products'
        ? _animalProductOrder
        : _nonAnimalOrder;
  }
  return [
    ...order.where(returned.contains),
    ...returned.where((category) => !order.contains(category)),
  ];
}

String _label(String key) =>
    _labels[key] ??
    key
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');

IconData _categoryIcon(String category) {
  switch (category) {
    case 'water':
      return CupertinoIcons.drop;
    case 'materials':
      return CupertinoIcons.layers_alt;
    case 'emissions':
      return CupertinoIcons.smoke;
    case 'renewability':
      return CupertinoIcons.leaf_arrow_circlepath;
    case 'deforestation':
      return CupertinoIcons.tree;
    case 'waste':
      return CupertinoIcons.trash;
    case 'chemicals':
    case 'animal_testing':
      return CupertinoIcons.lab_flask;
    case 'animal_derived_materials':
      return CupertinoIcons.list_bullet;
    case 'animal_treatment':
      return CupertinoIcons.house_alt;
    case 'living_conditions':
      return CupertinoIcons.paw;
    case 'procedures':
      return CupertinoIcons.scissors;
    case 'transport':
      return CupertinoIcons.car;
    case 'slaughter':
      return CupertinoIcons.heart_slash;
    case 'forced_labor':
      return CupertinoIcons.lock;
    case 'child_labor':
      return CupertinoIcons.person;
    case 'wages_and_benefits':
      return CupertinoIcons.money_dollar_circle;
    case 'health_and_safety':
      return CupertinoIcons.shield;
    case 'association':
      return CupertinoIcons.person_3;
    case 'grievances':
      return CupertinoIcons.bubble_left_bubble_right;
    case 'working_hours_and_job_security':
      return CupertinoIcons.clock;
    case 'equality_and_harassment':
      return CupertinoIcons.equal_circle;
    default:
      return CupertinoIcons.doc_plaintext;
  }
}

Color _overallColor(int? score) {
  if (score == null) return Colors.grey;
  if (score < 4) return Colors.red;
  if (score < 7) return Colors.yellow;
  return Colors.green;
}

Color _categoryColor(int? score) {
  if (score == null) return Colors.grey;
  if (score >= 5) return Colors.green.shade800;
  if (score == 4) return Colors.green.shade400;
  if (score == 3) return Colors.yellow.shade400;
  if (score == 2) return Colors.orange;
  if (score == 1) return Colors.red;
  return Colors.red.shade700;
}

String _rating(int? score, String? status) {
  if (score == null) {
    return status == 'not_applicable' ? 'Not applicable' : 'Unknown';
  }
  const ratings = ['Terrible', 'Bad', 'Poor', 'Medium', 'Good', 'Excellent'];
  return score >= 0 && score < ratings.length ? ratings[score] : 'Unknown';
}

String _coverage(dynamic value) => value is num && value.isFinite
    ? '${value.toStringAsFixed(1)}%'
    : 'Not applicable / unavailable';

bool _validBarcode(String value) =>
    RegExp(r'^(?:[0-9]{8}|[0-9]{12}|[0-9]{13}|[0-9]{14})$').hasMatch(value);

class ProductInformation extends StatefulWidget {
  const ProductInformation({
    super.key,
    this.barcodeNumber,
    this.companyName,
    this.productName,
    this.api = const ScoreApi(_miruApiBaseUrl),
  });

  final String? barcodeNumber;
  final String? companyName;
  final String? productName;
  final ScoreApi api;

  @override
  State<ProductInformation> createState() => _ProductInformationState();
}

class ProductInfo extends StatelessWidget {
  const ProductInfo({
    super.key,
    this.barcodeNumber,
    this.companyName,
    this.productName,
    this.api = const ScoreApi(_miruApiBaseUrl),
  });

  final String? barcodeNumber;
  final String? companyName;
  final String? productName;
  final ScoreApi api;

  @override
  Widget build(BuildContext context) => ProductInformation(
        barcodeNumber: barcodeNumber,
        companyName: companyName,
        productName: productName,
        api: api,
      );
}

class _ProductInformationState extends State<ProductInformation> {
  final _scrollController = ScrollController(keepScrollOffset: false);
  String _barcodeNumber = '';
  String _companyName = '';
  String _productName = '';
  String? _detectedAnimalRubric;
  Map<String, dynamic>? _result;
  String _status = 'Return to Scan to scan a barcode or enter product details.';
  String? _error;
  String? _historyError;
  String? _jobId;
  bool _busy = false;
  bool _completionAccepted = false;

  int _generation = 0;

  bool get _hasNames => _companyName.isNotEmpty && _productName.isNotEmpty;
  bool _stopped(int generation) => !mounted || generation != _generation;

  @override
  void initState() {
    super.initState();
    _prepareRequest(
      barcodeNumber: widget.barcodeNumber,
      companyName: widget.companyName,
      productName: widget.productName,
    );
  }

  @override
  void didUpdateWidget(covariant ProductInformation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barcodeNumber != widget.barcodeNumber ||
        oldWidget.companyName != widget.companyName ||
        oldWidget.productName != widget.productName ||
        oldWidget.api != widget.api) {
      _prepareRequest(
        barcodeNumber: widget.barcodeNumber,
        companyName: widget.companyName,
        productName: widget.productName,
      );
    }
  }

  @override
  void dispose() {
    _generation++;
    _scrollController.dispose();
    super.dispose();
  }

  void _prepareRequest({
    String? barcodeNumber,
    String? companyName,
    String? productName,
  }) {
    final generation = ++_generation;
    _barcodeNumber = barcodeNumber?.trim() ?? '';
    _companyName = _barcodeNumber.isEmpty ? companyName?.trim() ?? '' : '';
    _productName = _barcodeNumber.isEmpty ? productName?.trim() ?? '' : '';
    _detectedAnimalRubric = null;
    _result = null;
    _jobId = null;
    _error = null;
    _historyError = null;
    _busy = false;
    _completionAccepted = false;

    if (_barcodeNumber.isNotEmpty) {
      if (_validBarcode(_barcodeNumber)) {
        _busy = true;
        _status = 'Looking up product…';
      } else {
        _status = 'Check the barcode number.';
        _error = 'Return to Scan and rescan an 8, 12, 13, or 14 digit barcode.';
      }
    } else if (_hasNames) {
      _busy = true;
      _status = 'Starting research…';
    } else if (_companyName.isNotEmpty || _productName.isNotEmpty) {
      _status = 'Product details are incomplete.';
      _error = 'Return to Scan and enter both a product name and a company name.';
    } else {
      _status = 'Return to Scan to scan a barcode or enter product details.';
    }

    final shouldStart = _busy;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_stopped(generation)) return;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      scoreBarcode = _barcodeNumber.isEmpty ? null : _barcodeNumber;
      scoreResult.value = null;
      if (shouldStart) unawaited(_runRequest(generation));
    });
  }

  void _fillProduct(Map details, {bool keepExistingNames = false}) {
    final company = details['company_name']?.toString().trim() ?? '';
    final product = details['product_name']?.toString().trim() ?? '';
    if (!keepExistingNames || company.isNotEmpty) _companyName = company;
    if (!keepExistingNames || product.isNotEmpty) _productName = product;

    final rubric = details['animal_rubric_type'];
    if (rubric == 'animal_products' || rubric == 'non_animal_products') {
      _detectedAnimalRubric = rubric.toString();
    } else if (!keepExistingNames) {
      _detectedAnimalRubric = null;
    }
  }

  Future<void> _runRequest(int generation, {bool resume = false}) async {
    if (_stopped(generation)) return;
    final api = widget.api;
    bool stopped() => _stopped(generation);
    var lookingUp = false;
    var jobFailed = false;

    void statusChanged(String status) {
      if (stopped()) return;
      if (status == 'failed') jobFailed = true;
      const labels = {
        'submitting': 'Starting research…',
        'queued': 'Waiting to start research…',
        'running': 'Researching scores…',
        'completed': 'Finishing results…',
        'failed': 'Scoring failed.',
      };
      setState(() => _status = labels[status] ?? status);
    }

    try {
      final Map<String, dynamic> result;
      if (resume) {
        final jobId = _jobId;
        if (jobId == null) return;
        result = await api.waitForScoreJob(
          jobId,
          onStatus: statusChanged,
          shouldStop: stopped,
        );
      } else {
        if (_barcodeNumber.isNotEmpty) {
          lookingUp = true;
          final details = await api.lookupBarcode(_barcodeNumber);
          if (stopped()) return;
          setState(() => _fillProduct(details));

          if (!_hasNames) {
            setState(() {
              _status = 'Product details are incomplete.';
              _error = 'The barcode lookup did not return both names. '
                  'Return to Scan to enter or correct the details.';
            });
            return;
          }
          lookingUp = false;
        }

        if (!_hasNames) {
          setState(() {
            _status = 'Product details are incomplete.';
            _error = 'Return to Scan and enter both a product name and a company name.';
          });
          return;
        }

        setState(() => _status = 'Starting research…');
        result = await api.getScore(
          productName: _productName,
          companyName: _companyName,
          animalRubricType: _detectedAnimalRubric,
          onStatus: statusChanged,
          shouldStop: stopped,
          onJobStarted: (id) {
            if (!stopped()) setState(() => _jobId = id);
          },
        );
      }

      if (stopped() || _completionAccepted) return;
      _completionAccepted = true;
      final completed = Map<String, dynamic>.unmodifiable(result);
      setState(() {
        _fillProduct(completed, keepExistingNames: true);
        _status = 'Finishing results…';
        _jobId = null;
      });
      final completedCompany = _companyName;
      final completedBarcode = _barcodeNumber;
      String? progressError;
      final hasScores = !const ['unknown', 'failed', 'error']
              .contains(completed['data_status']) &&
          _dimensions.any((dimension) {
            final data = _map(completed[dimension]);
            return data['status'] != 'unknown' &&
                data['status'] != 'not_applicable' &&
                _number(data['score'], 10) != null;
          });
      if (completedBarcode.isNotEmpty && hasScores) {
        try {
          await _saveBarcodeReward();
        } catch (error) {
          debugPrint('Could not save earned scan progress: $error');
          progressError = 'Scores loaded, but earned progress could not be '
              'saved on this device.';
        }
      }
      unawaited(_saveHistory(completed, completedCompany, generation));
      if (stopped()) return;
      setState(() {
        _result = completed;
        _status = 'Completed';
        _historyError = progressError;
      });
      scoreBarcode = completedBarcode.isEmpty ? null : completedBarcode;
      scoreResult.value = completed;
    } catch (error) {
      if (stopped()) return;
      setState(() {
        _error = error.toString();
        if (lookingUp) {
          if (error is ScoreApiException && error.detail is Map) {
            _fillProduct(error.detail as Map);
          }
          _jobId = null;
          if (error is ScoreApiException && error.statusCode == 429) {
            _status = 'Barcode lookup limit reached. '
                'Return to Scan and enter the product and company manually to continue.';
          } else if (error is ScoreApiException && error.statusCode == 404) {
            _status = 'This barcode is not in the product database. '
                'Return to Scan and enter the product and company manually.';
          } else if (error is ScoreApiException && error.statusCode == 422) {
            _status = 'Product details are incomplete. '
                'Return to Scan to fill in the missing name.';
          } else {
            _status = 'Could not look up the barcode. '
                'Return to Scan to enter the details manually.';
          }
        } else if (jobFailed ||
            (error is ScoreApiException && error.statusCode == 404)) {
          _jobId = null;
          _status = 'Research could not finish. Please try again.';
        } else if (_jobId != null) {
          _status = 'Stopped waiting. You can resume this research.';
        } else {
          _status = 'Could not start research. Please try again.';
        }
      });
    } finally {
      if (!stopped()) setState(() => _busy = false);
    }
  }

  Future<void> _saveBarcodeReward() async {
    final preferences = await SharedPreferences.getInstance();
    final storedTokens = preferences.get('tokenValue');
    final storedScans = preferences.get('scannedNumber');
    final tokens = storedTokens is int && storedTokens >= 0 ? storedTokens : 0;
    final scans = storedScans is int && storedScans >= 0 ? storedScans : 0;
    final saved = await Future.wait([
      preferences.setInt('tokenValue', tokens + 1),
      preferences.setInt('scannedNumber', scans + 1),
    ]);
    if (saved.any((value) => !value)) {
      throw StateError('Could not save the token and completed scan count.');
    }
  }

  Future<void> _saveHistory(
      Map<String, dynamic> result, String company, int generation) async {
    try {
      await saveScanToHistory(
        companyName: company,
        animalScore: _number(_map(result['animal_welfare'])['score'], 10),
        peopleScore: _number(_map(result['ethical_labor'])['score'], 10),
        environmentScore: _number(_map(result['sustainability'])['score'], 10),
      );
    } catch (error) {
      debugPrint('Could not save scan history: $error');
      if (!_stopped(generation)) {
        setState(() {
          const message = 'Scores loaded, but this scan could not be saved '
              'to History on this device.';
          _historyError = _historyError == null
              ? message
              : '$_historyError\n$message';
        });
      }
    }
  }

  void _stopWaiting() {
    if (!_busy || _jobId == null) return;
    _generation++;
    setState(() {
      _busy = false;
      _status = _jobId == null
          ? 'Stopped waiting. Research may still be running.'
          : 'Stopped waiting. You can resume this research.';
    });
  }

  void _resumeWaiting() {
    if (_busy || _jobId == null) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Resuming…';
    });
    unawaited(_runRequest(generation, resume: true));
  }

  void _retry() {
    if (_busy) return;
    setState(() => _prepareRequest(
          barcodeNumber: _barcodeNumber,
          companyName: _companyName,
          productName: _productName,
        ));
  }

  Widget _header(BuildContext context) {
    final names = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _companyName.isEmpty
              ? (_busy ? 'Finding your product…' : 'Product information')
              : _companyName,
          key: const Key('company-name'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (_productName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _productName,
            key: const Key('product-name'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ],
    );

    return LayoutBuilder(builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(17.5) / 17.5;
      final scoreWidth = 200.0 * (textScale > 1 ? textScale : 1);
      if (constraints.maxWidth >= 140 + scoreWidth) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: names),
            const SizedBox(width: 12),
            SizedBox(
              width: scoreWidth,
              child: _OverallScoreList(result: _result),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          names,
          const SizedBox(height: 12),
          _OverallScoreList(result: _result),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final loadingGreen = Colors.lightGreen.shade800;
    final actionStyle = OutlinedButton.styleFrom(
      foregroundColor: loadingGreen,
      side: BorderSide(color: loadingGreen),
    );
    final canResume = !_busy && _jobId != null && _result == null;
    final canRetry = !_busy &&
        _result == null &&
        _jobId == null &&
        ((_barcodeNumber.isNotEmpty && _validBarcode(_barcodeNumber)) ||
            (_barcodeNumber.isEmpty && _hasNames));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const Key('product-information-scroll'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_barcodeNumber.isNotEmpty) ...[
                    SelectableText('Barcode number: $_barcodeNumber'),
                    const SizedBox(height: 8),
                  ],
                  _header(context),
                  const SizedBox(height: 8),
                  if (canResume || canRetry) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (canResume)
                          OutlinedButton.icon(
                            key: const Key('resume-waiting'),
                            onPressed: _resumeWaiting,
                            icon: const Icon(CupertinoIcons.play),
                            label: const Text('Resume waiting'),
                            style: actionStyle,
                          ),
                        if (canRetry)
                          OutlinedButton.icon(
                            key: const Key('retry-scores'),
                            onPressed: _retry,
                            icon: const Icon(CupertinoIcons.refresh),
                            label: const Text('Try again'),
                            style: actionStyle,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_status.isNotEmpty)
                    Semantics(
                      liveRegion: true,
                      child: Text(_status, key: const Key('score-status')),
                    ),
                  if (_busy) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      key: const Key('score-loading'),
                      semanticsLabel: _status,
                      color: loadingGreen,
                      backgroundColor: Colors.lightGreen.shade100,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Research can take several minutes.'),
                        TextButton(
                          key: const Key('stop-waiting'),
                          onPressed: _jobId == null ? null : _stopWaiting,
                          child: const Text('Stop waiting'),
                        ),
                      ],
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      _error!,
                      key: const Key('score-error'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (_historyError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _historyError!,
                      key: const Key('history-save-error'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, constraints) {
                    final heading = Text('Product Scores',
                        style: Theme.of(context).textTheme.titleLarge);
                    final textScale = MediaQuery.textScalerOf(context).scale(22) / 22;
                    if (constraints.maxWidth >= 340 * (textScale > 1 ? textScale : 1)) {
                      return Row(
                        children: [
                          Expanded(child: heading),
                          const SizedBox(width: 8),
                          const MethodsButton(),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [heading, const MethodsButton()],
                    );
                  }),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            _ScoreDetails(result: _result),
          ],
        ),
      ),
    );
  }
}

class StyledSlider extends StatelessWidget {
  const StyledSlider({super.key, required this.max, required this.score});

  final double max;
  final int? score;

  @override
  Widget build(BuildContext context) {
    final color = _overallColor(score);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 12,
        thumbShape: SliderComponentShape.noThumb,
        disabledActiveTrackColor: color,
        disabledInactiveTrackColor: color.withAlpha(45),
      ),
      child: Slider(
        value: (score ?? 0).toDouble().clamp(0.0, max).toDouble(),
        min: 0,
        max: max,
        onChanged: null,
      ),
    );
  }
}

class _OverallScoreList extends StatelessWidget {
  const _OverallScoreList({required this.result});
  final Map<String, dynamic>? result;

  Widget _row(
      BuildContext context, String dimension, String label, IconData icon) {
    final data = _map(result?[dimension]);
    final score = _number(data['score'], 10);
    final notApplicable = data['status'] == 'not_applicable';
    final display = score != null ? '$score/10' : (notApplicable ? 'N/A' : '—');
    final description = score != null
        ? '$score out of 10'
        : (notApplicable ? 'Not applicable' : 'Not scored');
    final textScale = MediaQuery.textScalerOf(context).scale(17.5) / 17.5;
    final numberWidth = 45.0 * (textScale > 1 ? textScale : 1);
    final number = Text(
      display,
      key: Key('overall-$dimension'),
      textAlign: TextAlign.end,
      style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold),
    );
    return Semantics(
      label: '$label: $description',
      excludeSemantics: true,
      child: Tooltip(
        message: '$label: $description',
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < numberWidth + 80) {
            return Column(
              children: [
                Row(
                  children: [
                    Icon(icon, color: _overallColor(score)),
                    const SizedBox(width: 8),
                    Expanded(child: number),
                  ],
                ),
                StyledSlider(max: ten, score: score),
              ],
            );
          }
          return Row(
            children: [
              Icon(icon, color: _overallColor(score)),
              Expanded(child: StyledSlider(max: ten, score: score)),
              SizedBox(width: numberWidth, child: number),
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(context, 'animal_welfare', 'Animals', CupertinoIcons.paw_solid),
          _row(context, 'ethical_labor', 'People', CupertinoIcons.hand_raised_fill),
          _row(context, 'sustainability', 'Environment', CupertinoIcons.tree),
        ],
      );
}

class OverallScores extends StatelessWidget {
  const OverallScores({super.key});

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: scoreResult,
        builder: (context, result, child) => _OverallScoreList(result: result),
      );
}

const _dimensions = ['animal_welfare', 'ethical_labor', 'sustainability'];
const _dimensionNames = ['Animals', 'People', 'Environment'];
const _dimensionIcons = [
  CupertinoIcons.paw_solid,
  CupertinoIcons.hand_raised_fill,
  CupertinoIcons.tree,
];

class _ScoreDetails extends StatefulWidget {
  const _ScoreDetails({required this.result});
  final Map<String, dynamic>? result;

  @override
  State<_ScoreDetails> createState() => _ScoreDetailsState();
}

class _ScoreDetailsState extends State<_ScoreDetails> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 120) return;
          final next = (_selected + (velocity < 0 ? 1 : -1)).clamp(0, 2);
          if (next != _selected) setState(() => _selected = next.toInt());
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(builder: (context, constraints) {
              return AnimatedToggleSwitch<int>.size(
                textDirection: TextDirection.rtl,
                current: 2 - _selected,
                values: const [0, 1, 2],
                iconOpacity: 0.4,
                indicatorSize: Size.fromWidth((constraints.maxWidth - 8) / 3),
                iconBuilder: (value) => Semantics(
                  selected: _selected == 2 - value,
                  label: _dimensionNames[2 - value],
                  child: Tooltip(
                    message: _dimensionNames[2 - value],
                    child: Icon(
                      _dimensionIcons[2 - value],
                      key: Key('tab-$value'),
                      color: _selected == 2 - value
                          ? Colors.black87
                          : Colors.lightGreen.shade800,
                    ),
                  ),
                ),
                borderWidth: 4,
                animationDuration: const Duration(milliseconds: 200),
                style: ToggleStyle(
                  backgroundColor: Colors.lightGreen.shade100,
                  borderColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                styleBuilder: (value) => ToggleStyle(
                  indicatorColor: _overallColor(_number(
                    _map(widget.result?[_dimensions[2 - value]])['score'],
                    10,
                  )),
                ),
                onChanged: (value) => setState(() => _selected = 2 - value),
              );
            }),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _dimensionChildren(
                    context, widget.result, _dimensions[_selected]),
              ),
            ),
          ],
        ),
      );
}

List<Widget> _dimensionChildren(
    BuildContext context, Map<String, dynamic>? result, String dimension) {
  if (result == null) {
    return [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('Scores will appear after research completes.'),
      ),
    ];
  }

  final data = _map(result[dimension]);
  final evidence = _map(data['evidence']);
  final statuses = _map(data['category_status']);
  final coverage = _map(data['transparency_breakdown']);
  final categories = _categories(
    dimension,
    data,
    animalRubricType: result['animal_rubric_type']?.toString(),
  );
  final animalRubric = result['animal_rubric_type'] == 'animal_products'
      ? 'Animal products'
      : 'Non-animal products';

  return [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dimension == 'animal_welfare') Text('Rubric: $animalRubric'),
          Text('Evidence coverage: ${_coverage(data['transparency_score'])}'),
          if (data['reason'] != null) Text(data['reason'].toString()),
        ],
      ),
    ),
    if (categories.isEmpty) const Text('No category details were returned.'),
    for (final category in categories) ...[
      StoplightScoreTile(
        key: PageStorageKey<String>(
            '${result['company_name']}/${result['product_name']}/$dimension/$category'),
        icon: _categoryIcon(category),
        label: _label(category),
        score: _number(_map(data['breakdown'])[category], 5),
        status: statuses[category]?.toString(),
        coverage: coverage[category],
        reasoning: _map(evidence[category])['summary']?.toString() ??
            'Summary unavailable.',
        answers: (_map(evidence[category])['answers'] is List)
            ? (_map(evidence[category])['answers'] as List)
                .whereType<Map>()
                .map(_map)
                .toList()
            : const <Map<String, dynamic>>[],
      ),
      const Divider(height: 1),
    ],
  ];
}

class ToggleButton extends StatelessWidget {
  const ToggleButton({super.key});

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: scoreResult,
        builder: (context, result, child) => ListView(
          padding: EdgeInsets.zero,
          children: [_ScoreDetails(result: result)],
        ),
      );
}

class EnvironmentDisplayInfo extends StatelessWidget {
  const EnvironmentDisplayInfo({super.key});

  @override
  Widget build(BuildContext context) =>
      const _DimensionView(dimension: 'sustainability');
}

class AnimalDisplayInfo extends StatelessWidget {
  const AnimalDisplayInfo({super.key});

  @override
  Widget build(BuildContext context) =>
      const _DimensionView(dimension: 'animal_welfare');
}

class LaborDisplayInfo extends StatelessWidget {
  const LaborDisplayInfo({super.key});

  @override
  Widget build(BuildContext context) =>
      const _DimensionView(dimension: 'ethical_labor');
}

class _DimensionView extends StatelessWidget {
  const _DimensionView({required this.dimension});
  final String dimension;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: scoreResult,
        builder: (context, result, child) => ListView(
          padding: EdgeInsets.zero,
          children: _dimensionChildren(context, result, dimension),
        ),
      );
}

class StoplightScoreTile extends StatelessWidget {
  const StoplightScoreTile({
    super.key,
    required this.icon,
    required this.label,
    required this.reasoning,
    required this.score,
    this.status,
    this.coverage,
    this.answers = const [],
  });

  final IconData icon;
  final String label;
  final String reasoning;
  final int? score;
  final String? status;
  final dynamic coverage;
  final List<Map<String, dynamic>> answers;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(score);
    final rating = _rating(score, status);
    final sources = _categorySources(answers);
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: color,
      title: LayoutBuilder(builder: (context, constraints) {
        final fontSize = Theme.of(context).textTheme.titleMedium?.fontSize ?? 16;
        final textScale =
            MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;
        final scale = textScale > 1 ? textScale : 1.0;
        final ratingWidth = 85.0 * scale;
        final scoreDetails = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(score == null ? '—/5' : '$score/5',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(rating,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelSmall),
          ],
        );

        if (constraints.maxWidth < ratingWidth + 144 * scale) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(label),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: scoreDetails),
                        const SizedBox(width: 10),
                        Icon(Icons.circle, color: color, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            const SizedBox(width: 8),
            SizedBox(width: ratingWidth, child: scoreDetails),
            const SizedBox(width: 10),
            Icon(Icons.circle, color: color, size: 16),
          ],
        );
      }),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        SelectableText(
          reasoning.trim().isEmpty ? 'Summary unavailable.' : reasoning,
          key: const PageStorageKey<String>('summary-text'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Sources',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        if (sources.isEmpty) const Text('No sources were returned.'),
        for (var index = 0; index < sources.length; index++)
          _CategorySource(
            key: PageStorageKey<String>('category-source-$index'),
            source: sources[index],
          ),
      ],
    );
  }
}

List<Map<String, String>> _categorySources(
    List<Map<String, dynamic>> answers) {
  final sources = <String, Map<String, String>>{};
  for (final answer in answers) {
    final title = answer['source_title']?.toString().trim() ?? '';
    final url = answer['source_url']?.toString().trim() ?? '';
    if (title.isEmpty && url.isEmpty) continue;

    final identity = url.isNotEmpty ? 'url:$url' : 'title:$title';
    final existing = sources[identity];
    if (existing == null) {
      sources[identity] = {'title': title, 'url': url};
    } else if ((existing['title'] ?? '').isEmpty && title.isNotEmpty) {
      existing['title'] = title;
    }
  }
  return sources.values.toList(growable: false);
}

class _CategorySource extends StatelessWidget {
  const _CategorySource({super.key, required this.source});
  final Map<String, String> source;

  @override
  Widget build(BuildContext context) {
    final sourceTitle = source['title'] ?? '';
    final sourceUrl = source['url'] ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sourceTitle.isNotEmpty) Text(sourceTitle),
          if (sourceTitle.isNotEmpty && sourceUrl.isNotEmpty)
            const SizedBox(height: 4),
          if (sourceUrl.isNotEmpty)
            SelectableText(
              sourceUrl,
              key: const PageStorageKey<String>('source-url'),
            ),
        ],
      ),
    );
  }
}

class MethodsButton extends StatelessWidget {
  const MethodsButton({super.key});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        label: const Text('Scoring System'),
        icon: const Icon(CupertinoIcons.info),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Scoring Criteria & Methods'),
            content: const SingleChildScrollView(
              child: SelectableText(
                'AI researches public evidence and answers our yes-no rubric questions. The backend calculates scores using the different weights for each question and their respective categories.\n\nOverall scores range from 0 to 10. Individual categories range from 0 to 5. Higher scores indicate better assessed performance.\n\nUnknown answers reduce evidence coverage and are excluded from performance. Questions established as not applicable are excluded from both. Transparency also counts as a weighted rubric category where specified. \n\nWe have interviewed environmental experts, PETA, and the Fair Labor Association to refine our rubric. They are not affiliated with MIRU. \n\nFor questions or access to our full rubric: miru.ethical.scanner@gmail.com.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );
}

