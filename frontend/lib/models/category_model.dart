import 'package:flutter/material.dart';

class CategoryModel {
  final int id;
  final int? userId;
  final String name;
  final String type; // 'income' or 'expense'
  final String color;
  final String icon;

  const CategoryModel({
    required this.id,
    this.userId,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      userId: json['user_id'] != null ? json['user_id'] as int : null,
      name: (json['name'] as String?) ?? 'Kategori',
      type: (json['type'] as String?) ?? 'expense',
      color: (json['color'] as String?) ?? '#10B981',
      icon: (json['icon'] as String?) ?? 'tag',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': type,
      'color': color,
      'icon': icon,
    };
  }

  IconData get iconData {
    switch (icon.toLowerCase()) {
      case 'utensils':
      case 'food':
        return Icons.restaurant_rounded;
      case 'car':
      case 'transport':
        return Icons.directions_car_rounded;
      case 'receipt':
      case 'bill':
        return Icons.receipt_long_rounded;
      case 'shopping-bag':
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'heart-pulse':
      case 'health':
        return Icons.favorite_rounded;
      case 'graduation-cap':
      case 'education':
        return Icons.school_rounded;
      case 'gamepad-2':
      case 'entertainment':
        return Icons.sports_esports_rounded;
      case 'briefcase':
      case 'salary':
        return Icons.work_rounded;
      case 'trending-up':
      case 'investment':
        return Icons.trending_up_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'store':
        return Icons.storefront_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color get colorValue {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }
}
