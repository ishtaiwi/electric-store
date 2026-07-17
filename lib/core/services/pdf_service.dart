import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../../features/customers/domain/entities/customer.dart';
import '../../features/customers/domain/entities/customer_ledger.dart';
import '../../features/customers/domain/entities/customer_ledger_entry.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/invoices/domain/entities/sale_item.dart';
import '../../features/price_lists/domain/entities/price_list.dart';
import '../../features/price_lists/domain/entities/price_list_item.dart';

class PdfService {
  pw.Font? _arabicFont;
  pw.Font? _arabicBoldFont;
  
  Future<void> _loadArabicFont() async {
    if (_arabicFont != null) return;
    
    try {
      // Load Arabic-supporting font from system fonts
      // Try common Arabic-capable fonts available on Windows
      final fontNames = [
        'Tahoma',
        'Arial',
        'Segoe UI',
        'Times New Roman',
      ];
      
      for (final fontName in fontNames) {
        try {
          final regular = await _loadSystemFont(fontName, bold: false);
          final bold = await _loadSystemFont(fontName, bold: true);
          if (regular != null) {
            _arabicFont = regular;
            _arabicBoldFont = bold ?? regular;
            return;
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      // Fallback: will use default font
    }
  }

  Future<pw.Font?> _loadSystemFont(String fontName, {bool bold = false}) async {
    try {
      final fontFile = await _findSystemFontFile(fontName, bold: bold);
      if (fontFile != null && await fontFile.exists()) {
        final bytes = await fontFile.readAsBytes();
        return pw.Font.ttf(bytes.buffer.asByteData());
      }
    } catch (_) {}
    return null;
  }

  Future<File?> _findSystemFontFile(String fontName, {bool bold = false}) async {
    final windowsFontsDir = 'C:\\Windows\\Fonts';
    
    // Map font names to their file names
    final fontFiles = <String, Map<String, String>>{
      'Tahoma': {'regular': 'tahoma.ttf', 'bold': 'tahomabd.ttf'},
      'Arial': {'regular': 'arial.ttf', 'bold': 'arialbd.ttf'},
      'Segoe UI': {'regular': 'segoeui.ttf', 'bold': 'segoeuib.ttf'},
      'Times New Roman': {'regular': 'times.ttf', 'bold': 'timesbd.ttf'},
    };
    
    final files = fontFiles[fontName];
    if (files == null) return null;
    
    final fileName = bold ? files['bold']! : files['regular']!;
    final file = File('$windowsFontsDir\\$fileName');
    
    if (await file.exists()) return file;
    return null;
  }

  pw.TextStyle _baseStyle({bool bold = false, double? fontSize, PdfColor? color}) {
    return pw.TextStyle(
      font: bold ? (_arabicBoldFont ?? _arabicFont) : _arabicFont,
      fontBold: _arabicBoldFont ?? _arabicFont,
      fontWeight: bold ? pw.FontWeight.bold : null,
      fontSize: fontSize,
      color: color,
    );
  }

  pw.ThemeData _buildTheme() {
    if (_arabicFont == null) {
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      );
    }
    return pw.ThemeData.withFont(
      base: _arabicFont!,
      bold: _arabicBoldFont ?? _arabicFont!,
      italic: _arabicFont!,
      boldItalic: _arabicBoldFont ?? _arabicFont!,
    );
  }

  /// Save invoice as PDF file and return the file path
  Future<String> saveInvoicePdf({
    required Invoice invoice,
    required List<SaleItem> items,
    Map<String, dynamic>? storeSettings,
    String? customPath,
  }) async {
    await _loadArabicFont();
    
    final pdf = await _buildInvoicePdf(invoice, items, storeSettings);
    
    // Determine save path
    final directory = customPath ?? (await getApplicationDocumentsDirectory()).path;
    final invoicesDir = Directory('$directory/Invoices');
    if (!await invoicesDir.exists()) {
      await invoicesDir.create(recursive: true);
    }
    
    final fileName = 'Invoice_${invoice.invoiceNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = '${invoicesDir.path}/$fileName';
    
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    
    return filePath;
  }

  /// Print invoice directly
  Future<void> printInvoice({
    required Invoice invoice,
    required List<SaleItem> items,
    Map<String, dynamic>? storeSettings,
  }) async {
    await _loadArabicFont();
    final pdf = await _buildInvoicePdf(invoice, items, storeSettings);

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Invoice_${invoice.invoiceNumber}',
    );
  }

  // Lightning bolt icon drawn with PDF primitives to represent electrical store
  pw.Widget _buildLightningBoltIcon({double size = 32, PdfColor color = PdfColors.amber}) {
    return pw.CustomPaint(
      size: PdfPoint(size, size),
      painter: (PdfGraphics canvas, PdfPoint canvasSize) {
        final w = canvasSize.x;
        final h = canvasSize.y;
        canvas
          ..setFillColor(color)
          ..moveTo(w * 0.55, 0)
          ..lineTo(w * 0.20, h * 0.50)
          ..lineTo(w * 0.45, h * 0.50)
          ..lineTo(w * 0.35, h)
          ..lineTo(w * 0.80, h * 0.42)
          ..lineTo(w * 0.52, h * 0.42)
          ..lineTo(w * 0.65, 0)
          ..closePath()
          ..fillPath();
      },
    );
  }

  // Builds a small decorative accent bar
  pw.Widget _buildAccentBar({double width = 60, double height = 3, PdfColor color = const PdfColor.fromInt(0xFF1565C0)}) {
    return pw.Container(
      width: width,
      height: height,
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(2),
      ),
    );
  }

