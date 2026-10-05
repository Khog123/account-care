import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../services/business_service.dart';
import 'database_provider.dart';

final businessServiceProvider = Provider<BusinessService>((ref) {
  final database = ref.watch(databaseProvider);

  return BusinessService(database);
});

final businessListProvider = FutureProvider<List<BusinessesData>>((ref) async {
  final database = ref.watch(databaseProvider);

  return database.select(database.businesses).get();
});

final activeBusinessIdProvider =
    NotifierProvider<ActiveBusinessIdNotifier, String?>(
  ActiveBusinessIdNotifier.new,
);

class ActiveBusinessIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    return null;
  }

  void setBusinessId(String businessId) {
    state = businessId;
  }

  void clearBusiness() {
    state = null;
  }
}

final activeUserIdProvider =
    NotifierProvider<ActiveUserIdNotifier, String?>(
  ActiveUserIdNotifier.new,
);

class ActiveUserIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    return null;
  }

  void setUserId(String userId) {
    state = userId;
  }

  void clearUser() {
    state = null;
  }
}