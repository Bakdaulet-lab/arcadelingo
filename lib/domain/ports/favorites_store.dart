/// Локальное избранное для всех уровней, независимо от плана повторения.
abstract class FavoritesStore {
  Set<String> load();
  Future<bool> save(Set<String> wordIds);
}
