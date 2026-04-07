
import 'package:cross_file/cross_file.dart';
import 'package:planmapp/features/expenses/services/receipt_scanner_service.dart'; // For ParsedReceipt models

abstract class ReceiptScannerPlatform {
  Future<ParsedReceipt> scanReceipt(XFile imageFile);
  void dispose();
}
