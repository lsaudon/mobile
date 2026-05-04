import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/account/account_preferences.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/rate_limit.dart';

const _kScrollAnimationDuration = Duration(milliseconds: 200);
const _kMoveListOpacity = 0.8;
const _kMoveListHeight = 40.0;

enum MoveListType { inline, stacked }

class MoveList extends StatefulWidget {
  const MoveList({
    required this.type,
    required this.slicedMoves,
    required this.currentMoveIndex,
    this.onSelectMove,
  });

  final MoveListType type;
  final Iterable<List<MapEntry<int, String>>> slicedMoves;
  final int currentMoveIndex;
  final void Function(int moveIndex)? onSelectMove;

  @override
  State<MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<MoveList> {
  final currentMoveKey = GlobalKey();
  final _debounce = Debouncer(const Duration(milliseconds: 100));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentMoveKey.currentContext != null) {
        Scrollable.ensureVisible(currentMoveKey.currentContext!, alignment: 0.5);
      }
    });
  }

  @override
  void dispose() {
    _debounce.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MoveList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _debounce(() {
      if (currentMoveKey.currentContext != null) {
        Scrollable.ensureVisible(
          currentMoveKey.currentContext!,
          alignment: 0.5,
          duration: _kScrollAnimationDuration,
          curve: Curves.easeIn,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.type) {
      MoveListType.inline => _InlineMoves(
        slicedMoves: widget.slicedMoves,
        currentMoveKey: currentMoveKey,
        currentMoveIndex: widget.currentMoveIndex,
        onSelectMove: widget.onSelectMove,
      ),
      MoveListType.stacked => _StackedMoves(
        slicedMoves: widget.slicedMoves,
        currentMoveKey: currentMoveKey,
        currentMoveIndex: widget.currentMoveIndex,
        onSelectMove: widget.onSelectMove,
      ),
    };
  }
}

class _InlineMoves extends ConsumerWidget {
  const _InlineMoves({
    required this.slicedMoves,
    required this.currentMoveKey,
    required this.currentMoveIndex,
    required this.onSelectMove,
  });

  final Iterable<List<MapEntry<int, String>>> slicedMoves;
  final GlobalKey<State<StatefulWidget>> currentMoveKey;
  final int currentMoveIndex;
  final void Function(int moveIndex)? onSelectMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pieceNotation = ref
        .watch(pieceNotationProvider)
        .maybeWhen(data: (value) => value, orElse: () => defaultAccountPreferences.pieceNotation);

    return SizedBox(
      height: _kMoveListHeight,
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 5),
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 10,
          children: slicedMoves
              .mapIndexed(
                (index, moves) => Row(
                  children: [
                    _InlineMoveCount(pieceNotation: pieceNotation, count: index + 1),
                    ...moves.map((move) {
                      // cursor index starts at 0, move index starts at 1
                      final isCurrentMove = currentMoveIndex == move.key + 1;
                      return InlineMoveItem(
                        key: isCurrentMove ? currentMoveKey : null,
                        move: move,
                        pieceNotation: pieceNotation,
                        current: isCurrentMove,
                        onSelectMove: onSelectMove,
                      );
                    }),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _InlineMoveCount extends StatelessWidget {
  const _InlineMoveCount({required this.count, required this.pieceNotation});

  final PieceNotation pieceNotation;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count.',
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: textShade(context, _kMoveListOpacity),
        fontFamily: switch (pieceNotation) {
          PieceNotation.symbol => 'ChessFont',
          PieceNotation.letter => null,
        },
      ),
    );
  }
}

class InlineMoveItem extends StatelessWidget {
  const InlineMoveItem({
    required this.move,
    required this.pieceNotation,
    required this.current,
    this.onSelectMove,
    super.key,
  });

  final MapEntry<int, String> move;
  final PieceNotation pieceNotation;
  final bool current;
  final void Function(int moveIndex)? onSelectMove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelectMove != null ? () => onSelectMove!(move.key + 1) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: Text(
          move.value,
          style: TextStyle(
            fontWeight: current ? FontWeight.bold : FontWeight.w500,
            color: current ? ColorScheme.of(context).primary : textShade(context, _kMoveListOpacity),
            fontFamily: switch (pieceNotation) {
              PieceNotation.symbol => 'ChessFont',
              PieceNotation.letter => null,
            },
          ),
        ),
      ),
    );
  }
}

class _StackedMoves extends StatelessWidget {
  const _StackedMoves({
    required this.slicedMoves,
    required this.currentMoveKey,
    required this.currentMoveIndex,
    required this.onSelectMove,
  });

  final Iterable<List<MapEntry<int, String>>> slicedMoves;
  final GlobalKey<State<StatefulWidget>> currentMoveKey;
  final int currentMoveIndex;
  final void Function(int moveIndex)? onSelectMove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: slicedMoves
              .mapIndexed(
                (index, moves) => Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _StackedMoveCount(count: index + 1),
                    Expanded(
                      child: Row(
                        children: [
                          ...moves.map((move) {
                            // cursor index starts at 0, move index starts at 1
                            final isCurrentMove = currentMoveIndex == move.key + 1;
                            return Expanded(
                              child: _StackedMoveItem(
                                key: isCurrentMove ? currentMoveKey : null,
                                move: move,
                                current: isCurrentMove,
                                onSelectMove: onSelectMove,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _StackedMoveCount extends StatelessWidget {
  const _StackedMoveCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40.0,
      child: Text(
        '$count.',
        style: TextStyle(fontWeight: FontWeight.w600, color: textShade(context, _kMoveListOpacity)),
      ),
    );
  }
}

class _StackedMoveItem extends StatelessWidget {
  const _StackedMoveItem({required this.move, required this.current, this.onSelectMove, super.key});

  final MapEntry<int, String> move;
  final bool current;
  final void Function(int moveIndex)? onSelectMove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelectMove != null ? () => onSelectMove!(move.key + 1) : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          move.value,
          style: TextStyle(
            fontWeight: current ? FontWeight.bold : null,
            color: current ? null : textShade(context, _kMoveListOpacity),
          ),
        ),
      ),
    );
  }
}
