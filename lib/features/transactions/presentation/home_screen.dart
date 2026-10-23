import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/transaction.dart';

final _dummy = [
  AppTransaction(id: 1, amount: 85000, type: TransactionType.income, category: 'Salary', note: 'Internship allowance', date: DateTime.now()),
  AppTransaction(id: 2, amount: 1200, type: TransactionType.expense, category: 'Food', note: 'Lunch', date: DateTime.now()),
  AppTransaction(id: 3, amount: 450, type: TransactionType.expense, category: 'Transport', note: 'Bus fare', date: DateTime.now()),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'LKR ', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(title: const Text('Spendly')),
      body: ListView.separated(
        itemCount: _dummy.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final t = _dummy[i];
          final isIncome = t.type == TransactionType.income;
          return ListTile(
            leading: CircleAvatar(
              child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward),
            ),
            title: Text(t.category),
            subtitle: Text(t.note),
            trailing: Text(
              '${isIncome ? '+' : '-'}${fmt.format(t.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}