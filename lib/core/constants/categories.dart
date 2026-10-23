import 'package:flutter/material.dart';

class CategoryInfo {
  final String name;
  final IconData icon;
  const CategoryInfo(this.name, this.icon);
}

const expenseCategories = [
  CategoryInfo('Food', Icons.restaurant),
  CategoryInfo('Transport', Icons.directions_bus),
  CategoryInfo('Shopping', Icons.shopping_bag),
  CategoryInfo('Bills', Icons.receipt_long),
  CategoryInfo('Health', Icons.favorite),
  CategoryInfo('Education', Icons.school),
  CategoryInfo('Other', Icons.more_horiz),
];

const incomeCategories = [
  CategoryInfo('Salary', Icons.payments),
  CategoryInfo('Allowance', Icons.account_balance_wallet),
  CategoryInfo('Freelance', Icons.laptop_mac),
  CategoryInfo('Other', Icons.more_horiz),
];

CategoryInfo findCategory(String name) {
  return [...expenseCategories, ...incomeCategories].firstWhere(
    (c) => c.name == name,
    orElse: () => const CategoryInfo('Other', Icons.more_horiz),
  );
}