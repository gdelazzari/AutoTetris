import nimraylib_now
import random

import objects
import graph

import ai
import genetic

import cpuinfo

randomize()

let width = 800
let height = 600

let   EVALUATOR_THREADS_NUM = count_processors()
const PIECES_PER_INDIVIDUAL = 10000
const NUM_MATCHES_PER_INDIV = 5

init_window(width.cint, height.cint, "AutoTetris")

set_target_FPS(30)

var field = new_field(10, 20, 24, rand(int.high))
var count = 0
var move_count = 0

#var current_generation = guided_generation(@[5.0, -2.8, -1.2, -0.7, -0.7, -0.8, 0.0, 0.0, 0.0, 1.5, 1.2, 0.5])
var current_generation = random_generation()
var current_generation_n = 0
var evaluated_count = 0
var evaluated_indiv_count = 0
var evaluated_status: array[GENERATION_SIZE, tuple[count: int, sum: int]]

var absolute_max = 0
var generation_max = 0
var generation_avg = 0.0
var mutants_avg = 0.0
var mutants_num = 0
var generation_best = random_individual()
var absolute_best = random_individual()

var turbo_mode = false

var fitness_graph = new_graph(100, 360, 160)
let max_series = fitness_graph.add_series(RED)
let avg_series = fitness_graph.add_series(DARKGREEN)
let mut_series = fitness_graph.add_series(ORANGE)

var to_evaluate: Channel[tuple[id: int, individual: Individual]]
var evaluated: Channel[tuple[id: int, score: int]]

var evaluator_threads: seq[Thread[int]]

proc evaluator_thread(num: int) {.thread.} =
  echo "[thread #", num, "] evaluator thread started"

  var rng = init_rand(rand(int.high))

  while true:
    let job = to_evaluate.recv()

    echo "[thread #", num, "] new job (id=", job.id, ")"

    var field = new_field(10, 20, 0, cast[int64](rng.next))
    var piece_count = 0

    while not field.lost and piece_count < PIECES_PER_INDIVIDUAL:
      if field.new_piece:
        piece_count += 1
        field.new_piece = false

        let ai_move = field.ai_move(job.individual.genome)

        field.current_piece = ai_move.piece
        field.current_piece_x = ai_move.x

      field.slide()

    var result: tuple[id: int, score: int]
    result.id = job.id
    result.score = field.get_score

    evaluated.send result

echo "initializing threads channels"
to_evaluate.open()
evaluated.open()

echo "starting evaluator threads"
for i in 0..<EVALUATOR_THREADS_NUM:
  var t: Thread[int]
  evaluator_threads.add (move t)

for i in 0..<EVALUATOR_THREADS_NUM:
  evaluator_threads[i].create_thread(evaluator_thread, i)

proc launch_evaluation() =
  echo "launching evaluation"

  evaluated_indiv_count = 0
  evaluated_count = 0
  for i in 0..<GENERATION_SIZE:
    evaluated_status[i].count = 0
    evaluated_status[i].sum = 0

  for i in 0..<GENERATION_SIZE:
    var job: tuple[id: int, individual: Individual]
    job.id = i
    job.individual = current_generation[i]

    for i in 0..<NUM_MATCHES_PER_INDIV:
      to_evaluate.send job

launch_evaluation()

while window_should_close() == false:

  if is_key_down(KeyboardKey.Left):
    if move_count == 0:
      move_count = 2000
    else:
      move_count += 1
  elif is_key_down(KeyboardKey.Right):
    if move_count == 0:
      move_count = 2000
    else:
      move_count += 1
  else:
    move_count = 0

  if move_count >= 8:
    if is_key_down(KeyboardKey.Left):
      field.move_current_piece(-1)
    elif is_key_down(KeyboardKey.Right):
      field.move_current_piece(1)
    move_count = 1

  if is_key_pressed(KeyboardKey.Up):
    field.rotate_current_piece()

  var slide_speed = 5
  var simulation_steps = 1

  if is_key_down(KeyboardKey.Down):
    slide_speed = 0

  if is_key_pressed(KeyboardKey.T):
    turbo_mode = not turbo_mode

  if turbo_mode:
    slide_speed = 0
    simulation_steps = 5

  for i in 0..simulation_steps:
    count += 1
    if count >= slide_speed:
      count = 0
      field.slide()

    if field.new_piece and not field.lost:
      field.new_piece = false

      try:
        let ai_move = field.ai_move(absolute_best.genome)

        field.current_piece = ai_move.piece
        field.current_piece_x = ai_move.x
      except:
        field.lost = true

    if field.lost:
      field.reset()

  let maybe_result = evaluated.try_recv()
  if maybe_result.data_available:
    let result = maybe_result.msg

    evaluated_count += 1
    evaluated_status[result.id].count += 1
    evaluated_status[result.id].sum += result.score

    if evaluated_status[result.id].count >= NUM_MATCHES_PER_INDIV:
      let score = (evaluated_status[result.id].sum / NUM_MATCHES_PER_INDIV).int
      current_generation[result.id].score = score
      evaluated_indiv_count += 1

      if score > generation_max:
        generation_max = score
        generation_best = current_generation[result.id]

        if generation_max > absolute_max:
          absolute_max = generation_max
          absolute_best = generation_best
          echo "new ABSOLUTE best: ", absolute_best

      generation_avg += score.float / GENERATION_SIZE.float

      if current_generation[result.id].mutated:
        mutants_avg += score.float
        mutants_num += 1

  if evaluated_count >= GENERATION_SIZE * NUM_MATCHES_PER_INDIV:
    current_generation = current_generation.next_generation()
    current_generation_n += 1

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

    launch_evaluation()

  begin_drawing()

  block:
    clear_background(RAYWHITE)

    field.draw(60, 60)

    draw_text("AutoTetris", 60, 20, 20, GRAY)
    draw_text($field.get_score(), 220, 20, 20, GRAY)
    draw_text("FPS " & $get_fps(), 360, 20, 20, GRAY)

    draw_text("Generation " & $current_generation_n, 360, 60, 20, GRAY)
    draw_text("Evaluating " & $evaluated_indiv_count & "/" & $GENERATION_SIZE & " (" & $EVALUATOR_THREADS_NUM & " threads)", 360, 90, 20, GRAY)

    draw_text("Gen max " & $generation_max, 360, 140, 20, GRAY)
    draw_text("Abs max " & $absolute_max, 360, 170, 20, GRAY)

    fitness_graph.draw(360, 220)

  end_drawing()
