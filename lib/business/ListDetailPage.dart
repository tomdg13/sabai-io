import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory/config/theme.dart';
import 'package:inventory/models/terminal_models.dart';
import 'package:inventory/services/excel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/simple_translations.dart';

class ListDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<Terminal> selectedTerminals;

  const ListDetailPage({
    Key? key,
    required this.data,
    required this.selectedTerminals,
  }) : super(key: key);

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  bool _isGeneratingPDF = false;
  bool _isGeneratingExcel = false;
  String currentTheme = ThemeConfig.defaultTheme;
  String _langCode = 'en';
  List<Map<String, dynamic>> terminalDetails = [];

  // Oxford Blue color palette
  static const PdfColor oxfordBlue = PdfColor.fromInt(0xFF002147);
  static const PdfColor oxfordBlue50 = PdfColor.fromInt(0xFFE8EDF7);
  static const PdfColor oxfordBlue100 = PdfColor.fromInt(0xFFD1DBE8);
  static const PdfColor oxfordBlue200 = PdfColor.fromInt(0xFFA3B7D1);
  static const PdfColor oxfordBlue700 = PdfColor.fromInt(0xFF001A35);
  static const PdfColor oxfordBlue800 = PdfColor.fromInt(0xFF001122);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    _loadCurrentTheme();
    _extractTerminalDetails();
  }

  Future<void> _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      _langCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  void _extractTerminalDetails() {
    if (widget.data['data'] is List) {
      terminalDetails = List<Map<String, dynamic>>.from(widget.data['data']);
    }
  }

  // Utility Methods
  String _formatExpireDate(dynamic date) {
    if (date == null) return SimpleTranslations.get(_langCode, 'n_a');
    
    DateTime? dateTime;
    if (date is DateTime) {
      dateTime = date;
    } else if (date is String) {
      try {
        dateTime = DateTime.parse(date);
      } catch (e) {
        return date.toString();
      }
    } else {
      return SimpleTranslations.get(_langCode, 'n_a');
    }
    
    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    String day = dateTime.day.toString().padLeft(2, '0');
    String month = months[dateTime.month - 1];
    String year = dateTime.year.toString();
    
    return '$day-$month-$year';
  }

  String _getExpiryStatus(Terminal terminal) {
    if (terminal.expireDate == null) return SimpleTranslations.get(_langCode, 'no_expiry');
    if (terminal.isExpired) return SimpleTranslations.get(_langCode, 'expired');
    if (terminal.isExpiringSoon) return SimpleTranslations.get(_langCode, 'expiring_soon');
    return SimpleTranslations.get(_langCode, 'valid');
  }

  Color _getExpiryStatusColor(Terminal terminal) {
    if (terminal.expireDate == null) return Colors.grey;
    if (terminal.isExpired) return Colors.red;
    if (terminal.isExpiringSoon) return Colors.orange;
    return Colors.green;
  }

  void _showMessage(String message, MessageType type) {
    final colors = {
      MessageType.success: Colors.green,
      MessageType.error: Colors.red,
      MessageType.warning: Colors.orange,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors[type],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // PDF Generation with Lao Font Support
  Future<void> _generatePDF() async {
    setState(() => _isGeneratingPDF = true);
    try {
      final pdf = await _createPDFReport();
      await _showPDFPreview(pdf);
    } catch (e) {
      _showMessage('${SimpleTranslations.get(_langCode, 'failed_to_generate_pdf')}: $e', MessageType.error);
    } finally {
      setState(() => _isGeneratingPDF = false);
    }
  }

  Future<pw.Document> _createPDFReport() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    
    // Load Lao font
    final fontData = await rootBundle.load('assets/fonts/Phetsarath-Regular.ttf');
    final laoFont = pw.Font.ttf(fontData);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => _buildPDFContent(font, fontBold, laoFont),
      ),
    );
    
    return pdf;
  }

  List<pw.Widget> _buildPDFContent(pw.Font font, pw.Font fontBold, pw.Font laoFont) {
    // Choose appropriate font based on language
    final currentFont = _langCode == 'lo' ? laoFont : font;
    final currentFontBold = _langCode == 'lo' ? laoFont : fontBold;
    
    return [
      _buildPDFHeader(currentFontBold),
      pw.SizedBox(height: 20),
      if (terminalDetails.isNotEmpty) ...[
        _buildPDFSummarySection(currentFont, currentFontBold),
        pw.SizedBox(height: 20),
        _buildPDFTerminalSection(currentFont, currentFontBold, terminalDetails),
      ] else ...[
        _buildPDFTerminalSection(currentFont, currentFontBold, null),
      ],
      _buildPDFSignatureSection(currentFont, currentFontBold),
    ];
  }

  pw.Widget _buildPDFHeader(pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 2, color: oxfordBlue)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            SimpleTranslations.get(_langCode, 'terminal_registration_form_report').toUpperCase(),
            style: pw.TextStyle(font: fontBold, fontSize: 24, color: oxfordBlue),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${SimpleTranslations.get(_langCode, 'generated')}: ${DateTime.now().toString().substring(0, 19)}',
            style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFSummarySection(pw.Font font, pw.Font fontBold) {
    if (terminalDetails.isEmpty) return pw.Container();
    
    final first = terminalDetails.first;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: oxfordBlue50,
        border: pw.Border.all(color: oxfordBlue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            SimpleTranslations.get(_langCode, 'organization_hierarchy_summary'),
            style: pw.TextStyle(font: fontBold, fontSize: 16, color: oxfordBlue800),
          ),
          pw.SizedBox(height: 12),
          _buildPDFInfoBlock(SimpleTranslations.get(_langCode, 'group_information'), [
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'code')}:', first['group_code'] ?? SimpleTranslations.get(_langCode, 'n_a'), font, fontBold),
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'name')}:', first['group_name'] ?? SimpleTranslations.get(_langCode, 'n_a'), font, fontBold),
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'mobile')}:', first['mobile'] ?? SimpleTranslations.get(_langCode, 'n_a'), font, fontBold),
          ], font, fontBold),
          pw.SizedBox(height: 12),
          _buildPDFInfoBlock(SimpleTranslations.get(_langCode, 'merchant_information'), [
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'code')}:', first['merchant_code'] ?? SimpleTranslations.get(_langCode, 'n_a'), font, fontBold),
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'name')}:', first['merchant_name'] ?? SimpleTranslations.get(_langCode, 'n_a'), font, fontBold),
          ], font, fontBold),
          pw.SizedBox(height: 12),
          _buildPDFInfoBlock(SimpleTranslations.get(_langCode, 'store_information'), [
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'code')}:', first['store_code'] ?? SimpleTranslations.get(_langCode, 'n_a'), font, fontBold),
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'name')}:', first['store_name'] ?? SimpleTranslations.get(_langCode, 'n_a'), font, fontBold),
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'store_manager')}:', first['store_manager'] ?? SimpleTranslations.get(_langCode, 'n_a'), font, fontBold),
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'store_email')}:', first['store_email'] ?? SimpleTranslations.get(_langCode, 'n_a'), font, fontBold),
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'upi_percentage')}:', first['upi_percentage'] ?? '0.00', font, fontBold),
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'visa_percentage')}:', first['visa_percentage'] ?? '0.00', font, fontBold),
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'master_percentage')}:', first['master_percentage'] ?? '0.00', font, fontBold),
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'account_name')}:', first['store_type'] ?? SimpleTranslations.get(_langCode, 'n_a'), font, fontBold),
            _buildPDFDetailRow('${SimpleTranslations.get(_langCode, 'account_no')}:', first['store_account'] ?? SimpleTranslations.get(_langCode, 'n_a'), font, fontBold),
          ], font, fontBold),
        ],
      ),
    );
  }

  pw.Widget _buildPDFInfoBlock(String title, List<pw.Widget> content, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(font: fontBold, fontSize: 12, color: oxfordBlue700),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: oxfordBlue100),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(children: content),
        ),
      ],
    );
  }

  pw.Widget _buildPDFTerminalSection(pw.Font font, pw.Font fontBold, List<Map<String, dynamic>>? details) {
    final count = details?.length ?? widget.selectedTerminals.length;
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: pw.BoxDecoration(
            color: oxfordBlue800,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(8),
              topRight: pw.Radius.circular(8),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                SimpleTranslations.get(_langCode, 'registered_terminals'),
                style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.white),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Text(
                  '$count ${SimpleTranslations.get(_langCode, 'items')}',
                  style: pw.TextStyle(font: fontBold, fontSize: 12, color: oxfordBlue800),
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.only(
              bottomLeft: pw.Radius.circular(8),
              bottomRight: pw.Radius.circular(8),
            ),
          ),
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(25),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(2.0),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _buildTableHeaderCell('#', fontBold),
                  _buildTableHeaderCell(SimpleTranslations.get(_langCode, 'terminal_name'), fontBold),
                  _buildTableHeaderCell(SimpleTranslations.get(_langCode, 'code'), fontBold),
                  _buildTableHeaderCell(SimpleTranslations.get(_langCode, 'serial_number'), fontBold),
                  _buildTableHeaderCell(SimpleTranslations.get(_langCode, 'sim_number'), fontBold),
                  _buildTableHeaderCell(SimpleTranslations.get(_langCode, 'expire_date'), fontBold),
                ],
              ),
              ...List.generate(count, (index) {
                if (details != null) {
                  final terminal = details[index];
                  return _buildTableRow(index, terminal['terminal_name'] ?? SimpleTranslations.get(_langCode, 'n_a'),
                      terminal['terminal_code'] ?? SimpleTranslations.get(_langCode, 'n_a'), terminal['serial_number'] ?? SimpleTranslations.get(_langCode, 'n_a'),
                      terminal['sim_number'] ?? SimpleTranslations.get(_langCode, 'n_a'), terminal['expire_date'] ?? SimpleTranslations.get(_langCode, 'n_a'), font);
                } else {
                  final terminal = widget.selectedTerminals[index];
                  return _buildTableRow(index, terminal.terminalName, terminal.terminalCode ?? SimpleTranslations.get(_langCode, 'n_a'),
                      terminal.serialNumber ?? SimpleTranslations.get(_langCode, 'n_a'), terminal.simNumber ?? SimpleTranslations.get(_langCode, 'n_a'),
                      _formatExpireDate(terminal.expireDate), font);
                }
              }),
            ],
          ),
        ),
        if (count > 0)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(8),
                bottomRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${SimpleTranslations.get(_langCode, 'total_terminals_registered')}: $count',
                  style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700),
                ),
                pw.Text(
                  '${SimpleTranslations.get(_langCode, 'report_generated')}: ${DateTime.now().toString().substring(0, 16)}',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.TableRow _buildTableRow(int index, String name, String code, String serial, String sim, String expire, pw.Font font) {
    final isEven = index % 2 == 0;
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isEven ? PdfColors.white : PdfColors.grey50,
      ),
      children: [
        _buildTableDataCell((index + 1).toString(), font, isCenter: true),
        _buildTableDataCell(name, font),
        _buildTableDataCell(code, font, isCode: true),
        _buildTableDataCell(serial, font),
        _buildTableDataCell(sim, font),
        _buildTableDataCell(expire, font),
      ],
    );
  }

  pw.Widget _buildPDFDetailRow(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              label,
              style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey800),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTableHeaderCell(String text, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800),
        textAlign: pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _buildTableDataCell(String text, pw.Font font, {bool isCenter = false, bool isCode = false}) {
    PdfColor textColor = PdfColors.grey700;
    PdfColor? backgroundColor;
    
    if (isCode && text != SimpleTranslations.get(_langCode, 'n_a')) {
      textColor = oxfordBlue700;
      backgroundColor = oxfordBlue50;
    }

    pw.Widget cellContent = pw.Text(
      text,
      style: pw.TextStyle(font: font, fontSize: 8, color: textColor),
      textAlign: isCenter ? pw.TextAlign.center : pw.TextAlign.left,
    );

    if (backgroundColor != null) {
      cellContent = pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: pw.BoxDecoration(
          color: backgroundColor,
          borderRadius: pw.BorderRadius.circular(3),
          border: pw.Border.all(color: oxfordBlue200, width: 0.5),
        ),
        child: cellContent,
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: isCenter ? pw.Center(child: cellContent) : cellContent,
    );
  }

  pw.Widget _buildPDFSignatureSection(pw.Font font, pw.Font fontBold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 30),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildPDFSignatureBlock(SimpleTranslations.get(_langCode, 'approved_by'), font, fontBold),
          pw.SizedBox(width: 20),
          _buildPDFSignatureBlock(SimpleTranslations.get(_langCode, 'created_by'), font, fontBold),
        ],
      ),
    );
  }

  pw.Widget _buildPDFSignatureBlock(String title, pw.Font font, pw.Font fontBold) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: oxfordBlue200),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 12, color: oxfordBlue700)),
            pw.SizedBox(height: 20),
            pw.Container(
              height: 60,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(SimpleTranslations.get(_langCode, 'signature'), style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
            pw.SizedBox(height: 16),
            pw.Container(
              height: 1,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(SimpleTranslations.get(_langCode, 'name'), style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
            pw.SizedBox(height: 16),
            pw.Container(
              height: 1,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(SimpleTranslations.get(_langCode, 'date'), style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  Future<void> _showPDFPreview(pw.Document pdf) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Terminal_Registration_Form_${DateTime.now().millisecondsSinceEpoch}',
      format: PdfPageFormat.a4,
    );
  }

  // Excel Generation
  Future<void> _generateExcel() async {
    setState(() => _isGeneratingExcel = true);
    try {
      final excelFile = await ExcelService.createTerminalReport(
        terminalDetails: terminalDetails,
        selectedTerminals: widget.selectedTerminals,
      );
      await ExcelService.downloadExcelFile(excelFile);
      _showMessage(SimpleTranslations.get(_langCode, 'excel_file_downloaded_successfully'), MessageType.success);
    } catch (e) {
      _showMessage('${SimpleTranslations.get(_langCode, 'failed_to_generate_excel')}: $e', MessageType.error);
    } finally {
      setState(() => _isGeneratingExcel = false);
    }
  }

  // UI Builders
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE8EDF7),
            const Color(0xFFF5F7FB),
            const Color(0xFFFFFFFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA3B7D1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF002147).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF002147),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF002147).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_circle, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SimpleTranslations.get(_langCode, 'terminal_registration_complete'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF002147),
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.data['message'] ?? SimpleTranslations.get(_langCode, 'registration_completed_successfully'),
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF001A35),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF002147).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF002147).withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, color: const Color(0xFF002147), size: 20),
                const SizedBox(width: 8),
                Text(
                  '${SimpleTranslations.get(_langCode, 'registered_terminals')} ${terminalDetails.isNotEmpty ? terminalDetails.length : widget.selectedTerminals.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF001A35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportButtons() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isGeneratingPDF ? null : _generatePDF,
                icon: _isGeneratingPDF 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf, size: 22),
                label: Text(
                  _isGeneratingPDF ? SimpleTranslations.get(_langCode, 'generating') : SimpleTranslations.get(_langCode, 'pdf_report'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isGeneratingExcel ? null : _generateExcel,
                icon: _isGeneratingExcel 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.table_chart, size: 22),
                label: Text(
                  _isGeneratingExcel ? SimpleTranslations.get(_langCode, 'generating') : SimpleTranslations.get(_langCode, 'excel_export'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF001A35),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalsList() {
    return terminalDetails.isNotEmpty ? _buildEnhancedTerminalsList() : _buildBasicTerminalsList();
  }

  Widget _buildEnhancedTerminalsList() {
    return _buildTerminalsCard(
      count: terminalDetails.length,
      builder: (index) => _buildEnhancedTerminalCard(terminalDetails[index], index),
    );
  }

  Widget _buildBasicTerminalsList() {
    return _buildTerminalsCard(
      count: widget.selectedTerminals.length,
      builder: (index) => _buildBasicTerminalCard(widget.selectedTerminals[index], index),
    );
  }

  Widget _buildTerminalsCard({required int count, required Widget Function(int) builder}) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, const Color(0xFFFAFBFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF002147),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.list_alt, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    SimpleTranslations.get(_langCode, 'registered_terminals'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002147),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF002147),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...List.generate(count, builder),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedTerminalCard(Map<String, dynamic> terminal, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFE8EDF7), const Color(0xFFF0F4F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA3B7D1).withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF002147).withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildNumberBadge(index + 1),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      terminal['terminal_name'] ?? SimpleTranslations.get(_langCode, 'unknown'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF002147),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildCodeBadge(terminal['terminal_code'] ?? SimpleTranslations.get(_langCode, 'no_code')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTerminalDetails([
            if (terminal['hierarchy_path'] != null) (SimpleTranslations.get(_langCode, 'path'), terminal['hierarchy_path']),
            if (terminal['serial_number'] != null) (SimpleTranslations.get(_langCode, 'serial'), terminal['serial_number']),
            if (terminal['sim_number'] != null) (SimpleTranslations.get(_langCode, 'sim'), terminal['sim_number']),
            if (terminal['expire_date'] != null) (SimpleTranslations.get(_langCode, 'expires'), _formatExpireDate(terminal['expire_date'])),
          ]),
        ],
      ),
    );
  }

  Widget _buildBasicTerminalCard(Terminal terminal, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA3B7D1).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildNumberBadge(index + 1),
        title: Text(
          terminal.terminalName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF002147),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (terminal.terminalCode != null) _buildCodeBadge(terminal.terminalCode!),
              if (terminal.serialNumber?.isNotEmpty == true) 
                _buildDetailText('${SimpleTranslations.get(_langCode, 'serial')}: ${terminal.serialNumber}'),
              if (terminal.simNumber?.isNotEmpty == true) 
                _buildDetailText('${SimpleTranslations.get(_langCode, 'sim')}: ${terminal.simNumber}'),
              if (terminal.expireDate != null) 
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildExpiryStatusText(terminal),
                ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.check_circle, color: Colors.green[600], size: 20),
        ),
      ),
    );
  }

  Widget _buildNumberBadge(int number) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF002147),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF002147).withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBadge(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF002147).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF002147).withOpacity(0.2)),
      ),
      child: Text(
        code,
        style: TextStyle(
          color: const Color(0xFF002147),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailText(String text) {
    return Text(
      text,
      style: TextStyle(color: Colors.grey[600], fontSize: 13),
    );
  }

  Widget _buildTerminalDetails(List<(String, String)> details) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Column(
        children: details.map((detail) => _buildTerminalDetailRow(detail.$1, detail.$2)).toList(),
      ),
    );
  }

  Widget _buildTerminalDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF002147),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryStatusText(Terminal terminal) {
    final status = _getExpiryStatus(terminal);
    final color = _getExpiryStatusColor(terminal);
    
    return Row(
      children: [
        Icon(
          terminal.isExpired ? Icons.error : 
          terminal.isExpiringSoon ? Icons.warning : Icons.check_circle,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${SimpleTranslations.get(_langCode, 'expires')}: ${_formatExpireDate(terminal.expireDate)} ($status)',
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSignatureSection() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, const Color(0xFFFAFBFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF002147),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.draw, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    SimpleTranslations.get(_langCode, 'signatures'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002147),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildSignatureBlock(SimpleTranslations.get(_langCode, 'created_by'))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSignatureBlock(SimpleTranslations.get(_langCode, 'approved_by'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureBlock(String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFE8EDF7), const Color(0xFFF0F4F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA3B7D1).withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF002147).withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF002147),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSignatureField(SimpleTranslations.get(_langCode, 'signature'), height: 80),
          const SizedBox(height: 12),
          _buildSignatureField(SimpleTranslations.get(_langCode, 'name')),
          const SizedBox(height: 8),
          _buildSignatureField(SimpleTranslations.get(_langCode, 'date')),
        ],
      ),
    );
  }

  Widget _buildSignatureField(String label, {double height = 48}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFA3B7D1).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Align(
        alignment: height > 50 ? Alignment.center : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(SimpleTranslations.get(_langCode, 'register_form_for_terminal')),
        backgroundColor: const Color(0xFF002147),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildReportButtons(),
            const SizedBox(height: 20),
            _buildTerminalsList(),
            const SizedBox(height: 20),
            _buildSignatureSection(),
          ],
        ),
      ),
    );
  }
}

enum MessageType { success, error, warning }