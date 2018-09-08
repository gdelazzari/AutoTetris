import raylib
import random

import objects
import graph

import ai
import genetic

randomize()

let width = 800
let height = 600

let PIECES_PER_INDIVIDUAL = 10000
let FPS_AVERAGING = 1000

init_window(width.cint, height.cint, "AutoTetris")

set_target_FPS(60)

var field = new_field(10, 20, 24)
var count = 0
var move_count = 0

#var current_generation = guided_generation(@[5.0, -2.8, -1.2, -0.7, -0.7, -0.8, 0.0, 0.0, 0.0, 1.5, 1.2, 0.5])
var current_generation = random_generation()
var current_generation_n = 0
var current_individual = 0
var current_piece_count = 0

var absolute_max = 0
var generation_max = 0
var generation_avg = 0.0
var mutants_avg = 0.0
var mutants_num = 0
var generation_best: seq[float] = @[]
var absolute_best: seq[float] = @[]

var turbo_mode = false

var fitness_graph = new_graph(100, 360, 160)
let max_series = fitness_graph.add_series(RED)
let avg_series = fitness_graph.add_series(DARKGREEN)
let mut_series = fitness_graph.add_series(ORANGE)

var fps_avg = 0.0
var fps_sum = 0.0
var fps_count = 0

var last_fps = 60

while window_should_close() == 0:

  if key_down(KEY_LEFT) != 0:
    if move_count == 0:
      move_count = 2000
    else:
      move_count += 1
  elif key_down(KEY_RIGHT) != 0:
    if move_count == 0:
      move_count = 2000
    else:
      move_count += 1
  else:
    move_count = 0

  if move_count >= 8:
    if key_down(KEY_LEFT) != 0:
      field.move_current_piece(-1)
    elif key_down(KEY_RIGHT) != 0:
      field.move_current_piece(1)
    move_count = 1

  if key_pressed(KEY_UP) != 0:
    field.rotate_current_piece()

  var slide_speed = 2
  var fps = 60

  if key_down(KEY_DOWN) != 0:
    slide_speed = 0
    fps = 10000

  if key_pressed(KEY_T) != 0:
    turbo_mode = not turbo_mode

  if turbo_mode:
    slide_speed = 0
    fps = 10000

  if fps != last_fps:
    set_target_FPS(fps.cint)
    last_fps = fps

  count += 1
  if count >= slide_speed:
    count = 0
    field.slide()

  if field.new_piece and not field.lost:
    current_piece_count += 1
    field.new_piece = false

    try:
      let ai_move = field.ai_move(current_generation[current_individual].genome)

      field.current_piece = ai_move.piece
      field.current_piece_x = ai_move.x
    except:
      field.lost = true

  if field.lost or current_piece_count >= PIECES_PER_INDIVIDUAL:
    current_generation[current_individual].score = field.get_score()

    if field.get_score() > generation_max:
      generation_max = field.get_score()
      generation_best = current_generation[current_individual].genome
      echo "new GENERATION best: ", generation_best

      if generation_max > absolute_max:
        absolute_max = generation_max
        absolute_best = generation_best
        echo "new ABSOLUTE best: ", absolute_best

    generation_avg += field.get_score().float / GENERATION_SIZE.float

    if current_generation[current_individual].mutated:
      mutants_avg += field.get_score().float
      mutants_num += 1

    current_individual += 1
    current_piece_count = 0

    field.reset()

    if current_individual >= GENERATION_SIZE:
      current_generation = current_generation.next_generation()
      current_generation_n += 1
      current_individual = 0

      fitness_graph.push(max_series, generation_max.float)
      fitness_graph.push(avg_series, generation_avg.float)
      if mutants_num > 0:
        fitness_graph.push(mut_series, mutants_avg / mutants_num.float)
      else:
        fitness_graph.push(mut_series, 0)
      
      generation_max = 0
      generation_avg = 0.0
      mutants_avg = 0.0
      mutants_num = 0

  fps_sum += get_fps().float
  fps_count += 1

  if fps_count >= FPS_AVERAGING:
    fps_avg = fps_sum / FPS_AVERAGING.float
    fps_sum = 0.0
    fps_count = 0

  begin_drawing()

  block:
    clear_background(RAYWHITE)

    field.draw(60, 60)

    draw_text("AutoTetris", 60, 20, 20, GRAY)
    draw_text($field.get_score(), 220, 20, 20, GRAY)
    draw_text("FPS " & $fps_avg.int, 360, 20, 20, GRAY)

    draw_text("Generation " & $current_generation_n, 360, 60, 20, GRAY)
    if current_generation[current_individual].mutated:
      draw_text("Individual " & $current_individual & " (mutant)", 360, 90, 20, GRAY)
    else:
      draw_text("Individual " & $current_individual, 360, 90, 20, GRAY)
    draw_text("Pieces #n  " & $current_piece_count, 360, 120, 20, GRAY)

    draw_text("Gen max " & $generation_max, 360, 170, 20, GRAY)
    draw_text("Abs max " & $absolute_max, 360, 200, 20, GRAY)

    fitness_graph.draw(360, 250)

  end_drawing()
