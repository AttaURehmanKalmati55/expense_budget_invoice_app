import 'package:flutter/material.dart';

void main() {
  runApp(const ExpenseBudgetInvoiceApp());
}

class ExpenseBudgetInvoiceApp extends StatelessWidget {
  const ExpenseBudgetInvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense, Budget & Invoice Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0F766E),
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class TransactionItem {
  final String title;
  final String category;
  final double amount;
  final bool isIncome;
  final DateTime date;

  TransactionItem({
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.date,
  });
}

class InvoiceEntry {
  final String invoiceNo;
  final String clientName;
  final String itemDescription;
  final int quantity;
  final double unitPrice;
  final DateTime date;

  InvoiceEntry({
    required this.invoiceNo,
    required this.clientName,
    required this.itemDescription,
    required this.quantity,
    required this.unitPrice,
    required this.date,
  });

  double get total => quantity * unitPrice;
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<TransactionItem> _transactions = [
    TransactionItem(
      title: 'Freelance Web Design',
      category: 'Income',
      amount: 25000,
      isIncome: true,
      date: DateTime.now(),
    ),
    TransactionItem(
      title: 'Grocery & Food',
      category: 'Food',
      amount: 4500,
      isIncome: false,
      date: DateTime.now(),
    ),
    TransactionItem(
      title: 'Internet & Electricity',
      category: 'Bills',
      amount: 6200,
      isIncome: false,
      date: DateTime.now(),
    ),
  ];

  final Map<String, double> _categoryBudgets = {
    'Food': 10000,
    'Bills': 8000,
    'Transport': 5000,
    'Shopping': 7000,
  };

  final List<InvoiceEntry> _invoices = [
    InvoiceEntry(
      invoiceNo: 'INV-1001',
      clientName: 'Al-Madina Traders',
      itemDescription: 'Mobile App UI Prototype',
      quantity: 1,
      unitPrice: 15000,
      date: DateTime.now(),
    ),
  ];

  double get _totalIncome => _transactions
      .where((t) => t.isIncome)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get _totalExpense => _transactions
      .where((t) => !t.isIncome)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get _balance => _totalIncome - _totalExpense;

  double _spentInCategory(String category) {
    return _transactions
        .where((t) => !t.isIncome && t.category == category)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  void _openAddTransactionSheet() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedCategory = 'Food';
    bool isIncome = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add Transaction',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Expense')),
                      ButtonSegment(value: true, label: Text('Income')),
                    ],
                    selected: {isIncome},
                    onSelectionChanged: (val) {
                      setModalState(() {
                        isIncome = val.first;
                        selectedCategory = isIncome ? 'Income' : 'Food';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title (e.g. Lunch, Salary)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (PKR)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isIncome)
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categoryBudgets.keys
                          .map((cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedCategory = val);
                        }
                      },
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (titleCtrl.text.trim().isEmpty ||
                          amount == null ||
                          amount <= 0) {
                        return;
                      }
                      setState(() {
                        _transactions.insert(
                          0,
                          TransactionItem(
                            title: titleCtrl.text.trim(),
                            category: isIncome ? 'Income' : selectedCategory,
                            amount: amount,
                            isIncome: isIncome,
                            date: DateTime.now(),
                          ),
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save Transaction'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCreateInvoiceSheet() {
    final clientCtrl = TextEditingController();
    final itemCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create New Invoice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientCtrl,
                decoration: const InputDecoration(
                  labelText: 'Client / Customer Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: itemCtrl,
                decoration: const InputDecoration(
                  labelText: 'Service / Item Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Unit Price (PKR)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                  final price = double.tryParse(priceCtrl.text.trim());
                  if (clientCtrl.text.trim().isEmpty ||
                      itemCtrl.text.trim().isEmpty ||
                      price == null ||
                      price <= 0) {
                    return;
                  }
                  setState(() {
                    _invoices.insert(
                      0,
                      InvoiceEntry(
                        invoiceNo: 'INV-${1001 + _invoices.length}',
                        clientName: clientCtrl.text.trim(),
                        itemDescription: itemCtrl.text.trim(),
                        quantity: qty,
                        unitPrice: price,
                        date: DateTime.now(),
                      ),
                    );
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Generate Invoice'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInvoicePreview(InvoiceEntry invoice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Invoice ${invoice.invoiceNo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${invoice.clientName}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Text('Item: ${invoice.itemDescription}'),
            Text('Quantity: ${invoice.quantity}'),
            Text('Unit Price: PKR ${invoice.unitPrice.toStringAsFixed(0)}'),
            const Divider(),
            Text(
              'Total Payable: PKR ${invoice.total.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF115E59)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 6),
              Text(
                'PKR ${_balance.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Income: +PKR ${_totalIncome.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.greenAccent)),
                  Text('Expense: -PKR ${_totalExpense.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.orangeAccent)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Recent Transactions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ..._transactions.map((tx) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: tx.isIncome
                    ? Colors.green.withOpacity(0.15)
                    : Colors.red.withOpacity(0.15),
                child: Icon(
                  tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: tx.isIncome ? Colors.green : Colors.red,
                ),
              ),
              title: Text(tx.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(tx.category),
              trailing: Text(
                '${tx.isIncome ? '+' : '-'}PKR ${tx.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: tx.isIncome ? Colors.green : Colors.red,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBudgetsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Monthly Category Budgets',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._categoryBudgets.entries.map((entry) {
          final spent = _spentInCategory(entry.key);
          final limit = entry.value;
          final ratio = (spent / limit).clamp(0.0, 1.0);
          final isOver = spent > limit;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        'PKR ${spent.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isOver ? Colors.red : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    color: isOver
                        ? Colors.red
                        : (ratio > 0.75 ? Colors.orange : Colors.teal),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInvoicesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Invoices & Receipts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            FilledButton.icon(
              onPressed: _openCreateInvoiceSheet,
              icon: const Icon(Icons.add),
              label: const Text('New Invoice'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._invoices.map((inv) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
              title: Text('${inv.invoiceNo} • ${inv.clientName}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(inv.itemDescription),
              trailing: Text(
                'PKR ${inv.total.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
              ),
              onTap: () => _showInvoicePreview(inv),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboardTab(),
      _buildBudgetsTab(),
      _buildInvoicesTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartLedger Tracker'),
        centerTitle: false,
      ),
      body: pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openAddTransactionSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart),
              label: 'Budgets'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Invoices'),
        ],
      ),
    );
  }
}
