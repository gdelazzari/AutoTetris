import unittest

import ai
import objects

const SIMILAR_RANGE = 0.001

proc similar(value: float, to: float): bool =
  result = value >= (to - SIMILAR_RANGE) and value <= (to + SIMILAR_RANGE)
  if not result:
    echo "got ", value, ", expected ", to

suite "AI tests":
  var field = new_field(10, 20, 1)

  setup:
    field.reset()

  test "max_height":
    check field.max_height == 0
    field.cells[19][3] = true
    check field.max_height == 1
    field.cells[19][8] = true
    check field.max_height == 1
    field.cells[19][7] = true
    check field.max_height == 1
    field.cells[18][8] = true
    check field.max_height == 2
    field.cells[18][3] = true
    check field.max_height == 2
    field.cells[17][3] = true
    check field.max_height == 3
    field.cells[10][5] = true
    check field.max_height == 10
    field.cells[1][1] = true
    check field.max_height == 19
    field.cells[0][2] = true
    check field.max_height == 20

  test "row_fill":
    for r in 0..19:
      check field.row_fill(19).similar(0)

    for i in 0..6:
      field.cells[19][i] = true
    check field.row_fill(19).similar(0.7)

    for i in 4..9:
      field.cells[5][i] = true
    check field.row_fill(5).similar(0.6)

  test "dirty_fill":
    check field.dirty_fill.similar(1)

    field.cells[19][4] = true
    check field.dirty_fill.similar(0.1)

    field.cells[18][4] = true
    check field.dirty_fill.similar(0.1)

    field.cells[19][3] = true
    check field.dirty_fill.similar(0.15)

    for i in 5..7:
      field.cells[19][i] = true
    check field.dirty_fill.similar(0.3)

    for i in 0..7:
      field.cells[17][i] = true
    check field.dirty_fill.similar(0.4667)

    for i in 2..9:
      field.cells[5][i] = true
    check field.dirty_fill.similar(0.1467)

    field.cells[1][4] = true
    check field.dirty_fill < 0.1467

    field.cells[0][4] = true
    check field.dirty_fill < 0.1467

  test "holes":
    check field.holes == 0

    field.cells[19][0] = true
    check field.holes == 0

    for i in 0..5: field.cells[19][i] = true
    check field.holes == 0

    field.cells[18][8] = true
    check field.holes == 1

    for i in 0..9: field.cells[19][i] = true
    check field.holes == 0

    for i in 0..9: field.cells[17][i] = true
    check field.holes == 9

    field.cells[14][0] = true
    field.cells[14][1] = true
    field.cells[14][2] = true
    check field.holes == 15

    for i in 0..9: field.cells[18][i] = true
    check field.holes == 6

    field.cells[16][1] = true
    check field.holes == 5

  test "covered_holes":
    let weights: seq[float] = @[0.0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1]

    check field.covered_holes(weights).similar(0)

    for i in 4..7: field.cells[19][i] = true
    check field.covered_holes(weights).similar(0)

    for i in 0..4: field.cells[18][i] = true
    check field.covered_holes(weights).similar(3 * 4)

    field.cells[17][1] = true
    field.cells[17][2] = true
    check field.covered_holes(weights).similar(3 * 2 + 4 * 2)

    for i in 4..9: field.cells[17][i] = true
    check field.covered_holes(weights).similar((3 * 2) + (4 * 2) + (4 * 3) + (6 * 2))

    field.cells[16][1] = true
    field.cells[16][2] = true
    field.cells[16][4] = true
    for i in 0..4: field.cells[15][i] = true
    check field.covered_holes(weights).similar((3 * 2) + (4 * 2) + (4 * 3) + (6 * 2) + (10 * 2) + 4)

    field.cells[16][2] = false
    check field.covered_holes(weights).similar((3 * 2) + (4 * 2) + (4 * 3) + (6 * 2) + (10 * 2) + 6 + 2)

  test "covered_holes (3-tall)":
    let weights: seq[float] = @[0.0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1]

    check field.covered_holes(weights).similar(0)

    for i in 0..4: field.cells[16][i] = true
    for j in 16..19: field.cells[j][4] = true
    check field.covered_holes(weights).similar(10 * 4)

  test "covered_holes (piled up)":
    let weights: seq[float] = @[0.0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1]

    check field.covered_holes(weights).similar(0)

    for i in 0..4: field.cells[17][i] = true
    for j in 12..19: field.cells[j][4] = true
    check field.covered_holes(weights).similar(6 * 4)

    for i in 0..4: field.cells[14][i] = true
    check field.covered_holes(weights).similar(6 * 4 + 12 * 4)

    for i in 0..4: field.cells[12][i] = true
    check field.covered_holes(weights).similar(6 * 4 + 12 * 4 + 9 * 4)

  test "covered_holes (big weights)":
    let weights: seq[float] = @[0.0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 10, 1]

    check field.covered_holes(weights).similar(0)

    for i in 0..4: field.cells[17][i] = true
    for j in 12..19: field.cells[j][4] = true
    check field.covered_holes(weights).similar(213 * 4)

    for i in 0..4: field.cells[14][i] = true
    check field.covered_holes(weights).similar(213 * 4 + 219 * 4)

    for i in 0..4: field.cells[12][i] = true
    check field.covered_holes(weights).similar(213 * 4 + 219 * 4 + 117 * 4)

  test "bumpiness":
    check field.bumpiness.similar(0)

    for i in 0..4: field.cells[19][i] = true
    check field.bumpiness.similar(0.4222)

    for i in 5..6: field.cells[19][i] = true
    check field.bumpiness.similar(0.4222)

    for i in 6..9: field.cells[19][i] = true
    check field.bumpiness.similar(0)

    field.cells[19][4] = false
    check field.bumpiness.similar(0.4944)

    for j in 15..19: field.cells[j][4] = true
    for j in 13..19: field.cells[j][6] = true
    for j in 15..19: field.cells[j][8] = true
    check field.bumpiness.similar(4.1222)

  test "cleared lines":
    check field.clear_lines().number == 0

    for i in 0..4: field.cells[19][i] = true
    check field.clear_lines().number == 0

    for i in 5..9: field.cells[19][i] = true
    check field.clear_lines().number == 1

    # doesn't modify original field
    check field.clear_lines().number == 1

    for i in 0..9: field.cells[18][i] = true
    check field.clear_lines().number == 2

    for i in 1..9: field.cells[17][i] = true
    check field.clear_lines().number == 2

    field.cells[17][0] = true
    check field.clear_lines().number == 3

  test "clear lines":
    for i in 0..9: field.cells[19][i] = true
    for i in 0..9: field.cells[18][i] = true
    for i in 2..7: field.cells[17][i] = true
    for i in 3..5: field.cells[16][i] = true
    for i in 1..8: field.cells[15][i] = true

    let cleared = field.clear_lines()

    check cleared.number == 2
    check cleared.scenario.bumpiness.similar(field.bumpiness)
    check cleared.scenario.max_height == field.max_height - 2
    check cleared.scenario.holes == field.holes
    check cleared.scenario.dirty_fill < field.dirty_fill
