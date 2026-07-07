import 'package:avogs/core/api/api_client.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(
    api: ref.watch(apiClientProvider),
    storeCode: ref.watch(appConfigProvider).selectedStoreCode,
  );
});

class InventoryBalanceItem {
  const InventoryBalanceItem({
    required this.stockId,
    required this.name,
    required this.available,
  });

  factory InventoryBalanceItem.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'] as String? ?? '';
    return InventoryBalanceItem(
      stockId: stockId,
      name: _friendlyName(stockId),
      available: _asInt(json['available']),
    );
  }

  final String stockId;
  final String name;
  final int available;
}

class InventorySnapshot {
  const InventorySnapshot({
    required this.store,
    required this.date,
    required this.shift,
    required this.avocadoPool,
    required this.items,
  });

  factory InventorySnapshot.fromJson(Map<String, dynamic> json) {
    return InventorySnapshot(
      store: json['store'] as String? ?? '',
      date: json['date'] as String? ?? '',
      shift: json['shift'] as String? ?? 'morning',
      avocadoPool: _asInt(json['avocado_pool']),
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(InventoryBalanceItem.fromJson)
          .toList(),
    );
  }

  final String store;
  final String date;
  final String shift;
  final int avocadoPool;
  final List<InventoryBalanceItem> items;

  List<InventoryCategory> get categories {
    final beverages = items.where((i) => i.stockId.startsWith('BVG-')).toList();
    final honey = items.where((i) => i.stockId.startsWith('HNY-')).toList();

    return [
      InventoryCategory(
        title: 'Avocados',
        icon: Icons.eco_outlined,
        unit: 'pcs',
        items: [
          InventoryBalanceItem(
            stockId: 'AVO-POOL',
            name: 'Available pool (all sizes)',
            available: avocadoPool,
          ),
        ],
      ),
      if (beverages.isNotEmpty)
        InventoryCategory(
          title: 'Beverages',
          icon: Icons.local_drink_outlined,
          unit: 'btl',
          items: beverages,
        ),
      if (honey.isNotEmpty)
        InventoryCategory(
          title: 'Honey',
          icon: Icons.hive_outlined,
          unit: 'jars',
          items: honey,
        ),
    ];
  }
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

  int get total => items.fold(0, (sum, item) => sum + item.available);
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String _friendlyName(String stockId) {
  return switch (stockId) {
    'BVG-JUICE' => 'Juice',
    'BVG-SMOOTHIE' => 'Smoothie',
    'BVG-GINGER' => 'Ginger',
    'HNY-250G' => 'Honey 250g',
    'HNY-450G' => 'Honey 450g',
    'HNY-900G' => 'Honey 900g',
    _ => stockId,
  };
}

class InventoryRepository {
  InventoryRepository({required ApiClient api, required String? storeCode})
      : _api = api,
        _storeCode = storeCode;

  final ApiClient _api;
  final String? _storeCode;

  Future<InventorySnapshot> fetchBalances() async {
    final query = <String, dynamic>{};
    if (_storeCode != null && _storeCode!.isNotEmpty) {
      query['store'] = _storeCode;
    }
    final data = await _api.getJson('/inventory', queryParameters: query);
    return InventorySnapshot.fromJson(data);
  }
}

final inventoryBalancesProvider = FutureProvider<InventorySnapshot>((ref) async {
  return ref.watch(inventoryRepositoryProvider).fetchBalances();
});
