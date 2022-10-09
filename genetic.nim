{.reorder: on.}

import algorithm
import math
import random

const GENOME_LENGTH* = 17
const GENERATION_SIZE* = 20

const MUTATION_INDIVIDUALS_PERCENT = 0.35
const MUTATION_GENES_PERCENT = 0.25
const MUTATION_ADD_RANGE = 0.75
const MUTATION_MUL_RANGE = 2.0

randomize()
var rng = init_rand(rand(int.high))

type Individual* = object
  genome*: seq[float]
  score*: int
  mutated*: bool

type Generation* = seq[Individual]

proc random_individual*(): Individual =
  result.score = 0
  result.genome = @[]
  result.mutated = false
  for i in 0..<GENOME_LENGTH:
    result.genome.add (rng.rand(2.0) - 1.0)

proc guided_individual*(genome: seq[float]): Individual =
  result.score = 0

  if rng.rand(1.0) <= MUTATION_INDIVIDUALS_PERCENT:
    result.genome = genome.mutate
    result.mutated = true
  else:
    result.genome.deepCopy genome
    result.mutated = false

proc specific_individual*(genome: seq[float]): Individual =
  result.score = 0
  result.mutated = false
  result.genome.deepCopy genome

proc random_generation*(): Generation =
  result = @[]
  for i in 0..<GENERATION_SIZE:
    result.add random_individual()

proc guided_generation*(genome: seq[float]): Generation =
  result = @[]
  result.add specific_individual(genome)
  result.add specific_individual(genome)
  for i in 2..<GENERATION_SIZE:
    result.add guided_individual(genome)

proc breed(a, b: seq[float]): seq[float] =
  result = @[]

  let cut_1 = rng.rand((a.high.float * 0.75).floor.int)
  let cut_2 = cut_1 + 1 + rng.rand(a.high - cut_1 - 1)

  for i in 0..<GENOME_LENGTH:
    if i < cut_1 or i >= cut_2:
      result.add (a[i] * 0.95 + b[i] * 0.05)
    else:
      result.add (a[i] * 0.05 + b[i] * 0.95)

proc pick_individuals(pool: seq[int]): tuple[a: int, b: int] =
  let a = pool[rand(pool.low .. pool.high)]

  var b = a
  while b == a:
    b = pool[rand(pool.low .. pool.high)]

  return (a, b)

proc mutate(genome: seq[float]): seq[float] =
  result = @[]

  for i in 0..<genome.len:
    if rng.rand(1.0) <= MUTATION_GENES_PERCENT:
      var mutated = genome[i]
      let kind = rand(1)

      if kind == 0:
        mutated += rng.rand(MUTATION_ADD_RANGE * 2) - MUTATION_ADD_RANGE
      elif kind == 1:
        mutated *= rng.rand(MUTATION_MUL_RANGE * 2) - MUTATION_MUL_RANGE

      result.add mutated
    else:
      result.add genome[i]

proc next_generation*(previous: Generation): Generation =
  result = @[]

  var max_score = 0
  for i in previous:
    if i.score > max_score:
      max_score = i.score

  var min_score = max_score
  for i in previous:
    if i.score < min_score:
      min_score = i.score

  echo "generation max score = ", max_score
  echo "generation min score = ", min_score

  var pool: seq[int] = @[]

  for i in 0..<previous.len:
    var count = 1

    if max_score != min_score:
      count = (((previous[i].score - min_score).float / (max_score - min_score).float) * 15).round.int + 1

    for c in 0..<count:
      pool.add i

  echo "mating pool size = ", pool.len

  var mutations = 0

  for c in 0..<GENERATION_SIZE:
    let parents = pool.pick_individuals
    var child_genome = breed(previous[parents.a].genome, previous[parents.b].genome)

    var mutated = false
    if rng.rand(1.0) <= MUTATION_INDIVIDUALS_PERCENT:
      child_genome = child_genome.mutate
      mutated = true
      mutations += 1

    result.add Individual(score: 0, genome: child_genome, mutated: mutated)

  echo mutations, " mutations this generation"
