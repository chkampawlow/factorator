import 'dart:io';

import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';
import 'package:my_app/core/api_exception.dart';
import 'package:my_app/core/extraction_models.dart';
import 'package:path/path.dart' as path;

class ExtractorService {
  ExtractorService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static const int maxFiles = 10;
  static const int maxFileBytes = 15 * 1024 * 1024;
  static const int maxBatchBytes = 50 * 1024 * 1024;
  static const Set<String> allowedExtensions = {
    '.pdf',
    '.png',
    '.jpg',
    '.jpeg',
    '.tif',
    '.tiff',
    '.bmp',
    '.webp',
  };

  final ApiClient _api;

  Future<ExtractionBatch> extractFiles(
    List<String> filePaths, {
    void Function(double progress)? onProgress,
  }) async {
    final paths = filePaths
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (paths.isEmpty) {
      throw const ApiException(
        message: 'Choose at least one PDF or image.',
        statusCode: 0,
        code: 'EXTRACTOR_NO_FILES',
      );
    }
    if (paths.length > maxFiles) {
      throw const ApiException(
        message: 'A maximum of 10 files is allowed per extraction.',
        statusCode: 0,
        code: 'EXTRACTOR_TOO_MANY_FILES',
      );
    }

    var batchBytes = 0;
    final sourcePaths = <String, String>{};
    for (final filePath in paths) {
      final extension = path.extension(filePath).toLowerCase();
      if (!allowedExtensions.contains(extension)) {
        throw ApiException(
          message: 'Unsupported file type: ${path.basename(filePath)}',
          statusCode: 0,
          code: 'EXTRACTOR_UNSUPPORTED_FILE',
        );
      }
      final file = File(filePath);
      if (!await file.exists()) {
        throw ApiException(
          message: 'File is no longer available: ${path.basename(filePath)}',
          statusCode: 0,
          code: 'EXTRACTOR_FILE_MISSING',
        );
      }
      final size = await file.length();
      if (size > maxFileBytes) {
        throw ApiException(
          message: '${path.basename(filePath)} exceeds the 15 MB limit.',
          statusCode: 0,
          code: 'EXTRACTOR_FILE_TOO_LARGE',
        );
      }
      batchBytes += size;
      sourcePaths[path.basename(filePath)] = filePath;
    }
    if (batchBytes > maxBatchBytes) {
      throw const ApiException(
        message: 'The selected files exceed the 50 MB batch limit.',
        statusCode: 0,
        code: 'EXTRACTOR_BATCH_TOO_LARGE',
      );
    }

    final raw = await _api.multipartPostFiles(
      ApiConfig.extractorRun,
      fileField: 'invoice_files[]',
      filePaths: paths,
      fields: const {'source': 'upload'},
      authRequired: true,
      onProgress: (sent, total) {
        if (total <= 0) return;
        onProgress?.call((sent / total).clamp(0, 1));
      },
    );
    if (raw is! Map) {
      throw const ApiException(
        message: 'The extractor returned an invalid response.',
        statusCode: 0,
        code: 'EXTRACTOR_INVALID_RESPONSE',
      );
    }
    final response = Map<String, dynamic>.from(raw);
    if (response['success'] != true) {
      throw ApiException(
        message: '${response['message'] ?? 'Extraction failed.'}',
        statusCode: 0,
        code: '${response['error_code'] ?? 'EXTRACTOR_FAILED'}',
      );
    }
    return ExtractionBatch.fromJson(response, sourcePaths: sourcePaths);
  }
}
