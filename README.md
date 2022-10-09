# AutoTetris

This small project of mine, which was developed during some free-time in 2018, involved the creation of a very simple automatic Tetris playing algorithm, which gets optimized through a genetic algorithm.

The code is written in [Nim](https://nim-lang.org/), as a way to play around with the language.

## Features and limitations
The Tetris game that I implemented is very basic.
For instance not all moves are supported: the pieces may only fall straight without late translations or rotations.
Also the "next piece" mechanic is not handled, i.e. there is no way of knowing which random piece will follow after the current one is fully dropped. Finally, most importantly and very embarrassingly, the core Tetris scoring mechanic for *tetrises* is not implemented.

These limitations actually make the game (from the AI perspective) more difficult to master, and make it so that the AI objective is to generically survive as long as possible in the playing field.

Nevertheless, the project features a couple of cool things:
- realtime/fast-forward view (toggle with `T` for *Turbo*) of the fittest individual playing a match;
- parallel background evaluation of population individuals, exploiting all the available CPU cores.

[![Animated demo](assets/demo.gif)](assets/demo.gif)

## Automatic playing algorithm workings

### Core logic
The automatic playing algorithm works as follows. Given the current Tetris board state and the piece that is falling, the algorithm computes all the possible outcomes following all the possible actions (piece placement) that can be taken. Every outcome is then evaluated and the action leading to the best one is chosen.

### Outcome evaluation
A Tetris board is evaluated by running it through a set of metrics, for instance:
- the maximum height of the fallen blocks
- the amount of (covered) "holes"
- the "bumpiness" of the fallen blocks top profile
- the number of cleared lines
- ...

Then, with the addition of a set of weighting and biasing coefficients, a final score is obtained. The set of coefficients is chosen to be the genome for the genetic optimization that is performed.

### Genetic optimization
There are 14 coefficients to optimize, with the aim (fitness function) being obtaining the highest possible score in the game. The genetic algorithm crossbreeds the genomes by performing two random cuts, and mutates them by adding or multiplying a random value to some randomly chosen coefficient(s).

## Compiling and running
You will need to [install Nim and Nimble](https://nim-lang.org/install.html), then to build and launch the project in release mode you can run:

```console
$ nimble install nimraylib_now
$ nim c -r -d:release --threads:on autotetris.nim
```
