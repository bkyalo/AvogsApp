import 'package:avogs/core/api/api_client.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/transactions/transaction_repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InventoryBalanceItem {
  const InventoryBalanceItem({
    required this.stockId,
    required this.name,
    required this.available,
    this.units = '',
    this.categoryName = 'Other',
  });

  factory InventoryBalanceItem.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'] as String? ?? '';
    return InventoryBalanceItem(
      stockId: stockId,
      name: json['description'] as String? ??
          json['name'] as String? ??
          stockId,
      available: _asDouble(json['qoh']),
      units: json['units'] as String? ?? '',
      categoryName: (json['category_name'] as String?)?.trim().isNotEmpty == true
          ? json['category_name'] as String
          : 'Other',
    );
  }

  final String stockId;
  final String name;
  final double available;
  final String units;
  final String categoryName;

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        stockId.toLowerCase().contains(q) ||
        categoryName.toLowerCase().contains(q);
  }
}

class InventorySnapshot {
  const InventorySnapshot({
    required this.location,
    required this.date,
    required this.items,
  });

  final String location;
  final String date;
  final List<InventoryBalanceItem> items;

  List<InventoryCategory> categoriesForQuery(String query) {
    final filtered = query.isEmpty
        ? items
        : items.where((i) => i.matchesQuery(query)).toList();
    if (filtered.isEmpty) return [];

    final grouped = <String, List<InventoryBalanceItem>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.categoryName, () => []).add(item);
    }

    final categories = grouped.entries
        .map(
          (e) => InventoryCategory(
            title: e.key,
            icon: _iconForCategory(e.key),
            unit: _unitLabel(e.value),
            items: e.value
              ..sort((a, b) => a.name.compareTo(b.name)),
          ),
        )
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    return categories;
  }

  double get totalOnHand =>
      items.fold(0.0, (sum, item) => sum + item.available);
}

class InventoryCategory {
  const InventoryCategory({
    required this.title,
    required this.icon,
    required this.unit,
    required this.items,
  });

  final String title;
  final IconData icon;
  final String unit;
  final List<InventoryBalanceItem> items;

  double get total =>
      items.fold(0.0, (sum, item) => sum + item.available);
}

double _asDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

IconData _iconForCategory(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('avocado') || lower.contains('produce')) {
    return Icons.eco_outlined;
  }
  if (lower.contains('beverage') || lower.contains('drink')) {
    return Icons.local_drink_outlined;
  }
  if (lower.contains('honey')) return Icons.hive_outlined;
  return Icons.inventory_2_outlined;
}

String _unitLabel(List<InventoryBalanceItem> items) {
  final units = items.map((i) => i.units).where((u) => u.isNotEmpty).toSet();
  if (units.length == 1) return units.first;
  return 'units';
}

class InventoryRepository {
  InventoryRepository(this._api, this._adjustments);

  final ApiClient _api;
  final AdjustmentRepository _adjustments;

  /// FA stock on hand for the selected location (`GET /items?location=`).
  Future<InventorySnapshot> fetchBalances({required String location}) async {
    try {
      final data = await _api.getJsonList(
        '/items',
        queryParameters: {'location': location},
      );
      final items = data
          .whereType<Map<String, dynamic>>()
          .map(InventoryBalanceItem.fromJson)
          .toList();
      if (items.isNotEmpty) {
        return _snapshot(location, items);
      }
    } catch (_) {}

    // Fallback: adjustment prefill catalog carries QOH for all stock items.
    final prefill = await _adjustments.fetchPrefill(location: location);
    final items = prefill.catalog
        .map(
          (item) => InventoryBalanceItem(
            stockId: item.stockId,
            name: item.description,
            available: item.qoh ?? 0,
            units: item.units,
          ),
        )
        .toList();

    return _snapshot(location, items);
  }

  InventorySnapshot _snapshot(
    String location,
    List<InventoryBalanceItem> items,
  ) {
    items.sort((a, b) => a.name.compareTo(b.name));
    return InventorySnapshot(
      location: location,
      date: DateTime.now().toIso8601String().split('T').first,
      items: items,
    );
  }
}

final inventoryBalancesProvider = FutureProvider<InventorySnapshot>((ref) async {
  await ref.read(appConfigProvider.notifier).ready;
  var location = ref.read(appConfigProvider).selectedStoreCode;

  if (location == null || location.isEmpty) {
    try {
      final stores = await ref.read(storesProvider.future);
      if (stores.isNotEmpty) {
        location = stores.first.code;
      }
    } catch (_) {}
  }

  if (location == null || location.isEmpty) {
    throw Exception('Select a store in Settings to view stock balances');
  }

  return ref.read(inventoryRepositoryProvider).fetchBalances(location: location);
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(
    ref.watch(apiClientProvider),
    ref.watch(adjustmentRepositoryProvider),
  );
});
