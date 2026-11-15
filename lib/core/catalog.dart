class Opening {
  final String name, eco, description, lesson;
  final List<String> moves;
  const Opening(this.name, this.eco, this.description, this.lesson, this.moves);
}

const openings = [
  Opening(
    'Italian Game',
    'C50',
    'A natural home for your pieces.',
    'Develop quickly, protect e4, and prepare to castle. After the line, explore human responses.',
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5'],
  ),
  Opening(
    'Queen’s Gambit',
    'D30',
    'Build a lasting foothold in the center.',
    'Offer the c-pawn to challenge Black’s center. Develop before trying to win the pawn back.',
    ['d2d4', 'd7d5', 'c2c4', 'e7e6', 'b1c3', 'g8f6'],
  ),
  Opening(
    'London System',
    'D02',
    'A sturdy setup, one move at a time.',
    'Develop the dark-squared bishop before e3. Support your center and watch for ...c5.',
    ['d2d4', 'd7d5', 'g1f3', 'g8f6', 'c1f4', 'e7e6', 'e2e3', 'f8d6'],
  ),
  Opening(
    'Sicilian Defense',
    'B20',
    'An unbalanced game from move one.',
    'White develops and opens the center; Black trades a flank pawn for central influence.',
    ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4', 'c5d4', 'f3d4', 'g8f6'],
  ),
  Opening(
    'Caro–Kann',
    'B10',
    'A solid center with room to grow.',
    'Challenge e4 with ...d5, then develop the light-squared bishop before closing it in.',
    ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'b1c3', 'd5e4', 'c3e4', 'c8f5'],
  ),
  Opening(
    'Ruy Lopez',
    'C60',
    'Pressure now, possibilities later.',
    'The bishop pressures the defender of e5. Castle and build patiently instead of rushing to capture.',
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6', 'b5a4', 'g8f6'],
  ),

  Opening(
    'French Defense · Advance',
    'C02',
    '',
    'Gain space with e5; Black challenges the chain with ...c5.',
    ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'e4e5', 'c7c5', 'c2c3', 'b8c6'],
  ),
  Opening(
    'Sicilian · Najdorf',
    'B90',
    '',
    'Develop actively while Black prepares ...e5 or ...e6.',
    [
      'e2e4',
      'c7c5',
      'g1f3',
      'd7d6',
      'd2d4',
      'c5d4',
      'f3d4',
      'g8f6',
      'b1c3',
      'a7a6',
    ],
  ),
  Opening(
    'Sicilian · Dragon',
    'B70',
    '',
    'Black fianchettoes the bishop; White chooses a castling plan.',
    [
      'e2e4',
      'c7c5',
      'g1f3',
      'd7d6',
      'd2d4',
      'c5d4',
      'f3d4',
      'g8f6',
      'b1c3',
      'g7g6',
    ],
  ),
  Opening(
    'Caro–Kann · Advance',
    'B12',
    '',
    'White claims space. Black develops the bishop before ...e6.',
    ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'e4e5', 'c8f5'],
  ),
  Opening(
    'Scandinavian Defense',
    'B01',
    '',
    'Black gives up time with the queen in return for an open center.',
    ['e2e4', 'd7d5', 'e4d5', 'd8d5', 'b1c3', 'd5a5'],
  ),
  Opening(
    'Scotch Game',
    'C45',
    '',
    'Challenge e5 immediately and use the open center to develop.',
    ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'd2d4', 'e5d4', 'f3d4'],
  ),
  Opening(
    'Petrov Defense',
    'C42',
    '',
    'Black counterattacks e4 instead of defending e5.',
    ['e2e4', 'e7e5', 'g1f3', 'g8f6', 'f3e5', 'd7d6', 'e5f3', 'f6e4'],
  ),
  Opening(
    'Vienna Game',
    'C25',
    '',
    'Develop the queen’s knight and choose between f4 and quiet development.',
    ['e2e4', 'e7e5', 'b1c3', 'g8f6', 'f1c4', 'b8c6'],
  ),
  Opening(
    'King’s Gambit',
    'C30',
    '',
    'White offers the f-pawn to build a center and attack.',
    ['e2e4', 'e7e5', 'f2f4', 'e5f4', 'g1f3', 'g7g5'],
  ),
  Opening(
    'Queen’s Gambit · Accepted',
    'D20',
    '',
    'White builds the center and recovers the pawn through development.',
    ['d2d4', 'd7d5', 'c2c4', 'd5c4', 'g1f3', 'g8f6', 'e2e3', 'e7e6'],
  ),
  Opening(
    'Slav Defense',
    'D10',
    '',
    'Support d5 with ...c6 while keeping the light-squared bishop free.',
    ['d2d4', 'd7d5', 'c2c4', 'c7c6', 'g1f3', 'g8f6', 'b1c3', 'd5c4'],
  ),
  Opening(
    'King’s Indian Defense',
    'E60',
    '',
    'White occupies the center; Black develops behind it and prepares a break.',
    ['d2d4', 'g8f6', 'c2c4', 'g7g6', 'b1c3', 'f8g7', 'e2e4', 'd7d6'],
  ),
  Opening(
    'Nimzo-Indian Defense',
    'E20',
    '',
    'The pin on c3 contests e4 and offers a trade of bishop for knight.',
    ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'b1c3', 'f8b4'],
  ),
  Opening(
    'Grünfeld Defense',
    'D80',
    '',
    'Black allows a pawn center and attacks it with pieces and ...c5.',
    ['d2d4', 'g8f6', 'c2c4', 'g7g6', 'b1c3', 'd7d5'],
  ),
  Opening(
    'English Opening',
    'A20',
    '',
    'Control d5 from the flank and keep the central pawn structure flexible.',
    ['c2c4', 'e7e5', 'b1c3', 'g8f6', 'g2g3', 'd7d5'],
  ),
  Opening(
    'Réti Opening',
    'A09',
    '',
    'Develop before committing the center; challenge d5 with c4.',
    ['g1f3', 'd7d5', 'c2c4', 'e7e6', 'g2g3', 'g8f6'],
  ),
];

