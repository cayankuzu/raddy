class_name MapRules
## What the navigator's map shows and the round numbers it is printed with (pure, tested). The map's truth never changes with the
## difficulty, only how much of it comes pre-digested: Explore marks the route with a highlighter and gives every call with distances,
## Rally the highlighter and every call, Redline no highlighter (the crew reads the route off the roads: a branch that ends is no stage)
## and only the dangerous calls. The live car marker is on every level.

## Nice lengths for the scale bar and the grid (m).
const NICE_METRES: Array[float] = [10.0, 20.0, 25.0, 50.0, 100.0, 200.0, 250.0, 500.0, 1000.0]
## Contour intervals (m) and how many lines a sheet should carry at most over its height range.
const CONTOUR_STEPS: Array[float] = [2.0, 2.5, 5.0, 10.0, 20.0, 25.0, 50.0]
const MOST_CONTOURS := 14
## The grid: at least this many cells across the map's frame.
const GRID_CELLS := 6
## How big the printed sheet is (PaperMap.SHEET_SIZE.x over MapCanvas.CANVAS.x): metres of paper per canvas pixel.
const PAPER_METRES_PER_PIXEL := 0.58 / 1792.0
## What the land's heights are printed above: the stage's world heights stand on this much (m) per biome.
const DATUM := {&"forest": 420.0, &"desert": 610.0, &"mountain": 1840.0}


## {"route": the highlighter, "notes": PaceNotes detail, "car": the live marker} for `difficulty` (RaceSettings.Difficulty).
static func contents(difficulty: int) -> Dictionary:
	return {"route": difficulty != RaceSettings.Difficulty.REDLINE, "notes": RaceSettings.note_detail(difficulty), "car": true}


## The longest nice length (m) whose bar is at most `longest` pixels at `pixels_per_metre`.
static func scale_bar(pixels_per_metre: float, longest: float) -> float:
	var best := NICE_METRES[0]
	for metres in NICE_METRES:
		if metres * pixels_per_metre <= longest:
			best = metres
	return best


## The grid's step (m): the longest nice length that still cuts `frame_width` pixels into GRID_CELLS cells or more.
static func grid_step(pixels_per_metre: float, frame_width: float) -> float:
	return scale_bar(pixels_per_metre, frame_width / GRID_CELLS)


## The contour interval for land from `lowest` to `highest` (m): the finest that draws no more than MOST_CONTOURS lines.
static func contour_step(lowest: float, highest: float) -> float:
	for step in CONTOUR_STEPS:
		if (highest - lowest) / step <= MOST_CONTOURS:
			return step
	return CONTOUR_STEPS[-1]


## How many contours make an index line (heavier and numbered): every fifth, or every fourth where the fifth is no round ten metres
## (2.5 m contours index every 10 m, 5 m every 20 m, 25 m every 100 m).
static func index_every(step: float) -> int:
	return 5 if is_zero_approx(fmod(step * 5.0, 10.0)) else 4


## The printed scale's denominator (1:N) at `pixels_per_metre`, rounded to a hundred.
static func ratio(pixels_per_metre: float) -> int:
	return roundi(1.0 / (pixels_per_metre * PAPER_METRES_PER_PIXEL) / 100.0) * 100


## The height printed for world height `y` in `biome` (StageCatalog's biome name).
static func altitude(y: float, biome: StringName) -> int:
	return roundi(y + float(DATUM.get(biome, 0.0)))
