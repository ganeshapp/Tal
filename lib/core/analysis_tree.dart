import 'chess.dart';

class AnalysisNode {
  final AnalysisNode? parent;
  final String fen;
  final String? move;
  final String san;
  final int? gamePly;
  final List<AnalysisNode> children = [];
  AnalysisNode? preferredChild;
  AnalysisNode({
    required this.fen,
    this.parent,
    this.move,
    this.san = '',
    this.gamePly,
  });
  List<AnalysisNode> get path {
    final nodes = <AnalysisNode>[];
    for (AnalysisNode? n = this; n?.parent != null; n = n.parent) {
      nodes.add(n!);
    }
    return nodes.reversed.toList();
  }

  int get ply => path.length;
}

class AnalysisTree {
  final GameRecord game;
  late final AnalysisNode root;
  final List<AnalysisNode> mainline = [];
  late AnalysisNode current;
  AnalysisTree(this.game) {
    root = AnalysisNode(fen: game.startFen, gamePly: 0);
    mainline.add(root);
    var node = root;
    final sans = game.sans;
    for (var i = 0; i < game.moves.length; i++) {
      final next = AnalysisNode(
        fen: game.fenAt(i + 1),
        parent: node,
        move: game.moves[i],
        san: sans[i],
        gamePly: i + 1,
      );
      node.children.add(next);
      mainline.add(next);
      node = next;
    }
    current = root;
  }
  AnalysisNode? extend(AnalysisNode parent, String move) {
    for (final child in parent.children) {
      if (child.move == move) return child;
    }
    final pos = ChessPosition(fen: parent.fen, chess960: game.chess960);
    if (!pos.legal.contains(move)) return null;
    final san = pos.san(move);
    pos.play(move);
    final node = AnalysisNode(
      fen: pos.fen,
      parent: parent,
      move: move,
      san: san,
    );
    parent.children.add(node);
    return node;
  }

  GameRecord recordAt(AnalysisNode node) => GameRecord(
    id: game.id,
    startFen: game.startFen,
    date: game.date,
    title: game.title,
    rating: game.rating,
    humanWhite: game.humanWhite,
    chess960: game.chess960,
    moves: node.path.map((n) => n.move!).toList(),
  );
}
