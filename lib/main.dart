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

enum EntryKind { expense, regular }

class BudgetEntry {
  final String id;
  final String title;
  final String category;
  final double amount;
  final EntryKind kind;
  final String frequency;

  BudgetEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.kind,
    required this.frequency,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'kind': kind.name,
        'frequency': frequency,
      };

  factory BudgetEntry.fromJson(Map<String, dynamic> json) => BudgetEntry(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        category: json['category']?.toString() ?? 'General',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        kind: json['kind'] == 'regular' ? EntryKind.regular : EntryKind.expense,
        frequency: json['frequency']?.toString() ?? 'One-time',
      );
}

class BillRecord {
  final String id;
  final String partyName;
  final String details;
  final double amount;
  final bool settled;

  BillRecord({
    required this.id,
    required this.partyName,
    required this.details,
    required this.amount,
    required this.settled,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'partyName': partyName,
        'details': details,
        'amount': amount,
        'settled': settled,
      };

  factory BillRecord.fromJson(Map<String, dynamic> json) => BillRecord(
        id: json['id']?.toString() ?? '',
        partyName: json['partyName']?.toString() ?? '',
        details: json['details']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        settled: json['settled'] == true,
      );
}

class SmartLedgerHome extends StatefulWidget {
  const SmartLedgerHome({super.key});

  @override
  State<SmartLedgerHome> createState() => _SmartLedgerHomeState();
}

class _SmartLedgerHomeState extends State<SmartLedgerHome>
    with WidgetsBindingObserver {
  int _currentTab = 0;
  bool _isLoading = true;

  // Koi pre-filled demo data nahi — shuru mein 0 aur empty list
  double _userBudget = 0.0;
  final List<BudgetEntry> _entries = [];
  final List<BillRecord> _bills = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _persistState();
    }
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBudget = prefs.getDouble('saved_user_budget') ?? 0.0;

    final rawEntries = prefs.getString('saved_budget_entries');
    if (rawEntries != null && rawEntries.isNotEmpty) {
      final decoded = jsonDecode(rawEntries) as List<dynamic>;
      _entries
        ..clear()
        ..addAll(
          decoded.map(
            (item) => BudgetEntry.fromJson(item as Map<String, dynamic>),
          ),
        );
    }

    final rawBills = prefs.getString('saved_bill_records');
    if (rawBills != null && rawBills.isNotEmpty) {
      final decodedBills = jsonDecode(rawBills) as List<dynamic>;
      _bills
        ..clear()
        ..addAll(
          decodedBills.map(
            (item) => BillRecord.fromJson(item as Map<String, dynamic>),
          ),
        );
    }

