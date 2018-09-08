import raylib

let GRAPH_BORDER_WIDTH = 2

type Series* = object
  points: seq[float]
  color: Color

type Graph* = ref object
  series: seq[Series]
  max_points: int
  width: int
  height: int
  max_value: float
  min_value: float

proc new_graph*(mp: int; width, height: int): Graph =
  return Graph(
    series: @[],
    max_points: mp,
    width: width,
    height: height
  )

proc add_series*(g: Graph, c: Color): int =
  g.series.add Series(points: @[], color: c)
  return g.series.len - 1

proc push*(g: Graph, s: int, value: float) =
  g.series[s].points.add value
  if g.series[s].points.len > g.max_points:
    g.series[s].points.delete 0

  g.max_value = g.series[0].points[0]
  g.min_value = g.series[0].points[0]
  for sn in 0..<g.series.len:
    for i in 0..<g.series[sn].points.len:
      if g.series[sn].points[i] > g.max_value:
        g.max_value = g.series[sn].points[i]
      if g.series[sn].points[i] < g.min_value:
        g.min_value = g.series[sn].points[i]

proc draw*(g: Graph; x, y: int) =
  draw_rectangle(
    (x - GRAPH_BORDER_WIDTH).cint, (y - GRAPH_BORDER_WIDTH).cint,
    GRAPH_BORDER_WIDTH.cint, (g.height + GRAPH_BORDER_WIDTH * 2).cint,
    GRAY
  )

  draw_rectangle(
    x.cint, (y + g.height).cint,
    (g.width + GRAPH_BORDER_WIDTH).cint, GRAPH_BORDER_WIDTH.cint,
    GRAY
  )

  draw_text(
    $g.max_value.int,
    (x + g.width + GRAPH_BORDER_WIDTH * 3).cint, y.cint,
    11,
    GRAY
  )

  draw_text(
    $g.min_value.int,
    (x + g.width + GRAPH_BORDER_WIDTH * 3).cint, (y + g.height + GRAPH_BORDER_WIDTH - 11).cint,
    11,
    GRAY
  )

  for s in 0..<g.series.len:
    if g.series[s].points.len > 1:

      for i in 1..<g.series[s].points.len:
        let prev = g.series[s].points[i - 1]
        let this = g.series[s].points[i]
        let prev_x = x.float + g.width.float / (g.series[s].points.len - 1).float * (i - 1).float
        let this_x = x.float + g.width.float / (g.series[s].points.len - 1).float * i.float
        let prev_y = y.float + g.height.float * 0.1 + (g.height.float * 0.8 - (prev - g.min_value) / (g.max_value - g.min_value) * g.height.float * 0.8)
        let this_y = y.float + g.height.float * 0.1 + (g.height.float * 0.8 - (this - g.min_value) / (g.max_value - g.min_value) * g.height.float * 0.8)

        draw_line(
          prev_x.cint, prev_y.cint,
          this_x.cint, this_y.cint,
          g.series[s].color
        )

        draw_circle(
          prev_x.cint, prev_y.cint,
          2,
          g.series[s].color
        )

        draw_circle(
          this_x.cint, this_y.cint,
          2,
          g.series[s].color
        )
