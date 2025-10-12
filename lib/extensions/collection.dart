extension IterableX<T> on Iterable<T> {
  List<T> joinWith(T separator) {
    if (isEmpty) {
      return [];
    }
    final result = <T>[];
    for (T element in this) {
      result.add(element);
      result.add(separator);
    }
    result.removeLast();
    return result;
  }

  K? firstWhereTypeOrNull<K extends T>() {
    for (T element in this) {
      if (element is K) {
        return element;
      }
    }
    return null;
  }

  Iterable<T> repeat(int times) sync* {
    for (int i = 0; i < times; i++) {
      yield* this;
    }
  }
}

extension ListX<T> on List<T> {
  /// Returns the index of the last element in the list, or -1 if the list is empty.
  int get lastIndex => length - 1;
}