    if (!mounted) return;
    setState(() {
      _userBudget = savedBudget;
      _isLoading = false;
    });
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('saved_user_budget', _userBudget);
    await prefs.setString(
      'saved_budget_entries',
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'saved_bill_records',
      jsonEncode(_bills.map((b) => b.toJson()).toList()),
    );
  }

  double get _totalExpenseAmount =>
      _entries.fold(0.0, (sum, item) => sum + item.amount);

  double get _totalRegularAmount => _entries
      .where((item) => item.kind == EntryKind.regular)
      .fold(0.0, (sum, item) => sum + item.amount);

  Future<void> _showBudgetInputDialog() async {
    final controller = TextEditingController(
      text: _userBudget > 0 ? _userBudget.toStringAsFixed(0) : '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apna Budget Likhein'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Budget Amount',
            hintText: 'Apni marzi ka budget likhein',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed != null && parsed >= 0) {
                setState(() => _userBudget = parsed);
                await _persistState();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEntryFormDialog({
    BudgetEntry? existing,
    bool defaultRegular = false,
  }) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(0) : '',
    );
    final categoryController = TextEditingController(
      text: existing?.category ?? 'General',
    );

    EntryKind selectedKind = existing?.kind ??
        (defaultRegular ? EntryKind.regular : EntryKind.expense);
    String selectedFreq = existing?.frequency ??
        (selectedKind == EntryKind.regular ? 'Monthly' : 'One-time');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            existing == null ? 'Naya Expense Add Karein' : 'Expense Edit Karein',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Naam / Title',
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
                const SizedBox(height: 10),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<EntryKind>(
                  value: selectedKind,
                  decoration: const InputDecoration(
                    labelText: 'Expense Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: EntryKind.expense,
                      child: Text('Normal Expense'),
                    ),
                    DropdownMenuItem(
                      value: EntryKind.regular,
                      child: Text('Regular Expense'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() {
                        selectedKind = value;
                        if (value == EntryKind.regular &&
                            selectedFreq == 'One-time') {
                          selectedFreq = 'Monthly';
                        } else if (value == EntryKind.expense) {
                          selectedFreq = 'One-time';
                        }
                      });
                    }
                  },
                ),
                if (selectedKind == EntryKind.regular) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedFreq == 'One-time' ? 'Monthly' : selectedFreq,
                    decoration: const InputDecoration(
                      labelText: 'Regular Interval',
                      border: OutlineInputBorder(),
                    ),
                    items: const ['Daily', 'Weekly', 'Monthly']
                        .map(
                          (freq) =>
                              DropdownMenuItem(value: freq, child: Text(freq)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => selectedFreq = value);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final amount = double.tryParse(amountController.text.trim());
                final category = categoryController.text.trim().isEmpty
                    ? 'General'
                    : categoryController.text.trim();

                if (title.isNotEmpty && amount != null && amount > 0) {
                  final updatedItem = BudgetEntry(
                    id: existing?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    category: category,
                    amount: amount,
                    kind: selectedKind,
                    frequency:
                        selectedKind == EntryKind.regular ? selectedFreq : 'One-time',
                  );

                  setState(() {
                    if (existing == null) {
                      _entries.insert(0, updatedItem);
                    } else {
                      final index =
                          _entries.indexWhere((item) => item.id == existing.id);
                      if (index != -1) {
                        _entries[index] = updatedItem;
                      }
                    }
                  });
                  await _persistState();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBillFormDialog() async {
    final partyController = TextEditingController();
    final detailsController = TextEditingController();
    final amountController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Naya Invoice Add Karein'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: partyController,
              decoration: const InputDecoration(
                labelText: 'Client / Customer Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: detailsController,
              decoration: const InputDecoration(
                labelText: 'Details',
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final party = partyController.text.trim();
              final amount = double.tryParse(amountController.text.trim());
              if (party.isNotEmpty && amount != null && amount > 0) {
                setState(() {
                  _bills.insert(
                    0,
                    BillRecord(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      partyName: party,
                      details: detailsController.text.trim(),
                      amount: amount,
                      settled: false,
                    ),
                  );
                });
                await _persistState();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMenu() {
    final remaining = _userBudget - _totalExpenseAmount;
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
                      'Apna Budget',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: _showBudgetInputDialog,
                      child: Text(_userBudget > 0 ? 'Edit Budget' : 'Set Budget'),
                    ),
                  ],
                ),
                Text(
                  _userBudget.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Total Spent: ${_totalExpenseAmount.toStringAsFixed(0)}'),
                Text('Regular Expenses: ${_totalRegularAmount.toStringAsFixed(0)}'),
                Text(
                  'Remaining: ${remaining.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: remaining < 0 ? Colors.red : Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Abhi koi expense add nahi hua. + button daba kar apna expense likhein.',
              ),
            ),
          )
        else
          ..._entries.take(5).map(
                (entry) => Card(
                  child: ListTile(
                    title: Text(entry.title),
                    subtitle: Text('${entry.category} • ${entry.frequency}'),
                    trailing: Text(entry.amount.toStringAsFixed(0)),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildEntriesMenu({required bool onlyRegular}) {
    final filtered = onlyRegular
        ? _entries.where((item) => item.kind == EntryKind.regular).toList()
        : _entries;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                onlyRegular
                    ? 'Koi regular expense add nahi hua.'
                    : 'Koi expense add nahi hua.',
              ),
            ),
          )
        else
          ...filtered.map(
            (entry) => Card(
              child: ListTile(
                title: Text(entry.title),
                subtitle: Text('${entry.category} • ${entry.frequency}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.amount.toStringAsFixed(0)),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEntryFormDialog(existing: entry),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        setState(
                          () => _entries.removeWhere((item) => item.id == entry.id),
                        );
                        await _persistState();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBillsMenu() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_bills.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Koi invoice add nahi hua.'),
            ),
          )
        else
          ..._bills.map(
            (bill) => Card(
              child: CheckboxListTile(
                value: bill.settled,
                title: Text(
                  '${bill.partyName} — ${bill.amount.toStringAsFixed(0)}',
                ),
                subtitle: Text(bill.details.isEmpty ? 'Invoice' : bill.details),
                onChanged: (value) async {
                  setState(() {
                    final idx = _bills.indexWhere((item) => item.id == bill.id);
                    if (idx != -1) {
                      _bills[idx] = BillRecord(
                        id: bill.id,
                        partyName: bill.partyName,
                        details: bill.details,
                        amount: bill.amount,
                        settled: value ?? false,
                      );
                    }
                  });
                  await _p