class Drill {
  final String name, category, fen, lesson;
  final bool white;
  const Drill(
    this.name,
    this.category,
    this.fen,
    this.lesson, {
    this.white = true,
  });
}

const drills = [
  Drill(
    'Build the bridge',
    'Lucena position',
    '1K6/1P1k4/8/8/8/8/r7/4R3 w - - 0 1',
    'Your king is in front of the pawn on the seventh rank. Use your rook to shelter the king from checks, then promote.',
  ),
  Drill(
    'Hold the sixth rank',
    'Philidor defense',
    '8/4k3/r7/4K3/4P3/8/8/7R b - - 0 1',
    'Defend as Black. Keep the rook on your sixth rank until the pawn advances; then check from behind.',
    white: false,
  ),
  Drill(
    'King & rook',
    'Essential checkmate',
    '8/8/4k3/8/8/3K4/8/R7 w - - 0 1',
    'Cut off the opposing king. Bring your king closer and shrink the box. Avoid stalemate.',
  ),
  Drill(
    'King & queen',
    'Essential checkmate',
    '8/8/4k3/8/8/3K4/8/Q7 w - - 0 1',
    'Use the queen to restrict the king, then bring your king in. Leave your opponent a legal move until mate.',
  ),
  Drill(
    'The opposition',
    'Pawn ending',
    '8/4k3/8/4K3/4P3/8/8/8 w - - 0 1',
    'Learn when to use the pawn as a waiting move. Get your king ahead of the pawn and take the opposition.',
  ),
  Drill(
    'Make the extra piece count',
    'Conversion • +3 material',
    'r2r2k1/pp3ppp/2p5/8/3P4/2N5/PP3PPP/R2R2K1 w - - 0 1',
    'You have an extra knight. Improve your least active piece, keep pawns safe, and trade when it simplifies the win.',
  ),
];
