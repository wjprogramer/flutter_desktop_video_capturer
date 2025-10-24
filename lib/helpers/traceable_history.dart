class TraceableHistory<T> {
  final List<T> _history = [];
  int _currentIndex = -1;

  void add(T item) {
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }
    _history.add(item);
    _currentIndex++;
  }

  T? undo() {
    if (canUndo) {
      _currentIndex--;
      return _history[_currentIndex];
    }
    return null;
  }

  T? redo() {
    if (canRedo) {
      _currentIndex++;
      return _history[_currentIndex];
    }
    return null;
  }

  bool get canUndo => _currentIndex > 0;

  bool get canRedo => _currentIndex < _history.length - 1;

  T? get current => _currentIndex >= 0 ? _history[_currentIndex] : null;
}