  pw.Widget _buildStoreBrandingBlock({
    required String storeName,
    String storeAddress = '',
    String storePhone = '',
    String storeEmail = '',
    PdfColor brandPrimary = const PdfColor.fromInt(0xFF1565C0),
    PdfColor brandDark = const PdfColor.fromInt(0xFF0D47A1),
    PdfColor brandAmber = const PdfColor.fromInt(0xFFFFC107),
    double titleFontSize = 22,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  storeName,
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: pw.FontWeight.bold,
                    color: brandDark,
                  ),
                ),
                pw.SizedBox(height: 2),
                _buildAccentBar(width: 50, height: 2, color: brandAmber),
              ],
            ),
            pw.SizedBox(width: 10),
            pw.Container(
              width: 38,
              height: 38,
              decoration: pw.BoxDecoration(
                color: brandPrimary,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              alignment: pw.Alignment.center,
              child: _buildLightningBoltIcon(size: 22, color: brandAmber),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        if (storeAddress.isNotEmpty)
          pw.Text(
            storeAddress,
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        if (storePhone.isNotEmpty)
          pw.Text(
            'هاتف: $storePhone',
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        if (storeEmail.isNotEmpty)
          pw.Text(
            'بريد: $storeEmail',
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
      ],
    );
  }

  pw.Widget _buildDocumentTitleBadge(
    String title, {
    PdfColor brandPrimary = const PdfColor.fromInt(0xFF1565C0),
    double fontSize = 18,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: pw.BoxDecoration(
        color: brandPrimary,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        title,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _buildBalanceSummaryBranding({
    required String currency,
    required double totalSales,
    required double totalPayments,
    required double currentBalance,
    PdfColor brandPrimary = const PdfColor.fromInt(0xFF1565C0),
    PdfColor brandDark = const PdfColor.fromInt(0xFF0D47A1),
    PdfColor brandAmber = const PdfColor.fromInt(0xFFFFC107),
    PdfColor debitColor = const PdfColor.fromInt(0xFFC62828),
    PdfColor creditColor = const PdfColor.fromInt(0xFF2E7D32),
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: double.infinity,
          child: pw.Text(
            'ملخص الرصيد',
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.black),
          ),
        ),
        pw.SizedBox(height: 8),
        _buildInfoRowAr('إجمالي المبيعات:', '$currency ${totalSales.toStringAsFixed(2)}'),
        _buildInfoRowAr('إجمالي المدفوع:', '$currency ${totalPayments.toStringAsFixed(2)}'),
        pw.Divider(color: brandPrimary, height: 14),
        pw.SizedBox(
          width: double.infinity,
          child: pw.Text(
            'الرصيد الحالي: $currency ${currentBalance.toStringAsFixed(2)}',
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: currentBalance > 0 ? debitColor : (currentBalance < 0 ? creditColor : brandDark),
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildCustomerDataBranding({
    required String customerName,
    required String customerCode,
    String? phone,
    String? address,
    PdfColor brandPrimary = const PdfColor.fromInt(0xFF1565C0),
    PdfColor brandDark = const PdfColor.fromInt(0xFF0D47A1),
    PdfColor brandAmber = const PdfColor.fromInt(0xFFFFC107),
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: double.infinity,
          child: pw.Text(
            'بيانات العميل',
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.black),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.SizedBox(
          width: double.infinity,
          child: pw.Text(
            customerName,
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: brandDark,
            ),
          ),
        ),
        _buildInfoRowAr('رقم الحساب:', customerCode),
        if (phone != null && phone.isNotEmpty) _buildInfoRowAr('هاتف:', phone),
        if (address != null && address.isNotEmpty) _buildInfoRowAr('عنوان:', address),
      ],
    );
  }

  Future<pw.Document> _buildInvoicePdf(
    Invoice invoice,
    List<SaleItem> items,
    Map<String, dynamic>? storeSettings,
  ) async {
    final pdf = pw.Document(theme: _buildTheme());
    
    final storeName = storeSettings?['store_name'] ?? 'Electrical Store';
    final storeAddress = storeSettings?['address'] ?? '';
    final storePhone = storeSettings?['phone'] ?? '';
    final storeEmail = storeSettings?['email'] ?? '';
    final currency = storeSettings?['currency'] ?? 'ILS';

    // Brand colors
    const brandPrimary = PdfColor.fromInt(0xFF1565C0);
    const brandDark = PdfColor.fromInt(0xFF0D47A1);
    const brandLight = PdfColor.fromInt(0xFFE3F2FD);
    const brandAmber = PdfColor.fromInt(0xFFFFC107);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        header: (context) {
          if (context.pageNumber == 1) {
            return pw.Column(
              children: [
                // ─── Top brand stripe ───
                pw.Container(
                  width: double.infinity,
                  height: 6,
                  decoration: const pw.BoxDecoration(
                    color: brandPrimary,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                ),
                pw.SizedBox(height: 16),

                // ─── Header row: Store info (right) + Invoice title (left) ───
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Store branding (right side in RTL = first child) with lightning bolt + address
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  storeName,
                                  style: pw.TextStyle(
                                    fontSize: 22,
                                    fontWeight: pw.FontWeight.bold,
                                    color: brandDark,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                _buildAccentBar(width: 50, height: 2, color: brandAmber),
                              ],
                            ),
                            pw.SizedBox(width: 10),
                            // Lightning bolt icon container
                            pw.Container(
                              width: 38,
                              height: 38,
                              decoration: pw.BoxDecoration(
                                color: brandPrimary,
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              alignment: pw.Alignment.center,
                              child: _buildLightningBoltIcon(size: 22, color: brandAmber),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        if (storeAddress.isNotEmpty)
                          pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
                        if (storePhone.isNotEmpty)
                          pw.Text('هاتف: $storePhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
                        if (storeEmail.isNotEmpty)
                          pw.Text('بريد: $storeEmail', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right),
                      ],
                    ),

                    pw.Spacer(),

                    // Invoice label (left side in RTL = last child)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: brandPrimary,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'فاتورة',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          '#${invoice.id}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: brandDark,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _formatDate(invoice.createdAt),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),

                // ─── Divider with dots ───
                pw.Container(
                  width: double.infinity,
                  height: 1.5,
                  color: brandPrimary,
                ),
                pw.SizedBox(height: 16),

                // ─── Info cards row ───
                pw.Row(
                  children: [
                    // Customer card
                    pw.Expanded(
                      flex: 3,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: brandLight,
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(color: brandPrimary, width: 0.5),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'العميل',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: brandPrimary,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              invoice.customerName ?? 'زبون عادي',
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    // Payment method card
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'طريقة الدفع',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              _formatPaymentMethod(invoice.paymentMethod),
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    // Cashier card
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'الكاشير',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              invoice.userName ?? '-',
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    // Status badge
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: invoice.isFullyPaid
                              ? const PdfColor.fromInt(0xFFE8F5E9)
                              : (invoice.isPartiallyPaid
                                  ? const PdfColor.fromInt(0xFFFFF8E1)
                                  : const PdfColor.fromInt(0xFFFFEBEE)),
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(
                            color: invoice.isFullyPaid
                                ? PdfColors.green
                                : (invoice.isPartiallyPaid ? PdfColors.orange : PdfColors.red),
                            width: 0.5,
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'الحالة',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              invoice.isFullyPaid ? 'مدفوعة' : (invoice.isPartiallyPaid ? 'جزئي' : 'غير مدفوعة'),
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: invoice.isFullyPaid
                                    ? PdfColors.green800
                                    : (invoice.isPartiallyPaid ? PdfColors.orange800 : PdfColors.red800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
            );
          }
          // Continuation pages: compact header
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'فاتورة #${invoice.id} - صفحة ${context.pageNumber}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        storeName,
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: brandDark),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Container(
                        width: 18,
                        height: 18,
                        decoration: pw.BoxDecoration(
                          color: brandPrimary,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        alignment: pw.Alignment.center,
                        child: _buildLightningBoltIcon(size: 11, color: brandAmber),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Container(width: double.infinity, height: 1, color: brandPrimary),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (context) {
          return pw.Column(
            children: [
              pw.SizedBox(height: 8),
              pw.Container(width: double.infinity, height: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'صفحة ${context.pageNumber} من ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      _buildLightningBoltIcon(size: 8, color: brandAmber),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        'شكراً لتعاملكم معنا!',
                        style: pw.TextStyle(
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey500,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    storeName,
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: brandPrimary,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (context) {
          return [
            // ─── Items Table ───
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder(
                left: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                right: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                top: const pw.BorderSide(color: brandPrimary, width: 1.5),
                horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                verticalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              ),
              headerDecoration: const pw.BoxDecoration(color: brandPrimary),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
              headerAlignment: pw.Alignment.center,
              cellAlignment: pw.Alignment.centerRight,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              cellStyle: const pw.TextStyle(fontSize: 10),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFAFAFA)),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(0.5),
                4: const pw.FlexColumnWidth(3),
              },
              headers: ['الإجمالي', 'سعر الوحدة', 'الكمية', '#', 'المنتج'],
              data: items.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final item = entry.value;
                return [
                  '₪${item.totalPrice.toStringAsFixed(2)}',
                  '₪${item.unitPrice.toStringAsFixed(2)}',
                  '${item.quantity}',
                  '$idx',
                  item.note != null && item.note!.isNotEmpty
                      ? '${item.productName}\n${item.note}'
                      : item.productName,
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),

            // ─── Totals & Payment summary row ───
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left side: payment info (for unpaid invoices)
                if (!invoice.isFullyPaid)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFFFF8E1),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: PdfColors.orange, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'تفاصيل الدفع',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.orange800,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          _buildTotalRow(
                            'المبلغ المدفوع:',
                            '₪${invoice.paidAmount.toStringAsFixed(2)}',
                            color: PdfColors.green700,
                          ),
                          _buildTotalRow(
                            'المبلغ المتبقي:',
                            '₪${invoice.remainingAmount.toStringAsFixed(2)}',
                            bold: true,
                            color: PdfColors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!invoice.isFullyPaid)
                  pw.SizedBox(width: 16),

                // Right side: totals box
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    children: [
                      _buildTotalRow('المجموع الفرعي:', '₪${invoice.subtotal.toStringAsFixed(2)}'),
                      if (invoice.discountAmount > 0) ...[
                        pw.SizedBox(height: 2),
                        _buildTotalRow(
                          'الخصم:',
                          '-₪${invoice.discountAmount.toStringAsFixed(2)}',
                          color: PdfColors.red,
                        ),
                      ],
                      pw.SizedBox(height: 6),
                      pw.Container(width: double.infinity, height: 1, color: PdfColors.grey300),
                      pw.SizedBox(height: 6),
                      // Grand total with highlight
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: pw.BoxDecoration(
                          color: brandLight,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'الإجمالي:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 14,
                                color: brandDark,
                              ),
                            ),
                            pw.Text(
                              '₪${invoice.finalAmount.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 16,
                                color: brandDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // ─── Notes section ───
            if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'ملاحظات:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      invoice.notes!,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // ─── Bottom decorative strip ───
            pw.Container(
              width: double.infinity,
              height: 3,
              decoration: const pw.BoxDecoration(
                color: brandPrimary,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _tableHeader(String text, {bool dark = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: dark ? PdfColors.black : PdfColors.white,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _tableCell(String text, {bool center = false, bool right = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: right
            ? pw.TextAlign.right
            : center
                ? pw.TextAlign.center
                : pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(color: PdfColors.grey700),
          ),
          pw.SizedBox(width: 8),
          pw.Text(value),
        ],
      ),
    );
  }

  pw.Widget _buildTotalRow(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 12,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : null,
              fontSize: fontSize,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : null,
              fontSize: fontSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Strip characters that are illegal in Windows file names (`<>:"/\|?*`).
  String _safeFileName(String raw, {String fallback = 'file'}) {
    final cleaned = raw
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? fallback : cleaned;
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'credit':
        return 'Credit';
      default:
        return method;
    }
  }

  /// Generate and save customer statement PDF with all invoices
  Future<String> saveCustomerStatementPdf({
    required Customer customer,
    required List<Invoice> invoices,
    required Map<int, List<SaleItem>> invoiceItems,
    Map<String, dynamic>? storeSettings,
    String? customPath,
  }) async {
    await _loadArabicFont();
    
    final pdf = await _buildCustomerStatementPdf(customer, invoices, invoiceItems, storeSettings);
    
    // Determine save path
    final directory = customPath ?? (await getApplicationDocumentsDirectory()).path;
    final statementsDir = Directory('$directory/CustomerStatements');
    if (!await statementsDir.exists()) {
      await statementsDir.create(recursive: true);
    }
    
    final safeName = _safeFileName(customer.name, fallback: 'customer');
    final fileName =
        'Statement_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = '${statementsDir.path}${Platform.pathSeparator}$fileName';
    
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    
    return filePath;
  }

  /// Print customer statement directly
  Future<void> printCustomerStatement({
    required Customer customer,
    required List<Invoice> invoices,
    required Map<int, List<SaleItem>> invoiceItems,
    Map<String, dynamic>? storeSettings,
  }) async {
    await _loadArabicFont();
    final pdf = await _buildCustomerStatementPdf(customer, invoices, invoiceItems, storeSettings);

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Statement_${customer.name}',
    );
  }

  Future<pw.Document> _buildCustomerStatementPdf(
    Customer customer,
    List<Invoice> invoices,
    Map<int, List<SaleItem>> invoiceItems,
    Map<String, dynamic>? storeSettings,
  ) async {
    final pdf = pw.Document(theme: _buildTheme());
    
    final storeName = storeSettings?['store_name'] ?? 'Electrical Store';
    final storeAddress = storeSettings?['address'] ?? '';
    final storePhone = storeSettings?['phone'] ?? '';
    final currency = storeSettings?['currency'] ?? 'ILS';

    // Calculate totals
    double totalAmount = 0;
    double totalPaid = 0;
    for (final invoice in invoices) {
      totalAmount += invoice.finalAmount;
      totalPaid += invoice.paidAmount;
    }
    final totalRemaining = totalAmount - totalPaid;

    // First page - Summary
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        storeName,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (storeAddress.isNotEmpty)
                        pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 10)),
                      if (storePhone.isNotEmpty)
                        pw.Text('Phone: $storePhone', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'CUSTOMER STATEMENT',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Date: ${_formatDate(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 16),

              // Customer Info
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Customer:', style: const pw.TextStyle(color: PdfColors.grey700)),
                        pw.Text(
                          customer.name,
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                        ),
                        if (customer.phone != null)
                          pw.Text('Phone: ${customer.phone}', style: const pw.TextStyle(fontSize: 10)),
                        if (customer.email != null)
                          pw.Text('Email: ${customer.email}', style: const pw.TextStyle(fontSize: 10)),
                        if (customer.address != null)
                          pw.Text('Address: ${customer.address}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Total Invoices: ${invoices.length}'),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: totalRemaining > 0 ? PdfColors.red50 : PdfColors.green50,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text('Balance:', style: const pw.TextStyle(fontSize: 10)),
                              pw.Text(
                                '\$$currency ${totalRemaining.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: totalRemaining > 0 ? PdfColors.red : PdfColors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Invoice Summary Table
              pw.Text(
                'Invoice Summary',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue),
                    children: [
                      _tableHeader('Invoice #'),
                      _tableHeader('Date'),
                      _tableHeader('Total'),
                      _tableHeader('Paid'),
                      _tableHeader('Remaining'),
                      _tableHeader('Status'),
                    ],
                  ),
                  // Rows
                  ...invoices.map((inv) {
                    final remaining = inv.finalAmount - inv.paidAmount;
                    return pw.TableRow(
                      children: [
                        _tableCell('#${inv.invoiceNumber}'),
                        _tableCell(_formatDate(inv.createdAt)),
                        _tableCell('\$$currency ${inv.finalAmount.toStringAsFixed(2)}', right: true),
                        _tableCell('\$$currency ${inv.paidAmount.toStringAsFixed(2)}', right: true),
                        _tableCell(
                          '\$$currency ${remaining.toStringAsFixed(2)}',
                          right: true,
                        ),
                        _tableCell(
                          remaining <= 0 ? 'Paid' : (inv.paidAmount > 0 ? 'Partial' : 'Unpaid'),
                          center: true,
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),

              // Totals
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 250,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      _buildTotalRow('Total Amount:', '\$$currency ${totalAmount.toStringAsFixed(2)}'),
                      _buildTotalRow('Total Paid:', '\$$currency ${totalPaid.toStringAsFixed(2)}', color: PdfColors.green),
                      pw.Divider(thickness: 1),
                      _buildTotalRow(
                        'Balance Due:',
                        '\$$currency ${totalRemaining.toStringAsFixed(2)}',
                        bold: true,
                        fontSize: 14,
                        color: totalRemaining > 0 ? PdfColors.red : PdfColors.green,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Add detailed pages for each invoice
    for (final invoice in invoices) {
      final items = invoiceItems[invoice.id] ?? [];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Invoice Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Invoice #${invoice.invoiceNumber}',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: invoice.isFullyPaid ? PdfColors.green100 : PdfColors.orange100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        invoice.isFullyPaid ? 'PAID' : (invoice.paidAmount > 0 ? 'PARTIAL' : 'UNPAID'),
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: invoice.isFullyPaid ? PdfColors.green : PdfColors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Text('Date: ${_formatDate(invoice.createdAt)} | ', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Payment: ${_formatPaymentMethod(invoice.paymentMethod)} | ', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Customer: ${invoice.customerName ?? customer.name}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(),
                pw.SizedBox(height: 12),

                // Items Table
                if (items.isNotEmpty) ...[
                  pw.Text('Items:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(4),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _tableHeader('Product', dark: true),
                          _tableHeader('Qty', dark: true),
                          _tableHeader('Price', dark: true),
                          _tableHeader('Total', dark: true),
                        ],
                      ),
                      ...items.map((item) => pw.TableRow(
                        children: [
                          _tableCell(item.note != null && item.note!.isNotEmpty
                              ? '${item.productName}\n${item.note}'
                              : item.productName),
                          _tableCell('${item.quantity}', center: true),
                          _tableCell('\$$currency ${item.unitPrice.toStringAsFixed(2)}', right: true),
                          _tableCell('\$$currency ${item.totalPrice.toStringAsFixed(2)}', right: true),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ] else
                  pw.Text('No items data available', style: const pw.TextStyle(color: PdfColors.grey)),

                // Invoice Totals
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        _buildTotalRow('Subtotal:', '\$$currency ${invoice.subtotal.toStringAsFixed(2)}'),
                        if (invoice.discountAmount > 0)
                          _buildTotalRow('Discount:', '-\$$currency ${invoice.discountAmount.toStringAsFixed(2)}', color: PdfColors.red),
                        pw.Divider(thickness: 1),
                        _buildTotalRow('Total:', '\$$currency ${invoice.finalAmount.toStringAsFixed(2)}', bold: true),
                        _buildTotalRow('Paid:', '\$$currency ${invoice.paidAmount.toStringAsFixed(2)}', color: PdfColors.green),
                        _buildTotalRow(
                          'Remaining:',
                          '\$$currency ${invoice.remainingAmount.toStringAsFixed(2)}',
                          bold: true,
                          color: invoice.remainingAmount > 0 ? PdfColors.red : PdfColors.green,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf;
  }

  // ==================== Price List PDF ====================

  /// Save price list as PDF file and return the file path
  Future<String> savePriceListPdf({
    required PriceList priceList,
    required List<PriceListItem> items,
    Map<String, dynamic>? storeSettings,
    String? customPath,
  }) async {
    await _loadArabicFont();

    final pdf = await _buildPriceListPdf(priceList, items, storeSettings);

    final directory = customPath ?? (await getApplicationDocumentsDirectory()).path;
    final priceListsDir = Directory('$directory/PriceLists');
    if (!await priceListsDir.exists()) {
      await priceListsDir.create(recursive: true);
    }

    final safeName = priceList.title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final fileName =
        'PriceList_${safeName.isEmpty ? 'list' : safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = '${priceListsDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  /// Print price list directly
  Future<void> printPriceList({
    required PriceList priceList,
    required List<PriceListItem> items,
    Map<String, dynamic>? storeSettings,
  }) async {
    await _loadArabicFont();
    final pdf = await _buildPriceListPdf(priceList, items, storeSettings);

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'PriceList_${priceList.title}',
    );
  }

  Future<pw.Document> _buildPriceListPdf(
    PriceList priceList,
    List<PriceListItem> items,
    Map<String, dynamic>? storeSettings,
  ) async {
    final pdf = pw.Document(theme: _buildTheme());

    const brandPrimary = PdfColor.fromInt(0xFF00796B);
    const brandDark = PdfColor.fromInt(0xFF004D40);
    const brandLight = PdfColor.fromInt(0xFFE0F2F1);
    const brandAmber = PdfColor.fromInt(0xFFFFC107);

    final storeName = storeSettings?['store_name'] ?? 'المحل الكهربائي';
    final storeAddress = storeSettings?['address'] ?? '';
    final storePhone = storeSettings?['phone'] ?? '';
    final storeEmail = storeSettings?['email'] ?? '';
    final currency = storeSettings?['currency'] ?? '₪';

    final totalAmount = items.fold(0.0, (sum, item) => sum + item.totalPrice);

    pw.Widget arText(
      String text, {
      double fontSize = 10,
      bool bold = false,
      PdfColor? color,
      pw.TextAlign align = pw.TextAlign.right,
    }) {
      return pw.Text(
        text,
        textDirection: pw.TextDirection.rtl,
        textAlign: align,
        style: _baseStyle(bold: bold, fontSize: fontSize, color: color),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        header: (context) {
          if (context.pageNumber > 1) {
            return pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    arText(
                      'قائمة أسعار — ${priceList.title} — صفحة ${context.pageNumber}',
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                    arText(storeName, fontSize: 10, bold: true, color: brandDark),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Container(width: double.infinity, height: 1, color: brandPrimary),
                pw.SizedBox(height: 10),
              ],
            );
          }
          return pw.SizedBox.shrink();
        },
        footer: (context) {
          return pw.Column(
            children: [
              pw.SizedBox(height: 8),
              pw.Container(width: double.infinity, height: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  arText(
                    'صفحة ${context.pageNumber} من ${context.pagesCount}',
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                  arText(
                    'عرض أسعار فقط — لا يُعد فاتورة أو عملية بيع',
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                  arText(
                    'تاريخ الطباعة: ${_formatDate(DateTime.now())}',
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ],
              ),
            ],
          );
        },
        build: (context) {
          return [
            pw.Container(
              width: double.infinity,
              height: 6,
              decoration: const pw.BoxDecoration(
                color: brandPrimary,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
            ),
            pw.SizedBox(height: 16),

            // Header: store + title
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      arText(storeName, fontSize: 22, bold: true, color: brandDark),
                      pw.SizedBox(height: 2),
                      _buildAccentBar(width: 50, height: 2, color: brandAmber),
                      pw.SizedBox(height: 6),
                      if (storeAddress.isNotEmpty)
                        arText(storeAddress, fontSize: 10, color: PdfColors.grey700),
                      if (storePhone.isNotEmpty)
                        arText('هاتف: $storePhone', fontSize: 10, color: PdfColors.grey700),
                      if (storeEmail.isNotEmpty)
                        arText('بريد: $storeEmail', fontSize: 10, color: PdfColors.grey700),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: brandPrimary,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: arText(
                        'قائمة أسعار',
                        fontSize: 18,
                        bold: true,
                        color: PdfColors.white,
                        align: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: brandLight,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: brandPrimary, width: 0.5),
                      ),
                      child: arText(
                        'عرض أسعار فقط — ليست فاتورة',
                        fontSize: 9,
                        bold: true,
                        color: brandDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(width: double.infinity, height: 1.5, color: brandPrimary),
            pw.SizedBox(height: 14),

            // Price list info card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: brandLight,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        arText(priceList.title, fontSize: 16, bold: true, color: brandDark),
                        if (priceList.customerName != null &&
                            priceList.customerName!.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          arText(
                            'العميل: ${priceList.customerName}',
                            fontSize: 11,
                            color: PdfColors.grey800,
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      arText(
                        'التاريخ: ${_formatDate(priceList.createdAt)}',
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                      pw.SizedBox(height: 4),
                      arText(
                        'عدد الأصناف: ${items.length}',
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Items table (RTL column order like invoices)
            if (items.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: arText(
                  'لا توجد أصناف في قائمة الأسعار',
                  fontSize: 12,
                  color: PdfColors.grey700,
                  align: pw.TextAlign.center,
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder(
                  left: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  right: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  top: const pw.BorderSide(color: brandPrimary, width: 1.5),
                  horizontalInside:
                      const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  verticalInside:
                      const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
                headerDecoration: const pw.BoxDecoration(color: brandPrimary),
                headerStyle: _baseStyle(
                  bold: true,
                  fontSize: 11,
                  color: PdfColors.white,
                ),
                headerAlignment: pw.Alignment.center,
                cellAlignment: pw.Alignment.centerRight,
                cellPadding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                cellStyle: _baseStyle(fontSize: 10),
                oddRowDecoration:
                    const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFAFAFA)),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(0.5),
                  4: const pw.FlexColumnWidth(3),
                },
                headers: ['الإجمالي', 'سعر الوحدة', 'الكمية', '#', 'المنتج'],
                data: items.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  final name = item.notes != null && item.notes!.isNotEmpty
                      ? '${item.productName}\n${item.notes}'
                      : item.productName;
                  return [
                    '$currency${item.totalPrice.toStringAsFixed(2)}',
                    '$currency${item.unitPrice.toStringAsFixed(2)}',
                    '${item.quantity}',
                    '$idx',
                    name,
                  ];
                }).toList(),
              ),

            pw.SizedBox(height: 16),

            // Total
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Container(
                width: 240,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: brandLight,
                  border: pw.Border.all(color: brandPrimary, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    arText('الإجمالي:', fontSize: 14, bold: true, color: brandDark),
                    arText(
                      '$currency${totalAmount.toStringAsFixed(2)}',
                      fontSize: 14,
                      bold: true,
                      color: brandDark,
                    ),
                  ],
                ),
              ),
            ),

            // Notes
            if (priceList.notes != null && priceList.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              arText('ملاحظات:', fontSize: 11, bold: true, color: brandDark),
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFFFF8E1),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.orange, width: 0.5),
                ),
                child: arText(
                  priceList.notes!,
                  fontSize: 10,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ];
        },
      ),
    );

    return pdf;
  }

  Future<String> saveCustomerLedgerPdf({
    required CustomerLedger ledger,
    Map<String, dynamic>? storeSettings,
    String? customPath,
    List<CustomerLedgerEntry>? entriesOverride,
    bool isPartialSelection = false,
  }) async {
    await _loadArabicFont();
    final pdf = await buildCustomerLedgerPdf(
      ledger,
      storeSettings,
      entriesOverride: entriesOverride,
      isPartialSelection: isPartialSelection,
    );

    final directory = customPath ?? (await getApplicationDocumentsDirectory()).path;
    final statementsDir = Directory('$directory/CustomerStatements');
    if (!await statementsDir.exists()) {
      await statementsDir.create(recursive: true);
    }

    final safeName = _safeFileName(ledger.customer.name, fallback: 'customer');
    final fileName =
        'Ledger_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = '${statementsDir.path}${Platform.pathSeparator}$fileName';
    await File(filePath).writeAsBytes(await pdf.save());
    return filePath;
  }

  Future<pw.Document> buildCustomerLedgerPdf(
    CustomerLedger ledger,
    Map<String, dynamic>? storeSettings, {
    List<CustomerLedgerEntry>? entriesOverride,
    bool isPartialSelection = false,
  }) async {
    await _loadArabicFont();
    final pdf = pw.Document(theme: _buildTheme());

    const brandPrimary = PdfColor.fromInt(0xFF1565C0);
    const brandDark = PdfColor.fromInt(0xFF0D47A1);
    const brandLight = PdfColor.fromInt(0xFFE3F2FD);
    const brandAmber = PdfColor.fromInt(0xFFFFC107);
    const debitColor = PdfColor.fromInt(0xFFC62828);
    const creditColor = PdfColor.fromInt(0xFF2E7D32);

    final storeName = storeSettings?['store_name'] ?? 'المحل الكهربائي';
    final storeAddress = storeSettings?['address'] ?? '';
    final storePhone = storeSettings?['phone'] ?? '';
    final storeEmail = storeSettings?['email'] ?? '';
    final currency = storeSettings?['currency_symbol'] ?? '₪';

    final entries = entriesOverride ?? ledger.entries;
    final totalDebit = entries.fold<double>(0, (s, e) => s + e.debit);
    final totalCredit = entries.fold<double>(0, (s, e) => s + e.credit);
    final finalBalance =
        entries.isNotEmpty ? entries.last.runningBalance : ledger.finalBalance;

    String typeLabelAr(LedgerDocumentType type) {
      switch (type) {
        case LedgerDocumentType.openingBalance:
          return 'رصيد مدور';
        case LedgerDocumentType.salesInvoice:
          return 'مبيعات';
        case LedgerDocumentType.paymentReceipt:
          return 'سند قبض';
        case LedgerDocumentType.salesReturn:
          return 'مرتجع';
        case LedgerDocumentType.manualAdjustment:
          return 'تسوية';
        case LedgerDocumentType.accountDiscount:
          return 'خصم';
      }
    }

    pw.Widget arText(
      String text, {
      double fontSize = 10,
      bool bold = false,
      PdfColor? color,
      pw.TextAlign align = pw.TextAlign.right,
    }) {
      return pw.Text(
        text,
        textDirection: pw.TextDirection.rtl,
        textAlign: align,
        style: _baseStyle(bold: bold, fontSize: fontSize, color: color),
      );
    }

    pw.Widget ledgerHeaderCell(String text, {PdfColor? bg}) {
      return pw.Container(
        color: bg ?? brandDark,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: arText(text, bold: true, fontSize: 9, color: PdfColors.white, align: pw.TextAlign.center),
      );
    }

    pw.Widget ledgerDataCell(
      String text, {
      PdfColor? bg,
      bool bold = false,
      PdfColor? color,
      pw.TextAlign align = pw.TextAlign.center,
    }) {
      return pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: arText(text, fontSize: 9, bold: bold, color: color, align: align),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(24),
        header: (context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  arText('كشف حساب — ${ledger.customer.name}', fontSize: 9, color: PdfColors.grey600),
                  arText('صفحة ${context.pageNumber}', fontSize: 9, color: PdfColors.grey600),
                ],
              ),
            );
          }
          return pw.SizedBox.shrink();
        },
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              arText('صفحة ${context.pageNumber} / ${context.pagesCount}', fontSize: 8, color: PdfColors.grey500),
              arText('تاريخ الطباعة: ${_formatLedgerDate(DateTime.now())}', fontSize: 8, color: PdfColors.grey500),
            ],
          ),
        ),
        build: (context) {
          return [
            pw.Container(
              width: double.infinity,
              height: 5,
              decoration: const pw.BoxDecoration(
                color: brandPrimary,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildStoreBrandingBlock(
                  storeName: storeName,
                  storeAddress: storeAddress,
                  storePhone: storePhone,
                  storeEmail: storeEmail,
                  brandPrimary: brandPrimary,
                  brandDark: brandDark,
                  brandAmber: brandAmber,
                ),
                pw.Spacer(),
                _buildDocumentTitleBadge('كشف حساب', brandPrimary: brandPrimary),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: brandLight,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: brandPrimary, width: 0.5),
                    ),
                    child: _buildCustomerDataBranding(
                      customerName: ledger.customer.name,
                      customerCode: ledger.customerCode,
                      phone: ledger.customer.phone,
                      address: ledger.customer.address,
                      brandPrimary: brandPrimary,
                      brandDark: brandDark,
                      brandAmber: brandAmber,
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: brandPrimary, width: 0.5),
                    ),
                    child: _buildBalanceSummaryBranding(
                      currency: currency,
                      totalSales: ledger.totalSales,
                      totalPayments: ledger.totalPayments,
                      currentBalance: ledger.currentBalance,
                      brandPrimary: brandPrimary,
                      brandDark: brandDark,
                      brandAmber: brandAmber,
                      debitColor: debitColor,
                      creditColor: creditColor,
                    ),
                  ),
                ),
              ],
            ),
            if (ledger.filters.fromDate != null || ledger.filters.toDate != null || isPartialSelection) ...[
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: brandAmber,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: arText(
                  isPartialSelection
                      ? 'تقرير جزئي — ${entries.length} حركة محددة'
                      : 'الفترة: ${ledger.filters.fromDate != null ? _formatLedgerDate(ledger.filters.fromDate!) : '...'} — ${ledger.filters.toDate != null ? _formatLedgerDate(ledger.filters.toDate!) : '...'}',
                  fontSize: 9,
                  bold: true,
                  color: brandDark,
                  align: pw.TextAlign.center,
                ),
              ),
            ],
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.3),
                1: const pw.FlexColumnWidth(1.1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(1.2),
                6: const pw.FlexColumnWidth(1.1),
                7: const pw.FixedColumnWidth(22),
              },
              children: [
                pw.TableRow(
                  children: [
                    ledgerHeaderCell('ملاحظات'),
                    ledgerHeaderCell('الرصيد'),
                    ledgerHeaderCell('دائن'),
                    ledgerHeaderCell('مدين'),
                    ledgerHeaderCell('النوع'),
                    ledgerHeaderCell('رقم المستند'),
                    ledgerHeaderCell('التاريخ'),
                    ledgerHeaderCell('#'),
                  ],
                ),
                ...entries.asMap().entries.expand((mapEntry) {
                  final i = mapEntry.key;
                  final e = mapEntry.value;
                  final rowBg = i.isEven ? PdfColors.white : PdfColors.grey50;
                  final rows = <pw.TableRow>[
                    pw.TableRow(
                      children: [
                        ledgerDataCell(e.notes ?? '', bg: rowBg, align: pw.TextAlign.right),
                        ledgerDataCell(
                          '$currency ${e.runningBalance.toStringAsFixed(2)}',
                          bg: rowBg,
                          bold: true,
                        ),
                        ledgerDataCell(
                          e.credit > 0 ? '$currency ${e.credit.toStringAsFixed(2)}' : '—',
                          bg: rowBg,
                          color: e.credit > 0 ? creditColor : null,
                          bold: e.credit > 0,
                        ),
                        ledgerDataCell(
                          e.debit > 0 ? '$currency ${e.debit.toStringAsFixed(2)}' : '—',
                          bg: rowBg,
                          color: e.debit > 0 ? debitColor : null,
                          bold: e.debit > 0,
                        ),
                        ledgerDataCell(typeLabelAr(e.documentType), bg: rowBg),
                        ledgerDataCell(e.documentNumber, bg: rowBg),
                        ledgerDataCell(_formatLedgerDate(e.date), bg: rowBg),
                        ledgerDataCell('${i + 1}', bg: rowBg),
                      ],
                    ),
                  ];

                  if (e.isSalesInvoice) {
                    final items = e.lineItems ?? (e.invoiceId != null ? ledger.invoiceItems[e.invoiceId] : null) ?? [];
                    if (items.isNotEmpty) {
                      rows.add(pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EAF6)),
                        children: [
                          ledgerHeaderCell('', bg: PdfColor.fromInt(0xFF3949AB)),
                          ledgerHeaderCell('', bg: PdfColor.fromInt(0xFF3949AB)),
                          ledgerHeaderCell('المبلغ', bg: PdfColor.fromInt(0xFF3949AB)),
                          ledgerHeaderCell('السعر', bg: PdfColor.fromInt(0xFF3949AB)),
                          ledgerHeaderCell('الكمية', bg: PdfColor.fromInt(0xFF3949AB)),
                          ledgerHeaderCell('اسم الصنف', bg: PdfColor.fromInt(0xFF3949AB)),
                          ledgerHeaderCell('الباركود', bg: PdfColor.fromInt(0xFF3949AB)),
                          ledgerHeaderCell('', bg: PdfColor.fromInt(0xFF3949AB)),
                        ],
                      ));
                      for (final item in items) {
                        rows.add(pw.TableRow(
                          children: [
                            ledgerDataCell('', bg: PdfColors.grey100),
                            ledgerDataCell('', bg: PdfColors.grey100),
                            ledgerDataCell('$currency ${item.totalAmount.toStringAsFixed(2)}', bg: PdfColors.grey100, bold: true),
                            ledgerDataCell('$currency ${item.salePrice.toStringAsFixed(2)}', bg: PdfColors.grey100),
                            ledgerDataCell('${item.quantity}', bg: PdfColors.grey100),
                            ledgerDataCell(item.productName, bg: PdfColors.grey100, align: pw.TextAlign.right),
                            ledgerDataCell(item.barcode ?? '—', bg: PdfColors.grey100),
                            ledgerDataCell('', bg: PdfColors.grey100),
                          ],
                        ));
                      }
                    }
                  }
                  return rows;
                }),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: brandLight,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: brandPrimary, width: 0.8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  arText(
                    'الرصيد الصافي: $currency ${finalBalance.toStringAsFixed(2)}',
                    fontSize: 12,
                    bold: true,
                    color: finalBalance > 0 ? debitColor : (finalBalance < 0 ? creditColor : brandDark),
                  ),
                  arText(
                    'إجمالي الدائن: $currency ${totalCredit.toStringAsFixed(2)}',
                    fontSize: 11,
                    bold: true,
                    color: creditColor,
                  ),
                  arText(
                    'إجمالي المدين: $currency ${totalDebit.toStringAsFixed(2)}',
                    fontSize: 11,
                    bold: true,
                    color: debitColor,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              height: 3,
              decoration: const pw.BoxDecoration(
                color: brandPrimary,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  String _formatLedgerDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  pw.Widget _buildInfoRowAr(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.SizedBox(
        width: double.infinity,
        child: pw.RichText(
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right,
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: label,
                style: _baseStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.TextSpan(
                text: ' $value',
                style: _baseStyle(fontSize: 9, bold: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
