import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartLedgerApp());
}

class SmartLedgerApp extends StatelessWidget {
  const SmartLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartLedger Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: const SmartLedgerHome(),
    );
  }
}

enum TransactionType { expense, regularExpense }

class LedgerEntry {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String? frequency;

  LedgerEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.type,
    this.frequency,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'type': type.name,
        'frequency': frequency,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        type: json['type'] == 'regularExpense'
            ? TransactionType.regularExpense
            : TransactionType.expense,
        frequency: json['frequency'] as String?,
      );
}

class InvoiceItem {
  final String id;
  final String clientName;
  final String description;
  final double amount;
  final bool isPaid;

  InvoiceItem({
    required this.id,
    required this.clientName,
    required this.description,
    required this.amount,
    this.isPaid = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'description': description,
        'amount': amount,
        'isPaid': isPaid,
      };

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        id: json['id'] as String,
        clientName: json['clientName'] as String,
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        isPaid: json['isPaid'] as bool? ?? false,
      );
}

class SmartLedgerHome extends StatefulWidget {
  const SmartLedgerHome({super.key});

  @override
  State<SmartLedgerHome> createState() => _SmartLedgerHomeState();
}

class _SmartLedgerHomeState extends State<SmartLedgerHome> {
  static const String _budgetKey = 'smartledger_monthly_budget';
  static const String _catBudgetsKey = 'smartledger_category_budgets';
  static const String _entriesKey = 'smartledger_entries';
  static const String _invoicesKey = 'smartledger_invoices';

  int _selectedIndex = 0;
  bool _isLoading = true;

  double _monthlyBudget = 0.0;
  final Map<String, double> _categoryBudgets = {
    'Food': 0.0,
    'Travel': 0.0,
    'Bills': 0.0,
    'Shopping': 0.0,
    'Other': 0.0,
  };

  final List<LedgerEntry> _entries = [];
  final List<InvoiceItem> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadDataFromPrefs();
  }

  Future<void> _loadDataFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBudget = prefs.getDouble(_budgetKey) ?? 0.0;

    final catJsonString = prefs.getString(_catBudgetsKey);
    if (catJsonString != null) {
      final decoded = jsonDecode(catJsonString) as Map<String, dynamic>;
      for (final key in _categoryBudgets.keys) {
        if (decoded.containsKey(key)) {
          _categoryBudgets[key] = (decoded[key] as num).toDouble();
        }
      }
    }

    final entriesString = prefs.getString(_entriesKey);
    if (entriesString != null) {
      final decodedList = jsonDecode(entriesString) as List<dynamic>;
      _entries
        ..clear()
        ..addAll(
          decodedList
              .map((item) => LedgerEntry.fromJson(item as Map<String, dynamic>)),
        );
    }

    final invoicesString = prefs.getString(_invoicesKey);
    if (invoicesString != null) {
      final decodedInv = jsonDecode(invoicesString) as List<dynamic>;
      _invoices
        ..clear()
        ..addAll(
          decodedInv
              .map((item) => InvoiceItem.fromJson(item as Map<String, dynamic>)),
        );
    }

    if (!mounted) return;
    setState(() {
      _monthlyBudget = savedBudget;
      _isLoading = false;
    });
  }

  Future<void> _saveDataToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, _monthlyBudget);
    await prefs.setString(_catBudgetsKey, jsonEncode(_categoryBudgets));
    await prefs.setString(
      _entriesKey,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _invoicesKey,
      jsonEncode(_invoices.map((i) => i.toJson()).toList()),
    );
  }

  double get _totalSpent =>
      _entries.fold(0.0, (sum, item) => sum + item.amount);

  double get _regularExpensesTotal => _entries
      .where((e) => e.type == TransactionType.regularExpense)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get _remainingBudget => _monthlyBudget - _totalSpent;

  void _setMonthlyBudgetDialog() {
    final controller = TextEditingController(
      text: _monthlyBudget > 0 ? _monthlyBudget.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apna Monthly Budget Likhein'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Total Budget (e.g. 50000)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value >= 0) {
                setState(() => _monthlyBudget = value);
                await _saveDataToPrefs();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save Budget'),
          ),
        ],
      ),
    );
  }

  void _addEntryDialog({required bool isRegular}) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = _categoryBudgets.keys.first;
    String selectedFrequency = 'Monthly';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            isRegular
                ? 'Naya Regular Expense Add Karein'
                : 'Naya Expense Add Karein',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: isRegular
                        ? 'Naam (e.g. Rent, Internet, Milk)'
                        : 'Expense Title (e.g. Lunch, Taxi)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categoryBudgets.keys
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedCategory = val);
                    }
                  },
                ),
                if (isRegular) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Repeat Frequency',
                      border: OutlineInputBorder(),
                    ),
                    items: const ['Daily', 'Weekly', 'Monthly']
                        .map(
                          (freq) =>
                              DropdownMenuItem(value: freq, child: Text(freq)),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedFrequency = val);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final amount = double.tryParse(amountController.text.trim());
                if (title.isNotEmpty && amount != null && amount > 0) {
                  setState(() {
                    _entries.insert(
                      0,
                      LedgerEntry(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        category: selectedCategory,
                        amount: amount,
                        date: DateTime.now(),
                        type: isRegular
                            ? TransactionType.regularExpense
                            : TransactionType.expense,
                        frequency: isRegular ? selectedFrequency : null,
                      ),
                    );
                  });
                  await _saveDataToPrefs();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _editCategoryBudgetDialog(String category) {
    final controller = TextEditingController(
      text: (_categoryBudgets[category] ?? 0).toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$category Budget Set Karein'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Category Limit',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value >= 0) {
                setState(() => _categoryBudgets[category] = value);
                await _saveDataToPrefs();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addInvoiceDialog() {
    final clientController = TextEditingController();
    final descController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Naya Invoice Banayein'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: clientController,
              decoration: const InputDecoration(
                labelText: 'Client / Customer Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Work / Item Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final client = clientController.text.trim();
              final desc = descController.text.trim();
              final amount = double.tryParse(amountController.text.trim());
              if (client.isNotEmpty && amount != null && amount > 0) {
                setState(() {
                  _invoices.insert(
                    0,
                    InvoiceItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      clientName: client,
                      description: desc.isEmpty ? 'Invoice Item' : desc,
                      amount: amount,
                    ),
                  );
                });
                await _saveDataToPrefs();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    final progress = _monthlyBudget > 0
        ? (_totalSpent / _monthlyBudget).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Apna Monthly Budget',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _setMonthlyBudgetDialog,
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(_monthlyBudget > 0 ? 'Change' : 'Set Budget'),
                    ),
                  ],
                ),
                Text(
                  _monthlyBudget.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxis
