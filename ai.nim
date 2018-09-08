import objects
import algorithm
import strutils

type Scenario = ref object
  rows: int
  columns: int
  cells: seq[seq[bool]]

  score: float

  x: int
  rotations: int
  piece: Piece

proc print_piece*(p: Piece) =
  for r in 0..3:
    var rs = ""
    for c in 0..3:
      if r == 2 and c == 2:
        rs &= "o"
      elif p.form[r][c]:
        rs &= "X"
      else:
        rs &= " "
    echo rs

proc print_field*[T](f: T) =
  for r in 0..<f.rows:
    var rs = ""
    for c in 0..<f.columns:
      if f.cells[r][c]:
        rs &= "X"
      else:
        rs &= " "
    echo rs

  echo "'".repeat(f.columns)

proc print_scenario*(f: Scenario) =
  for r in 0..<f.rows:
    var rs = ""
    for c in 0..<f.columns:
      if f.cells[r][c]:
        rs &= "X"
      else:
        rs &= " "
    echo rs

  echo "'".repeat(f.columns), "score=", f.score

proc merge_piece[T](f: T; p: Piece; x, y: int) =
  discard
    """
    echo "merging piece"
    print_piece p

    echo "at ", x, ",", y

    echo "in:"
    print_field f
    """

  for px in 0..3:
    for py in 0..3:
      let fx = (px - 2) + x
      let fy = (py - 2) + y
      if p.form[py][px]:
        f.cells[fy][fx] = true

proc get_scenario(f: TetrisField, p: Piece, x: int): Scenario =
  result = new Scenario
  result.x = x
  result.piece = p.make_copy
  result.rows = f.rows
  result.columns = f.columns

  var y = 1
  while f.check_piece_collision(p, x, y) == false:
    y += 1

  result.cells.deepCopy f.cells
  result.merge_piece(p, x, y)

proc get_x_scenarios(f: TetrisField, p: Piece): seq[Scenario] =
  var valid_x: seq[int] = @[]

  result = @[]

  for x in -2..<f.columns+2:
    if f.check_valid_pos(p, x, 3):
      valid_x.add x

  for x in valid_x:
    result.add f.get_scenario(p, x)

proc get_scenarios(f: TetrisField): seq[Scenario] =
  result = @[]

  var piece = f.current_piece.make_copy

  var rots_to_try = 4
  if piece.type_hint == Z or piece.type_hint == I:
    rots_to_try = 1
  elif piece.type_hint == Q:
    rots_to_try = 0

  for rot in 0..<rots_to_try:
    var scenarios = f.get_x_scenarios(piece)

    for s in scenarios:
      s.rotations = rot

    result &= scenarios

    piece = piece.rotate()

proc max_height*[T](f: T): int =
  result = 0

  for r in 0..<f.rows:
    var has_something = false

    for c in 0..<f.columns:
      if f.cells[r][c]:
        has_something = true
        break

    if has_something:
      return f.rows - r

proc row_fill*[T](f: T, row: int): float =
  var count = 0

  for c in 0..<f.columns:
    if f.cells[row][c]:
      count += 1

  return count.float / f.columns.float

proc dirty_fill*[T](f: T): float =
  let height = f.max_height

  result = 0.0

  if height <= 0:
    result = 1.0
  else:
    for r in countdown(f.rows - 1, f.rows - height):
      result += f.row_fill(r)

    result /= height.float

proc holes*[T](f: T): int =
  result = 0

  for c in 0..<f.columns:
    var y = f.rows - 1

    var count = 0

    while y >= 0:
      if not f.cells[y][c]:
        count += 1
      else:
        result += count
        count = 0

      y -= 1

proc covered_holes*[T](f: T, genome: seq[float]): float =
  result = 0

  let empty_weight = genome[9]
  let cover_weight = genome[10]
  let height_multiplier = genome[11]

  for c in 0..<f.columns:
    var found_empty = false
    var contrib = 0.0
    var height = 1
    var r = f.rows - 1
    while r >= 0:
      if not f.cells[r][c]:
        contrib += empty_weight + (height.float * height_multiplier)
        found_empty = true
      else:
        if found_empty:
          result += contrib
          contrib = 0

          result += cover_weight

      r -= 1
      height += 1

proc bumpiness*[T](f: T): float =
  var previous_height = 0

  result = 0

  for r in 0..<f.rows:
    if f.cells[r][0]:
      previous_height = f.rows - r
      break

  var max = 0

  for c in 1..<f.columns:
    var height = 0

    for r in 0..<f.rows:
      if f.cells[r][c]:
        height = f.rows - r
        break

    let diff = abs(height - previous_height)
    result += diff.float
    if diff > max:
      max = diff

    previous_height = height

  result /= (f.columns - 1).float
  result = result * 0.65 + max.float * 0.35

proc clear_lines*[T](s: T): tuple[number: int, scenario: T] =
  result.scenario.deepCopy s
  result.number = 0

  while true:
    var did_clear = false

    for r in countdown(result.scenario.rows - 1, 0):
      var full = true

      for c in 0..<result.scenario.columns:
        if not result.scenario.cells[r][c]:
          full = false
          break

      if full:
        # keep count
        did_clear = true
        result.number += 1

        # shift everything down
        for rd in countdown(r, 1):
          for cd in 0..<result.scenario.columns:
            result.scenario.cells[rd][cd] = result.scenario.cells[rd - 1][cd]

        for cd in 0..<result.scenario.columns:
          result.scenario.cells[0][cd] = false

    if not did_clear:
      break


# @[5.0, -3.5, -0.29, 1.0, -1.5, -0.83, 0.0, 0.0]
# @[5.0, -2.8, -1.2, -0.7, -0.7, -0.8, 0.0, 0.0, 0.0, 1.5, 1.2, 0.5]

proc calculate_score(s: Scenario, f: TetrisField, genome: seq[float]): float =
  result = 0

  let cleared = s.clear_lines()
  result += genome[0] * cleared.number.float

  let cs = cleared.scenario
  result += genome[1] * cs.max_height.float / f.rows.float * 2
  result += genome[2] * cs.holes.float
  result += genome[3] * cs.dirty_fill
  result += genome[4] * cs.covered_holes(genome)
  result += genome[5] * cs.bumpiness
  result += (genome[6] * 0.1) * (s.x.float / 4.5 - 1.0 + genome[7])
  result += (genome[8] * 0.1) * abs(s.x.float - 4.5) / 4.5

proc best_scenario(scenarios: seq[Scenario], f: TetrisField, genome: seq[float]): Scenario =
  #echo "calculating scores for ", scenarios.len, " scenarios"

  for s in scenarios:
    s.score = s.calculate_score(f, genome)
    #print_scenario s

  let best = scenarios.sorted do (x, y: Scenario) -> int: return cmp(x.score, y.score)

  #echo "sorted scores:"
  #for s in best:
  #  echo s.score

  return best[best.len - 1]

type AIMove = object
  rotations*: int
  x*: int
  piece*: Piece

proc ai_move*(f: TetrisField, genome: seq[float]): AIMove =
  #echo "finding scenarios for AI move with piece:"
  #print_piece f.current_piece

  let scenarios = f.get_scenarios()

  let best = scenarios.best_scenario(f, genome)

  #echo "best scenario:"
  #print_scenario best

  if best == nil:
    result.rotations = 0
    result.x = 5
    result.piece = f.current_piece
  else:
    result.rotations = best.rotations
    result.x = best.x
    result.piece = best.piece
