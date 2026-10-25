import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://miru-api-822959759707.us-central1.run.app',
);

typedef ScoreStatusCallback = void Function(String status);

class ScoreApiException implements Exception {
  const ScoreApiException(this.message, {this.statusCode, this.detail});
  final String message;
  final int? statusCode;
  final dynamic detail;

  @override
  String toString() => message;
}

class ScoreApi {
  const ScoreApi(this.baseUrl, {http.Client? client, http.Client? barcodeClient})
      : _client = client, _barcodeClient = barcodeClient;
  final String baseUrl;
  final http.Client? _client;
  final http.Client? _barcodeClient;

  static final _barcodeCache = <String, _BarcodeLookupCacheEntry>{};
  static final _pendingBarcodeLookups =
      <String, Future<Map<String, dynamic>>>{};
  static final _barcodeRetryAfter = <String, DateTime>{};
  static final _barcodeRetryDetails = <String, dynamic>{};
  static Future<void>? _deviceLookupQueue;
  static const _barcodeCacheLifetime = Duration(hours: 24);
  static const _maximumCachedBarcodes = 128;

  String get _base => baseUrl.replaceFirst(RegExp(r'/+$'), '');

  Future<void> checkHealth() async {
    final data = await _request('GET', '/health');
    if (data['status'] != 'ok') {
      throw const ScoreApiException('The server did not report a healthy status.');
    }
  }

  Future<Map<String, dynamic>> lookupBarcode(String barcodeNumber) async {
    final barcode = barcodeNumber.trim();
    if (!_isBarcode(barcode)) {
      throw const ScoreApiException(
        'Enter an 8, 12, 13, or 14 digit barcode.',
        statusCode: 400,
      );
    }
    final route = kIsWeb ? 'backend' : 'device';
    final key = '$_base\n$route\n' + barcode.padLeft(14, '0');
    final cached = _barcodeCache[key];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return _completeBarcodeDetails(cached.details);
    }
    _barcodeCache.remove(key);

