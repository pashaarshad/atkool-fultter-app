import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/fee_service.dart';

class ParentFeesScreen extends StatefulWidget {
  const ParentFeesScreen({super.key});

  @override
  State<ParentFeesScreen> createState() => _ParentFeesScreenState();
}

class _ParentFeesScreenState extends State<ParentFeesScreen> {
  final _feeService = FeeService();
  bool _isLoading = true;
  List<dynamic> _fees = [];
  Map<String, dynamic>? _qrData;

  // Stats
  double _totalAllocated = 0;
  double _totalPaid = 0;
  double _totalPending = 0;

  @override
  void initState() {
    super.initState();
    _loadFeeDetails();
  }

  Future<void> _loadFeeDetails() async {
    setState(() => _isLoading = true);

    final feesResult = await _feeService.getParentFees();
    final qrResult = await _feeService.getSchoolQr();

    if (feesResult['success']) {
      _fees = feesResult['data'] ?? [];
      _calculateStats();
    }

    if (qrResult['success']) {
      _qrData = qrResult['data'];
    }

    setState(() => _isLoading = false);
  }

  void _calculateStats() {
    double allocated = 0;
    double paid = 0;
    double pending = 0;

    for (var f in _fees) {
      final totalAmt = double.tryParse(f['totalAmount']?.toString() ?? '0') ?? 0;
      final paidAmt = double.tryParse(f['amountPaid']?.toString() ?? '0') ?? 0;

      // Safe fallback calculation to match Web dashboard logic
      final calculatedAllocated = paidAmt > totalAmt ? paidAmt : totalAmt;

      allocated += calculatedAllocated;
      paid += paidAmt;
      
      final diff = calculatedAllocated - paidAmt;
      pending += diff > 0 ? diff : 0;
    }

    _totalAllocated = allocated;
    _totalPaid = paid;
    _totalPending = pending;
  }

  List<Map<String, dynamic>> get _paidReceipts {
    List<Map<String, dynamic>> receipts = [];
    for (var f in _fees) {
      final structure = f['feeStructureId'] ?? {};
      final installments = f['installments'] ?? [];
      for (var inst in installments) {
        if (inst['status'] == 'Paid') {
          receipts.add({
            'paymentId': f['_id'],
            'installmentId': inst['_id'],
            'feeName': structure['feeName'] ?? 'School Fee',
            'label': inst['label'] ?? 'Installment',
            'amount': double.tryParse(inst['submittedAmount']?.toString() ?? inst['amount']?.toString() ?? '0') ?? 0,
            'date': inst['paidDate'] != null 
                ? DateTime.parse(inst['paidDate'].toString()).toLocal().toString().split(' ')[0]
                : (inst['submittedDate'] != null 
                    ? DateTime.parse(inst['submittedDate'].toString()).toLocal().toString().split(' ')[0]
                    : 'N/A'),
            'receiptNo': inst['transactionId'] ?? inst['utrNumber'] ?? inst['_id'] ?? 'N/A',
            'payment': f,
            'installment': inst
          });
        }
      }
    }
    return receipts;
  }

