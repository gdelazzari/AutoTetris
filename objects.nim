import sequtils
import random
import raylib
import math

type PieceType* = enum
  L,
  Z,
  T,
  I,
  Q

type Piece* = ref object
  form*: array[4, array[4, bool]]
  type_hint*: PieceType

proc make_copy*(p: Piece): Piece =
  result = new Piece
  for r in 0..3:
    for c in 0..3:
      result.form[r][c] = p.form[r][c]

proc rotate*(p: Piece): Piece =
  result = p.make_copy

  for py in 0..3:
    for px in 0..3:
      result.form[px][3 - py] = p.form[py][px]

proc relevance*(p: Piece): int =
  result = 0

  if p == nil:
    return 0

  for py in 0..3:
    for px in 0..3:
      if p.form[py][px]:
        result += 1

let FIELD_BORDER_WIDTH = 4

type TetrisField* = ref object
  columns*: int
  rows*: int
  cell_size: int
  cells*: seq[seq[bool]]
  current_piece*: Piece
  current_piece_x*: int
  current_piece_y: int
  score: int
  new_piece*: bool
  lost*: bool
  rng: Rand

proc new_field*(columns, rows, cell_size: int, seed: int64): TetrisField =
  result = new TetrisField
  result.rng = init_rand(seed)
  result.columns = columns
  result.rows = rows
  result.cell_size = cell_size
  result.cells = false.repeat(columns).repeat(rows)
  result.current_piece = pick_random_piece(result.rng)
  result.current_piece_y = 1
  result.current_piece_x = 5
  result.new_piece = true

proc draw*(f: TetrisField; x, y: int) =
  let width = f.columns * f.cell_size
  let height = f.rows * f.cell_size

  # draw field border
  draw_rectangle(
    (x - FIELD_BORDER_WIDTH).cint, (y - FIELD_BORDER_WIDTH).cint,
    (width + FIELD_BORDER_WIDTH * 2).cint, (height + FIELD_BORDER_WIDTH * 2).cint,
    GRAY
  )

  draw_rectangle(
    x.cint, y.cint,
    width.cint, height.cint,
    WHITE
  )

  # draw grid
  for r in 1..f.rows - 1:
    draw_rectangle(
      x.cint, (y + r * f.cell_size).cint,
      width.cint, 1,
      LIGHTGRAY
    )

  for c in 1..f.columns - 1:
    draw_rectangle(
      (x + c * f.cell_size).cint, y.cint,
      1, height.cint,
      LIGHTGRAY
    )

  # draw current cells
  for r in 0..f.rows - 1:
    for c in 0..f.columns - 1:
      if f.cells[r][c] == true:
        draw_rectangle(
          (x + c * f.cell_size).cint, (y + r * f.cell_size).cint,
          f.cell_size.cint, f.cell_size.cint,
          BLACK
        )

  # draw current piece, if any
  if f.current_piece != nil:
    for px in 0..3:
      for py in 0..3:
        let fx = (px - 2) + f.current_piece_x
        let fy = (py - 2) + f.current_piece_y
        if f.current_piece.form[py][px]:
          draw_rectangle(
            (x + fx * f.cell_size).cint, (y + fy * f.cell_size).cint,
            f.cell_size.cint, f.cell_size.cint,
            RED
          )

proc check_piece_collision*(f: TetrisField; p: Piece; x, y: int): bool =
  for py in countdown(3, 0):
    for px in 0..3:
      let fx = (px - 2) + x
      let fy = (py - 2) + y

      if p.form[py][px]:
        if fy >= f.rows - 1:
          # this happens when it's touching the ground/bottom
          return true
        else:
          # otherwise check if below there's another block or not
          if f.cells[fy + 1][fx]:
            return true

  return false

proc check_piece_collision(f: TetrisField): bool =
  return f.check_piece_collision(f.current_piece, f.current_piece_x, f.current_piece_y)

# 0: no collision, -1: left, +1: right
proc check_piece_collision_side(f: TetrisField): int =
  for px in 0..3:
    for py in 0..3:
      let fx = (px - 2) + f.current_piece_x
      let fy = (py - 2) + f.current_piece_y
      if f.current_piece.form[py][px]:
        if fx <= 0:
          return -1
        elif fx >= f.columns - 1:
          return 1
        elif fy < 0:
          continue
        elif f.cells[fy][fx - 1]:
          return -1
        elif f.cells[fy][fx + 1]:
          return 1

  return 0