    final pending = _pendingBarcodeLookups[key] ??=
        _lookupAndCacheBarcode(key, barcode);
    try {
      return _completeBarcodeDetails(await pending);
    } finally {
      if (identical(_pendingBarcodeLookups[key], pending)) {
        _pendingBarcodeLookups.remove(key);
      }
    }
  }

  Future<Map<String, dynamic>> _lookupAndCacheBarcode(
    String key,
    String barcode,
  ) async {
    Map<String, dynamic> details;
    try {
      details = kIsWeb
          ? await _request('POST', '/barcode-lookup', body: {
              'barcode_number': barcode,
            })
          : await _queuedDeviceLookup(barcode);
    } on ScoreApiException catch (error) {
      if (error.statusCode != 422 || error.detail is! Map) rethrow;
      details = Map<String, dynamic>.from(error.detail as Map);
    }
    final now = DateTime.now();
    _barcodeCache.removeWhere((_, entry) => !now.isBefore(entry.expiresAt));
    if (_barcodeCache.length >= _maximumCachedBarcodes) {
      _barcodeCache.remove(_barcodeCache.keys.first);
    }
    _barcodeCache[key] = _BarcodeLookupCacheEntry(
      Map<String, dynamic>.unmodifiable(details),
      now.add(_barcodeCacheLifetime),
    );
    return details;
  }

  Map<String, dynamic> _completeBarcodeDetails(Map<String, dynamic> details) {
    if (_text(details['product_name']).isEmpty ||
        _text(details['company_name']).isEmpty) {
      throw ScoreApiException(
        'UPCitemdb found incomplete product details. Enter the missing names manually.',
        statusCode: 422,
        detail: {
          'message': 'Enter the missing product or company name.',
          ...details,
        },
      );
    }
    return Map<String, dynamic>.from(details);
  }

  Future<Map<String, dynamic>> _queuedDeviceLookup(String barcode) async {
    // The free provider allows one connection, even for different barcodes.
    final previous = _deviceLookupQueue;
    final finished = Completer<void>();
    _deviceLookupQueue = finished.future;
    try {
      if (previous != null) await previous;
      return await _lookupFromDevice(barcode);
    } finally {
      finished.complete();
      if (identical(_deviceLookupQueue, finished.future)) {
        _deviceLookupQueue = null;
      }
    }
  }

  Future<Map<String, dynamic>> _lookupFromDevice(String barcode) async {
    final providerKey = '$_base:upcitemdb-device';
    final pausedUntil = _barcodeRetryAfter[providerKey];
    if (pausedUntil != null && DateTime.now().isBefore(pausedUntil)) {
      throw _barcodeLimitException(
        pausedUntil, detail: _barcodeRetryDetails[providerKey],
      );
    }
    _barcodeRetryAfter.remove(providerKey);
    _barcodeRetryDetails.remove(providerKey);

    final uri = Uri.https(
      'api.upcitemdb.com',
      '/prod/trial/lookup',
      {'upc': barcode},
    );
    http.Response response;
    final suppliedClient = _barcodeClient ?? _client;
    final client = suppliedClient ?? http.Client();
    try {
      final headers = {
        'Accept': 'application/json',
        'User-Agent': 'MIRU/0.8 (device barcode lookup)',
      };
      response = await client.get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ScoreApiException(
        'UPCitemdb did not respond within 15 seconds. Try later or enter details manually.',
        statusCode: 504,
      );
    } on http.ClientException {
      throw const ScoreApiException(
        'Could not connect to UPCitemdb from this device. Enter product details manually.',
        statusCode: 502,
      );
    } finally {
      if (suppliedClient == null) client.close();
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      // non-JSON
    }
    final code = decoded is Map ? decoded['code'] : null;
    if (response.statusCode == 429 ||
        code == 'EXCEED_LIMIT' ||
        code == 'TOO_FAST' ||
        code == 'HTTP_TOO_MANY_REQUESTS') {
      final detail = <String, dynamic>{
        'provider': 'upcitemdb',
        'message': code == 'EXCEED_LIMIT'
            ? 'UPCitemdb has reached its daily barcode lookup limit for this network.'
            : 'UPCitemdb has temporarily limited barcode lookups on this network.',
      };
      final retryAt = _barcodeRetryTime(response);
      _barcodeRetryAfter[providerKey] = retryAt;
      _barcodeRetryDetails[providerKey] = detail;
      throw _barcodeLimitException(retryAt, detail: detail);
    }
    if (response.statusCode == 404 && decoded is Map && code == 'NOT_FOUND') {
      throw const ScoreApiException(
        'UPCitemdb has no record for this barcode. Enter product details manually.',
        statusCode: 404,
      );
    }
    if (response.statusCode == 400) {
      throw const ScoreApiException(
        'UPCitemdb rejected this barcode. Check the number or enter details manually.',
        statusCode: 400,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ScoreApiException(
        'UPCitemdb returned HTTP ' + response.statusCode.toString() +
            '. Try later or enter details manually.',
        statusCode: 502,
      );
    }
    if (decoded is! Map) {
      throw const ScoreApiException(
        'UPCitemdb returned an unreadable response. Enter product details manually.',
        statusCode: 502,
      );
    }
    if (code == 'NOT_FOUND') {
      throw const ScoreApiException(
        'UPCitemdb has no record for this barcode. Enter product details manually.',
        statusCode: 404,
      );
    }
    final items = decoded['items'];
    if (code != 'OK' || items is! List) {
      throw const ScoreApiException(
        'UPCitemdb returned an unexpected response. Enter product details manually.',
        statusCode: 502,
      );
    }
    if (items.isEmpty) {
      throw const ScoreApiException(
        'UPCitemdb has no record for this barcode. Enter product details manually.',
        statusCode: 404,
      );
    }

    final matches = items.whereType<Map>().where((item) {
      return ['ean', 'upc', 'gtin'].any((field) {
        final value = item[field];
        return value is String &&
            _isBarcode(value) &&
            value.padLeft(14, '0') == barcode.padLeft(14, '0');
      });
    }).toList();
    if (matches.isEmpty) {
      throw const ScoreApiException(
        'UPCitemdb returned a different barcode. Enter product details manually.',
        statusCode: 409,
      );
    }
    final product = matches.firstWhere(
      (item) => _text(item['title']).isNotEmpty && _text(item['brand']).isNotEmpty,
      orElse: () => matches.first,
    );
    final productName = _text(product['title']);
    final companyName = _companyAlias(_text(product['brand']));
    final details = <String, dynamic>{
      'product_name': productName.isEmpty ? null : productName,
      'company_name': companyName.isEmpty ? null : companyName,
      'animal_rubric_type': null,
    };
    return details;
  }

  static String _text(dynamic value) => value is String ? value.trim() : '';

  static bool _isBarcode(String value) => RegExp(
    r'^(?:[0-9]{8}|[0-9]{12}|[0-9]{13}|[0-9]{14})$',
  ).hasMatch(value);

  static String _companyAlias(String value) {
    const aliases = {
      'gap': 'The Gap, Inc.',
      'the gap': 'The Gap, Inc.',
      'gap inc': 'The Gap, Inc.',
      'gap inc.': 'The Gap, Inc.',
    };
    return aliases[value.toLowerCase()] ?? value;
  }

  DateTime _barcodeRetryTime(http.Response response, {dynamic detail}) {
    String? header(String name) {
      for (final entry in response.headers.entries) {
        if (entry.key.toLowerCase() == name) return entry.value;
      }
      return null;
    }

    double? seconds(dynamic value) {
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
    }

    var wait = seconds(header('retry-after'));
    if (wait == null && detail is Map) {
      wait = seconds(detail['retry_after_seconds']);
    }
    if (wait == null) {
      final reset = seconds(header('x-ratelimit-reset'));
      if (reset != null) {
        final remaining =
            reset - DateTime.now().millisecondsSinceEpoch / 1000;
        if (remaining >= 0) wait = remaining;
      }
    }
    final wholeSeconds = (wait ?? 60).clamp(1, 2147483647).ceil();
    return DateTime.now().add(Duration(seconds: wholeSeconds));
  }


  Future<Map<String, dynamic>> getScore({
    required String productName,
    required String companyName,
    String? animalRubricType,
    ScoreStatusCallback? onStatus,
    void Function(String jobId)? onJobStarted,
    bool Function()? shouldStop,
  }) {
    return _startAndWait('/score-jobs', {
      'product_name': productName.trim(),
      'company_name': companyName.trim(),
      if (animalRubricType != null) 'animal_rubric_type': animalRubricType,
    }, onStatus: onStatus, onJobStarted: onJobStarted, shouldStop: shouldStop);
  }

  Future<Map<String, dynamic>> getScoreFromBarcode({
    required String barcodeNumber,
    String? productName,
    String? companyName,
    String? animalRubricType,
    ScoreStatusCallback? onStatus,
    void Function(String jobId)? onJobStarted,
    bool Function()? shouldStop,
  }) async {
    if (kIsWeb) {
      return _startAndWait('/barcode-score-jobs', {
        'barcode_number': barcodeNumber.trim(),
        if (productName != null) 'product_name': productName.trim(),
        if (companyName != null) 'company_name': companyName.trim(),
        if (animalRubricType != null) 'animal_rubric_type': animalRubricType,
      }, onStatus: onStatus, onJobStarted: onJobStarted, shouldStop: shouldStop);
    }

    _checkStopped(shouldStop);
    onStatus?.call('looking_up');
    Map<String, dynamic> details;
    try {
      details = await lookupBarcode(barcodeNumber);
    } on ScoreApiException catch (error) {
      if (error.statusCode != 422 || error.detail is! Map) rethrow;
      details = Map<String, dynamic>.from(error.detail as Map);
    }
    _checkStopped(shouldStop);
    final resolvedProduct = _text(productName).isNotEmpty
        ? productName!.trim() : _text(details['product_name']);
    final resolvedCompany = _text(companyName).isNotEmpty
        ? _companyAlias(companyName!.trim()) : _text(details['company_name']);
    if (resolvedProduct.isEmpty || resolvedCompany.isEmpty) {
      throw ScoreApiException(
        'Enter both the product and company name to get scores.',
        statusCode: 422,
        detail: details,
      );
    }
    return getScore(
      productName: resolvedProduct,
      companyName: resolvedCompany,
      animalRubricType: animalRubricType,
      onStatus: onStatus,
      onJobStarted: onJobStarted,
      shouldStop: shouldStop,
    );
  }


  Future<Map<String, dynamic>> _startAndWait(
    String path,
    Map<String, dynamic> body, {
    ScoreStatusCallback? onStatus,
    void Function(String jobId)? onJobStarted,
    bool Function()? shouldStop,
  }) async {
    _checkStopped(shouldStop);
    onStatus?.call('submitting');
    final started = await _request('POST', path, body: body);
    final jobId = started['job_id'];
    if (jobId is! String || jobId.isEmpty) {
      throw const ScoreApiException('The backend did not return a job ID.');
    }
    onJobStarted?.call(jobId);
    return waitForScoreJob(
      jobId,
      onStatus: onStatus,
      shouldStop: shouldStop,
    );
  }

  Future<Map<String, dynamic>> waitForScoreJob(
    String jobId, {
    ScoreStatusCallback? onStatus,
    bool Function()? shouldStop,
  }) async {
    final deadline = DateTime.now().add(const Duration(minutes: 30));
    while (DateTime.now().isBefore(deadline)) {
      _checkStopped(shouldStop);
      final job = await _request(
        'GET', '/score-jobs/${Uri.encodeComponent(jobId)}',
      );
      _checkStopped(shouldStop);
      final status = job['status']?.toString() ?? 'unknown';
      onStatus?.call(status);
      if (status == 'completed') {
        final result = job['result'];
        if (result is Map) return Map<String, dynamic>.from(result);
        throw const ScoreApiException('The completed job has no result.');
      }
      if (status == 'failed') {
        throw ScoreApiException(job['error']?.toString() ?? 'Scoring failed.');
      }
      if (status != 'queued' && status != 'running') {
        throw ScoreApiException('Unexpected job status: $status');
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    throw const ScoreApiException(
      'Still running after 30 minutes. Use Resume waiting to check this job again.',
    );
  }

  void _checkStopped(bool Function()? shouldStop) {
    if (shouldStop?.call() ?? false) {
      throw const ScoreApiException(
        'Stopped waiting. The backend job may still be running.',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final isBarcodeLookup =
        path == '/barcode-lookup' || path == '/barcode-score-jobs';
    if (isBarcodeLookup) {
      final retryAt = _barcodeRetryAfter[_base];
      if (retryAt != null && DateTime.now().isBefore(retryAt)) {
        throw _barcodeLimitException(
          retryAt, detail: _barcodeRetryDetails[_base],
        );
      }
      _barcodeRetryAfter.remove(_base);
      _barcodeRetryDetails.remove(_base);
    }

    http.Response response;
    try {
      final uri = Uri.parse('$_base$path');
      final client = _client;
      final future = method == 'POST'
          ? (client == null
              ? http.post(uri, headers: _jsonHeaders, body: jsonEncode(body))
              : client.post(uri, headers: _jsonHeaders, body: jsonEncode(body)))
          : (client == null
              ? http.get(uri, headers: {'Accept': 'application/json'})
              : client.get(uri, headers: {'Accept': 'application/json'}));
      response = await future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ScoreApiException('The server did not respond within 30 seconds.');
    } on http.ClientException catch (error) {
      throw ScoreApiException('Could not connect to $_base: ${error.message}');
    }

    if (isBarcodeLookup && response.statusCode == 429) {
      dynamic detail;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        detail = decoded is Map ? decoded['detail'] : decoded;
      } on FormatException {
        // Even a non-JSON 429 must pause subsequent barcode requests.
      }
      final retryAt = _barcodeRetryTime(response, detail: detail);
      _barcodeRetryAfter[_base] = retryAt;
      _barcodeRetryDetails[_base] = detail;
      throw _barcodeLimitException(retryAt, detail: detail);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ScoreApiException(
        'Server returned HTTP ${response.statusCode} without valid JSON.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : decoded;
      final message = detail is Map ? detail['message'] : detail;
      throw ScoreApiException(
        'HTTP ${response.statusCode}: ${message ?? 'Backend request failed.'}',
        statusCode: response.statusCode,
        detail: detail,
      );
    }
    if (decoded is! Map) {
      throw const ScoreApiException('The server returned an unexpected response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static const _jsonHeaders = {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };

  ScoreApiException _barcodeLimitException(DateTime retryAt, {dynamic detail}) {
    final remaining =
        (retryAt.difference(DateTime.now()).inMilliseconds / 1000).ceil();
    final seconds = remaining > 0 ? remaining : 1;
    final supplied = detail is Map ? detail['message'] : detail;
    final reason = supplied is String && supplied.trim().isNotEmpty
        ? supplied.trim()
        : 'The barcode lookup service has reached a request limit.';
    return ScoreApiException(
      '$reason Wait at least $seconds seconds before trying again, or enter '
      'the product and company manually. A daily limit may last longer.',
      statusCode: 429,
      detail: {
        if (detail is Map) ...Map<String, dynamic>.from(detail),
        'message': reason,
        'retry_after_seconds': seconds,
      },
    );
  }
}


class _BarcodeLookupCacheEntry {
  const _BarcodeLookupCacheEntry(this.details, this.expiresAt);
  final Map<String, dynamic> details;
  final DateTime expiresAt;
}