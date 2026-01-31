
import 'package:cross_file/cross_file.dart';
import 'scanner/receipt_scanner_interface.dart';
import 'scanner/receipt_scanner_mobile.dart' if (dart.library.html) 'scanner/receipt_scanner_web.dart';

export 'scanner/receipt_scanner_interface.dart';

class ReceiptScannerService {
  final ReceiptScannerPlatform _delegate = ReceiptScannerImplementation();

  Future<ParsedReceipt> scanReceipt(XFile imageFile) async {
    return _delegate.scanReceipt(imageFile);
  }

  void dispose() {
    _delegate.dispose();
  }
}

class ParsedReceipt {
  final List<ParsedItem> items;
  final double? total;
  final double? tip;
  final double? discount;
  final double? tax;

  ParsedReceipt({
    required this.items, 
    this.total,
    this.tip,
    this.discount,
    this.tax
  });
}

class ParsedItem {
  final String name;
  final double price;
  final int quantity; 
  
  ParsedItem({required this.name, required this.price, this.quantity = 1});
}
