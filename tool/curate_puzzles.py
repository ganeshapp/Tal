#!/usr/bin/env python3
"""Curate a small, rating-balanced CC0 offline library from Lichess's export."""
import csv, io, json, pathlib, subprocess, hashlib, datetime, collections
import chess
ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = 'https://database.lichess.org/lichess_db_puzzle.csv.zst'
curl = subprocess.Popen(['curl', '-L', '--fail', '--silent', '--show-error', URL], stdout=subprocess.PIPE)
zstd = subprocess.Popen(['zstd', '-dc'], stdin=curl.stdout, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
curl.stdout.close()
counts = [0] * 14
quotas = [1500] * 12 + [1000, 50]
puzzles = []
values = {chess.PAWN:100,chess.KNIGHT:300,chess.BISHOP:300,chess.ROOK:500,chess.QUEEN:900,chess.KING:0}
try:
    for row in csv.DictReader(io.TextIOWrapper(zstd.stdout)):
        rating = int(row['Rating'])
        if not 400 <= rating < 3200 or int(row['Popularity']) < 85 or int(row['NbPlays']) < 100 or int(row['RatingDeviation']) > 110:
            continue
        bucket = (rating-400)//200
        if counts[bucket] >= quotas[bucket]: continue
        moves = row['Moves'].split()
        if len(moves) < 2: continue
        board = chess.Board(row['FEN'])
        themes = row['Themes'].split()
        captures = []
        queen_captures = []
        valid = True
        for i, uci in enumerate(moves):
            move = chess.Move.from_uci(uci)
            if move not in board.legal_moves:
                valid = False; break
            victim = board.piece_at(move.to_square)
            captures.append(values[victim.piece_type] if victim else 0)
            if i > 1 and i % 2 == 0 and victim and victim.piece_type == chess.QUEEN:
                queen_captures.append(i)
            board.push(move)
        if not valid: continue
        if len(moves) >= 6: themes.append('multiMove')
        if 'sacrifice' in themes and any(captures[i-1] + (captures[i+1] if i+1<len(captures) else 0) < 900 for i in queen_captures):
            themes.append('queenSacrifice')
        puzzles.append({'id':row['PuzzleId'],'fen':row['FEN'],'moves':moves,'rating':rating,'deviation':int(row['RatingDeviation']),'themes':themes,'opening':row.get('OpeningTags',''),'url':row['GameUrl']})
        counts[bucket] += 1
        if len(puzzles)%1500 == 0: print(len(puzzles),counts,flush=True)
        if counts == quotas: break
finally:
    zstd.terminate(); curl.terminate()
    zstd.wait(); curl.wait()
assert counts == quotas, counts
puzzles.sort(key=lambda p:p['id'])
payload=json.dumps(puzzles,separators=(',',':')).encode()
(ROOT/'assets/data/puzzles.json').write_bytes(payload)
manifest={'source':URL,'retrieved':str(datetime.date.today()),'license':'CC0-1.0','records':len(puzzles),'rating_min':400,'rating_max':3199,'popularity_min':85,'plays_min':100,'rating_deviation_max':110,'per_200_rating_band':quotas,'bands':counts,'themes':dict(sorted(collections.Counter(t for p in puzzles for t in p['themes']).items())),'sha256':hashlib.sha256(payload).hexdigest(),'bytes':len(payload),'derived_tags':{'multiMove':'At least 3 solver moves','queenSacrifice':'Source sacrifice theme; solver queen captured in the line with less than queen value recaptured immediately'}}
(ROOT/'assets/data/puzzles_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest),flush=True)
