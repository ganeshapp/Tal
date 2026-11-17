#!/usr/bin/env python3
import urllib.request, csv, io, json, pathlib, hashlib, concurrent.futures
import chess, chess.pgn
ROOT=pathlib.Path(__file__).resolve().parents[1]
API='https://api.github.com/repos/lichess-org/chess-openings/commits/master'
revision=json.load(urllib.request.urlopen(API))['sha']
def get(letter):
 url=f'https://raw.githubusercontent.com/lichess-org/chess-openings/{revision}/{letter}.tsv'
 data=urllib.request.urlopen(url).read().decode()
 result=[]
 for row in csv.DictReader(io.StringIO(data),delimiter='\t'):
  game=chess.pgn.read_game(io.StringIO(row['pgn']))
  if game.errors:raise ValueError(game.errors)
  board=game.end().board()
  result.append({'name':row['name'],'eco':row['eco'],'fen':' '.join(board.fen().split()[:3]),'moves':[m.uci() for m in game.mainline_moves()]})
 return result
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
 rows=[r for group in pool.map(get,'abcde') for r in group]
payload=json.dumps(rows,separators=(',',':')).encode()
(ROOT/'assets/data/openings.json').write_bytes(payload)
(ROOT/'assets/data/openings_manifest.json').write_text(json.dumps({'source':'https://github.com/lichess-org/chess-openings','revision':revision,'license':'CC0-1.0','records':len(rows),'bytes':len(payload),'sha256':hashlib.sha256(payload).hexdigest()},indent=2)+'\n')
print(len(rows),len(payload),revision)

print('Rebuild the book-move index: dart run tool/build_opening_book.dart')