proc check_valid_pos*(f: TetrisField; p: Piece; x, y: int): bool =
  for px in 0..3:
    for py in 0..3:
      let fx = (px - 2) + x
      let fy = (py - 2) + y
      if p.form[py][px]:
        if fx < 0:
          return false
        elif fx > f.columns - 1:
          return false
        elif fy < 0:
          return false
        elif fy > f.rows - 1:
          return false

  for px in 0..3:
    for py in 0..3:
      let fx = (px - 2) + x
      let fy = (py - 2) + y
      if p.form[py][px]:
        if f.cells[fy][fx]:
          return false

  return true

proc pick_random_piece(rng: var Rand): Piece =
  let PieceL1 = Piece(type_hint: L, form: [[false, false, false, false], [false, false, false, true], [false, true, true, true], [false, false, false, false]])
  let PieceL2 = Piece(type_hint: L, form: [[false, false, false, false], [false, true, true, true], [false, false, false, true], [false, false, false, false]])
  let PieceZ1 = Piece(type_hint: Z, form: [[false, false, false, false], [false, true, false, false], [false, true, true, false], [false, false, true, false]])
  let PieceZ2 = Piece(type_hint: Z, form: [[false, false, false, false], [false, false, true, false], [false, true, true, false], [false, true, false, false]])
  let PieceT = Piece(type_hint: T, form: [[false, false, false, false], [false, false, false, false], [false, false, true, false], [false, true, true, true]])
  let PieceI = Piece(type_hint: I, form: [[false, false, false, false], [false, false, false, false], [true, true, true, true], [false, false, false, false]])
  let PieceQ = Piece(type_hint: Q, form: [[false, false, false, false], [false, true, true, false], [false, true, true, false], [false, false, false, false]])

  let PIECES = [
    PieceL1,
    PieceL2,
    PieceZ1,
    PieceZ2,
    PieceT,
    PieceI,
    PieceQ
  ]

  result = PIECES[rng.rand(PIECES.len - 1)].make_copy

proc merge_piece(f: TetrisField) =
  if f.current_piece != nil:
    for px in 0..3:
      for py in 0..3:
        let fx = (px - 2) + f.current_piece_x
        let fy = (py - 2) + f.current_piece_y
        if f.current_piece.form[py][px] and fy >= 0:
          f.cells[fy][fx] = true

proc score_lines(f: TetrisField): int =
  var cleared = 0

  while true:
    var did_clear = false

    for r in countdown(f.rows - 1, 0):
      var full = true

      for c in 0..<f.columns:
        if not f.cells[r][c]:
          full = false
          break

      if full:
        # keep count
        cleared += 1
        did_clear = true

        # shift everything down
        for rd in countdown(r, 1):
          for cd in 0..<f.columns:
            f.cells[rd][cd] = f.cells[rd - 1][cd]

        for cd in 0..<f.columns:
          f.cells[0][cd] = false

    if not did_clear:
      break

  if cleared > 0:
    return ((2.pow(float(cleared - 1))) * 100).int
  else:
    return 0

proc slide*(f: TetrisField) =
  if f.lost:
    return

  if f.current_piece != nil and not f.check_piece_collision():
    f.current_piece_y += 1
  else:
    f.merge_piece()
    f.score += f.score_lines()
    f.score += f.current_piece.relevance
    f.current_piece = pick_random_piece(f.rng)
    f.current_piece_y = 1
    f.current_piece_x = 5
    f.new_piece = true

    for c in 0..<f.columns:
      if f.cells[1][c]:
        f.lost = true

proc rotate_current_piece*(f: TetrisField) =
  if f.lost:
    return

  let rotated = f.current_piece.rotate()

  if f.check_valid_pos(rotated, f.current_piece_x, f.current_piece_y):
    f.current_piece = rotated

proc move_current_piece*(f: TetrisField, move: int) =
  if f.lost:
    return

  if move < 0 and f.check_piece_collision_side >= 0:
    f.current_piece_x -= 1
  if move > 0 and f.check_piece_collision_side <= 0:
    f.current_piece_x += 1

proc get_score*(f: TetrisField): int =
  return f.score

proc reset*(f: TetrisField) =
  for c in 0..<f.columns:
    for r in 0..<f.rows:
      f.cells[r][c] = false

  f.current_piece = pick_random_piece(f.rng)
  f.current_piece_y = 1
  f.current_piece_x = 5
  f.new_piece = true
  f.score = 0

  f.lost = false
