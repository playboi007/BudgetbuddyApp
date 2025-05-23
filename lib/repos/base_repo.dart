///this file will define the contracts for all data operations
abstract class BaseRepo<T> {
  Future<T> get(String id);
  Future<List<T>> getAll();
  Future<void> add(T item);
  Future<void> update(String id, T item);
  Future<void> delete(String id);
}
