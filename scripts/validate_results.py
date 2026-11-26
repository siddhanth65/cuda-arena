import csv, collections, sys
def check(path, expected):
    rows = 0; win = collections.Counter(); moves = collections.Counter(); bad = []; ids_ok = True; seeds=set()
    with open(path, newline='') as f:
        r = csv.DictReader(f)
        assert r.fieldnames == ['game_id','winner','moves','seed'], r.fieldnames
        for i, row in enumerate(r):
            rows += 1
            if int(row['game_id']) != i: ids_ok = False
            w = row['winner']; m = int(row['moves']); win[w] += 1; moves[(w,m)] += 1; seeds.add(row['seed'])
            if w not in ('X','O','DRAW'): bad.append(('winner', i, w))
            elif w == 'X' and m not in (5,7,9): bad.append(('xmoves', i, m))
            elif w == 'O' and m not in (6,8): bad.append(('omoves', i, m))
            elif w == 'DRAW' and m != 9: bad.append(('drawmoves', i, m))
    avg = sum(m*c for (w,m),c in moves.items())/rows
    print(f"{path}: rows={rows} (expected {expected}) ids_sequential={ids_ok} invalid_rows={len(bad)} seeds={sorted(seeds)}")
    print(f"  winners={dict(win)}  avg_moves={avg:.4f}")
    print(f"  (winner,moves) distribution={dict(sorted(moves.items()))}")
    return rows == expected and not bad and ids_ok
ok1 = check('results/tournament_results.csv', 1048576)
ok2 = check('results/smoke.csv', 16384)
print("VALIDATION:", "PASS" if ok1 and ok2 else "FAIL")