  Future<void> _generateAndOpenReceipt(Map<String, dynamic> r) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF Receipt...'), duration: Duration(milliseconds: 700)),
      );

      final pdf = pw.Document();

      final payment = r['payment'];
      final inst = r['installment'];
      final school = payment['schoolId'] ?? {};
      final student = payment['studentId'] ?? {};
      final structure = payment['feeStructureId'] ?? {};

      final schoolName = (school['name'] ?? 'ATKool Partner School').toString().toUpperCase();
      final schoolAddress = (school['address'] ?? school['city'] ?? 'N/A').toString();
      final studentName = (student['name'] ?? 'N/A').toString();
      final studentIdVal = (student['studentId'] ?? student['rollNo'] ?? 'N/A').toString();
      final studentClass = student['className'] != null 
          ? '${student['className']} - ${student['section'] ?? 'A'}'
          : 'N/A';
      
      final receiptNo = r['receiptNo'].toString();
      final paymentDate = r['date'].toString();
      final paidAmount = r['amount'] as double;
      
      final totalAmount = double.tryParse(payment['totalAmount']?.toString() ?? '0') ?? 0;
      final totalPaidSoFar = double.tryParse(payment['amountPaid']?.toString() ?? '0') ?? 0;
      double balanceRemaining = totalAmount - totalPaidSoFar;
      if (balanceRemaining < 0) balanceRemaining = 0;

      var paymentMode = (payment['paymentMode'] ?? 'Online/UPI').toString();
      if (inst['utrNumber'] != null && inst['utrNumber'] != '') {
        paymentMode += ' (UTR: ${inst['utrNumber']})';
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.indigo, width: 3),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(12),
                    color: PdfColors.indigo,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          schoolName,
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          schoolAddress,
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey200),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Title
                  pw.Text(
                    'OFFICIAL FEE RECEIPT',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo),
                  ),
                  pw.Divider(color: PdfColors.grey300, thickness: 1),
                  pw.SizedBox(height: 10),

                  // Details Grid
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfDetail('Receipt Number', receiptNo),
                          _buildPdfDetail('Payment Date', paymentDate),
                          _buildPdfDetail('Payment Mode', paymentMode),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfDetail('Student Name', studentName),
                          _buildPdfDetail('Student ID', studentIdVal),
                          _buildPdfDetail('Class / Section', studentClass),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.Divider(color: PdfColors.grey300, thickness: 1),
                  pw.SizedBox(height: 15),

                  // Table
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Particulars', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                      // Data Row
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${structure['feeName'] ?? 'School Fee'} - ${inst['label'] ?? 'Installment'}',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('1', style: const pw.TextStyle(fontSize: 11)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('INR ${paidAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),

                  // Summary
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Total Paid Amount: INR ${paidAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                        pw.SizedBox(height: 4),
                        pw.Text('Remaining Balance: INR ${balanceRemaining.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 30),

                  // Official Verified Stamp
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.green, width: 2),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text('PAID & VERIFIED', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green, fontSize: 12)),
                            pw.SizedBox(height: 2),
                            pw.Text('ATKool Connect', style: const pw.TextStyle(fontSize: 8, color: PdfColors.green)),
                          ],
                        ),
                      ),
                      pw.Column(
                        children: [
                          pw.Container(width: 120, height: 1, color: PdfColors.grey600),
                          pw.SizedBox(height: 4),
                          pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                        ],
                      ),
                    ],
                  ),

                  pw.Spacer(),
                  pw.Text(
                    'This is a system-generated verified fee receipt sent automatically via ATKool Connect.',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Receipt_$receiptNo.pdf');
      await file.writeAsBytes(await pdf.save());

      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  pw.Widget _buildPdfDetail(String label, String val) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text('$label: ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.Text(val, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF))),
      );
    }

    final receiptsList = _paidReceipts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fees & Payments',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Allocated',
                    '₹${_totalAllocated.toStringAsFixed(0)}',
                    const Color(0xFF6B4EFF),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Paid',
                    '₹${_totalPaid.toStringAsFixed(0)}',
                    const Color(0xFF28A745),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Pending',
                    '₹${_totalPending.toStringAsFixed(0)}',
                    const Color(0xFFDC3545),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ledger List
            const Text(
              'Fee Ledger',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 12),
            _fees.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No fee records found.', style: TextStyle(color: Colors.grey))),
                    ),
                  )
                : Column(
                    children: _fees.map((f) => _buildFeeLedgerCard(f)).toList(),
                  ),
            const SizedBox(height: 24),

            if (_qrData != null && _totalPending > 0) ...[
              const Text(
                'UPI Payment Info',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(5),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_qrData!['qrCode'] != null && _qrData!['qrCode'].toString().startsWith('data:image'))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(_qrData!['qrCode'].toString().split(',').last),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[100],
                            child: const Icon(Icons.qr_code_2, color: Colors.grey, size: 40),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B4EFF).withAlpha(10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.qr_code_2, color: Color(0xFF6B4EFF), size: 48),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan QR to Pay School Fees',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'UPI ID: ${_qrData!['upiId'] ?? 'N/A'}',
                            style: TextStyle(color: Colors.grey[700], fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Please share proof with reference number after payment.',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Fee Receipts
            const Text(
              'Fee Receipts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 12),
            receiptsList.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: const Center(
                      child: Text(
                        '0 Receipts Available',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: receiptsList.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final r = receiptsList[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF28A745).withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt_long, color: Color(0xFF28A745)),
                          ),
                          title: Text(
                            r['feeName'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Paid: ${r['date']} • No: ${r['receiptNo'].toString().substring(0, r['receiptNo'].toString().length > 8 ? 8 : r['receiptNo'].toString().length)}...',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${r['amount'].toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF28A745), fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.download, color: Color(0xFF6B4EFF)),
                                onPressed: () => _generateAndOpenReceipt(r),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFeeLedgerCard(dynamic f) {
    final structure = f['feeStructureId'] ?? {};
    final installments = f['installments'] ?? [];
    final feeName = structure['feeName'] ?? 'School Fee';
    final totalAmt = double.tryParse(f['totalAmount']?.toString() ?? '0') ?? 0;
    final paidAmt = double.tryParse(f['amountPaid']?.toString() ?? '0') ?? 0;
    final calculatedAllocated = paidAmt > totalAmt ? paidAmt : totalAmt;
    final remaining = calculatedAllocated - paidAmt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          feeName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A1A)),
        ),
        subtitle: Text(
          'Total: ₹${calculatedAllocated.toStringAsFixed(0)} • Paid: ₹${paidAmt.toStringAsFixed(0)} • Balance: ₹${remaining.toStringAsFixed(0)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: installments.isEmpty
                ? const Center(child: Text('No installments structured yet.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                : Column(
                    children: (installments as List).map<Widget>((inst) {
                      final label = inst['label'] ?? 'Installment';
                      final amount = inst['amount'] ?? 0;
                      final status = inst['status'] ?? 'Unpaid';
                      
                      Color statusColor;
                      switch (status) {
                        case 'Paid':
                          statusColor = const Color(0xFF28A745);
                          break;
                        case 'Pending':
                          statusColor = const Color(0xFFFF9800);
                          break;
                        default:
                          statusColor = const Color(0xFFDC3545);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text('Amount: ₹$amount', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
