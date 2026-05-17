List<Map<String, dynamic>> sortedEntitiesForRender(List<Map<String, dynamic>> entities) {
  final sorted = List<Map<String, dynamic>>.from(entities);
  sorted.sort((a, b) {
    final sa = a['sprite'] as Map<String, dynamic>?;
    final sb = b['sprite'] as Map<String, dynamic>?;
    final la = (sa?['sorting_layer'] as num?)?.toInt() ?? 0;
    final lb = (sb?['sorting_layer'] as num?)?.toInt() ?? 0;
    final lr = la.compareTo(lb);
    if (lr != 0) return lr;
    final oa = (sa?['order_in_layer'] as num?)?.toInt() ?? 0;
    final ob = (sb?['order_in_layer'] as num?)?.toInt() ?? 0;
    final or = oa.compareTo(ob);
    if (or != 0) return or;
    final ida = (a['id'] as num?)?.toInt() ?? 0;
    final idb = (b['id'] as num?)?.toInt() ?? 0;
    return ida.compareTo(idb);
  });
  return sorted;
}
