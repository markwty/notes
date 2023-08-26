import 'package:flutter/material.dart';

class ListModel<E> {
  final GlobalKey<AnimatedListState> listKey;
  final dynamic removedItemBuilder;
  List<E> items;

  ListModel({
    @required this.listKey, @required this.removedItemBuilder, Iterable<E> initialItems,
  }) : assert(listKey != null), assert(removedItemBuilder != null), items = List<E>.from(initialItems ?? <E>[]);

  AnimatedListState get _animatedList => listKey.currentState;

  void clear() {
    for (int index = items.length - 1; index >= 0; index--) {
      removeAt(index);
    }
  }

  void add(E item) {
    items.add(item);
    _animatedList.insertItem(items.length - 1);
  }

  void insert(int index, E item) {
    items.insert(index, item);
    _animatedList.insertItem(index);
  }

  E removeAt(int index) {
    final E removedItem = items.removeAt(index);
    if (removedItem != null) {
      _animatedList.removeItem(
        index,
            (BuildContext context, Animation<double> animation) => removedItemBuilder(removedItem, context, animation),
      );
    }
    return removedItem;
  }

  int get length => items.length;

  E operator [](int index) => items[index];

  int indexOf(E item) => items.indexOf(item);
}