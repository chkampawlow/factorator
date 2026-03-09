import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://192.168.1.155/facturation_api";

  void _log(String message) {
    debugPrint("[ApiService] $message");
  }

  Future<Map<String, dynamic>> addClient({
    required String type,
    required String name,
    String? email,
    String? phone,
    String? address,
    String? fiscalId,
    String? cin,
  }) async {
    final uri = Uri.parse("$baseUrl/add_client.php");

    final payload = {
      "type": type,
      "name": name,
      "email": email,
      "phone": phone,
      "address": address,
      "fiscalId": fiscalId,
      "cin": cin,
    };

    final headers = const {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };

    _log("---- addClient START ----");
    _log("URL      => $uri");
    _log("METHOD   => POST");
    _log("HEADERS  => $headers");
    _log("PAYLOAD  => ${jsonEncode(payload)}");

    try {
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      _log("RESPONSE STATUS => ${response.statusCode}");
      _log("RESPONSE BODY   => ${response.body}");
      _log("RESPONSE HEADERS=> ${response.headers}");

      if (response.body.isEmpty) {
        _log("ERROR => Empty response from server");
        throw Exception("Empty response from server");
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
        _log("DECODED JSON    => $decoded");
      } catch (e, st) {
        _log("JSON DECODE ERROR => $e");
        _log("STACKTRACE => $st");
        throw Exception("Invalid JSON from server: $e");
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          _log("SUCCESS => addClient completed");
          _log("---- addClient END ----");
          return decoded;
        }

        _log("ERROR => JSON is not a Map<String, dynamic>");
        throw Exception("Invalid JSON format from server");
      } else {
        final msg = decoded is Map<String, dynamic>
            ? (decoded["message"] ?? "Server error")
            : "Server error";

        _log("HTTP ERROR => ${response.statusCode}: $msg");
        throw Exception("HTTP ${response.statusCode}: $msg");
      }
    } on SocketException catch (e, st) {
      _log("SOCKET ERROR => $e");
      _log("STACKTRACE   => $st");
      throw Exception("Network error: $e");
    } on TimeoutException catch (e, st) {
      _log("TIMEOUT ERROR => $e");
      _log("STACKTRACE    => $st");
      throw Exception("Request timeout");
    } on HandshakeException catch (e, st) {
      _log("HANDSHAKE ERROR => $e");
      _log("STACKTRACE      => $st");
      throw Exception("SSL/Handshake error: $e");
    } on HttpException catch (e, st) {
      _log("HTTP EXCEPTION => $e");
      _log("STACKTRACE     => $st");
      throw Exception("HTTP exception: $e");
    } on FormatException catch (e, st) {
      _log("FORMAT ERROR => $e");
      _log("STACKTRACE   => $st");
      throw Exception("Invalid JSON from server: $e");
    } catch (e, st) {
      _log("UNEXPECTED ERROR => $e");
      _log("STACKTRACE       => $st");
      throw Exception("Unexpected error: $e");
    }
  }
  Future<Map<String, dynamic>> addErpInvoice({
  required String invoice,
  String? customEmail,
  String? customCode,
  required String invoiceDate,
  required String invoiceDueDate,
  required double subtotal,
  double? montantTva,
  required double subtotalTtc,
  double? shipping,
  double? discount,
  double? vat,
  required double total,
  required String notes,
  required String invoiceType,
  String? status,
  String? typeDoc,
  double? timbre,
  double? txRetenue,
  double? retenue,
  double? netRetenue,
  int? idExtract,
  int? idLettrage,
  String? contratNo,
  dynamic jsonFinsys,
  dynamic jsonReturn,
  dynamic jsonReturn2,
  int? statApi,
  String? mntLettre,
  String? statTtn,
  String? qrCode,
  String? uuid,
}) async {
  final uri = Uri.parse("$baseUrl/add_erp_invoice.php");

  final payload = {
    "invoice": invoice,
    "custom_email": customEmail,
    "custom_code": customCode,
    "invoice_date": invoiceDate,
    "invoice_due_date": invoiceDueDate,
    "subtotal": subtotal,
    "montant_tva": montantTva,
    "subtotal_ttc": subtotalTtc,
    "shipping": shipping ?? 0.000,
    "discount": discount ?? 0.000,
    "vat": vat ?? 0.000,
    "total": total,
    "notes": notes,
    "invoice_type": invoiceType,
    "status": status ?? "open",
    "type_doc": typeDoc,
    "timbre": timbre,
    "tx_retenue": txRetenue,
    "retenue": retenue,
    "net_retenue": netRetenue,
    "id_extract": idExtract,
    "id_lettrage": idLettrage,
    "contrat_no": contratNo,
    "json_finsys": jsonFinsys,
    "json_return": jsonReturn,
    "json_return2": jsonReturn2,
    "stat_api": statApi,
    "mnt_lettre": mntLettre,
    "stat_ttn": statTtn,
    "qr_code": qrCode,
    "uuid": uuid,
  };

  final response = await http.post(
    uri,
    headers: const {
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: jsonEncode(payload),
  );

  if (response.body.isEmpty) {
    throw Exception("Empty response from server");
  }

  final decoded = jsonDecode(response.body);

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return decoded;
  } else {
    throw Exception(decoded["message"] ?? "Server error");
  }
}
Future<Map<String, dynamic>> addErpInvoiceItems({
  required int invoiceId,
  required String invoice,
  required String invoiceDate,
  required List<Map<String, dynamic>> items,
}) async {
  final uri = Uri.parse("$baseUrl/add_erp_invoice_items.php");

  final payload = {
    "invoice_id": invoiceId,
    "invoice": invoice,
    "invoice_date": invoiceDate,
    "items": items,
  };

  final response = await http.post(
    uri,
    headers: const {
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: jsonEncode(payload),
  );

  if (response.body.isEmpty) {
    throw Exception("Empty response from server");
  }

  final decoded = jsonDecode(response.body);

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return decoded;
  } else {
    throw Exception(decoded["message"] ?? "Server error");
  }
}
}