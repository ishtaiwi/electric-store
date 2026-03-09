import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../../features/customers/domain/entities/customer.dart';
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
    
    final fileName = 'Statement_${customer.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = '${statementsDir.path}/$fileName';
    
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

    final safeName = priceList.title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final fileName = 'PriceList_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
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

    final storeName = storeSettings?['store_name'] ?? 'Electrical Store';
    final storeAddress = storeSettings?['address'] ?? '';
    final storePhone = storeSettings?['phone'] ?? '';
    final storeEmail = storeSettings?['email'] ?? '';
    final currency = storeSettings?['currency'] ?? 'ILS';

    final totalAmount = items.fold(0.0, (sum, item) => sum + item.totalPrice);

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
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      if (storeAddress.isNotEmpty)
                        pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 10)),
                      if (storePhone.isNotEmpty)
                        pw.Text('Phone: $storePhone', style: const pw.TextStyle(fontSize: 10)),
                      if (storeEmail.isNotEmpty)
                        pw.Text('Email: $storeEmail', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'PRICE LIST',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.teal50,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'Quotation Only - Not an Invoice',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2, color: PdfColors.teal),
              pw.SizedBox(height: 16),

              // Price List Info
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
                        pw.Text(
                          priceList.title,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        if (priceList.customerName != null)
                          pw.Text(
                            'Client: ${priceList.customerName}',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _buildInfoRow('Date:', _formatDate(priceList.createdAt)),
                        _buildInfoRow('Items:', '${items.length}'),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FixedColumnWidth(35),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal),
                    children: [
                      _tableHeader('#'),
                      _tableHeader('Product'),
                      _tableHeader('Qty'),
                      _tableHeader('Unit Price'),
                      _tableHeader('Total'),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index.isEven ? PdfColors.white : PdfColors.grey50,
                      ),
                      children: [
                        _tableCell('${index + 1}', center: true),
                        _tableCell(item.productName),
                        _tableCell('${item.quantity}', center: true),
                        _tableCell('\$$currency ${item.unitPrice.toStringAsFixed(2)}', right: true),
                        _tableCell('\$$currency ${item.totalPrice.toStringAsFixed(2)}', right: true),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),

              // Total
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.teal, width: 2),
                    borderRadius: pw.BorderRadius.circular(4),
                    color: PdfColors.teal50,
                  ),
                  child: _buildTotalRow(
                    'TOTAL:',
                    '\$$currency ${totalAmount.toStringAsFixed(2)}',
                    bold: true,
                    fontSize: 16,
                  ),
                ),
              ),

              // Notes
              if (priceList.notes != null && priceList.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Notes:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange50,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    priceList.notes!,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ),
              ],

              // Footer
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'This is a price quotation only and does not constitute a sale or invoice.',
                    style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey500,
                      fontSize: 9,
                    ),
                  ),
                  pw.Text(
                    'Generated: ${_formatDate(DateTime.now())}',
                    style: const pw.TextStyle(
                      color: PdfColors.grey500,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }
}
