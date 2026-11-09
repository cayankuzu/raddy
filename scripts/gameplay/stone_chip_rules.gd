class_name StoneChipRules
extends RefCounted
## When a stone off the road marks a windshield, for the host (Cabin): GAME_DESIGN §6. Rare for a car on its own; the real danger
## is the car in front, whose stones come straight at the glass within FOLLOW_RANGE metres behind it on the road, more the closer
## and the faster. Only loose ground throws them: none on tarmac, snow or mud. The first stone leaves a bullseye, the second cracks
## the glass, the ones after that make the crack worse. Pure: no nodes, no network.

## What throws stones that reach a windshield.
const LOOSE: Array[StringName] = [Surface.GRAVEL, Surface.DIRT, Surface.SAND]
## Below this speed (m/s) a stone does nothing to the glass; the chance grows with speed from REFERENCE_SPEED's value.
const MIN_SPEED := 12.0
const REFERENCE_SPEED := 20.0
## Chance per second at REFERENCE_SPEED of a stone on the glass with nobody in front: one run in ten cracks (`tools\chip_odds.ps1`).
const ALONE_RATE := 0.0059
## How close (m along the road) the car in front must be, and the chance per second added right behind it at REFERENCE_SPEED.
const FOLLOW_RANGE := 30.0
const FOLLOW_RATE := 0.3
## A car slower than this (m/s) throws nothing at the one behind it.
const THROWING_SPEED := 8.0
## The stone that cracks the glass, and the last one that still changes it.
const CRACKS_AT := 2
const MOST_HITS := 6
const NOBODY_AHEAD := INF


## Chance per second of a stone on the glass of a car going `speed` m/s on `surface`, `gap_ahead` metres behind the next car.
static func chance_per_second(speed: float, surface: StringName, gap_ahead: float) -> float:
	if speed < MIN_SPEED or not LOOSE.has(surface):
		return 0.0
	var closeness := clampf(1.0 - gap_ahead / FOLLOW_RANGE, 0.0, 1.0)
	return (ALONE_RATE + FOLLOW_RATE * closeness * closeness) * speed / REFERENCE_SPEED


## Metres along the road to the nearest of `others` (their distances along the stage) ahead of `own`.
static func gap_ahead(own: float, others: Array[float]) -> float:
	var nearest := NOBODY_AHEAD
	for other in others:
		if other > own:
			nearest = minf(nearest, other - own)
	return nearest


## How many runs in 100 end with a bullseye at least and how many with a crack, given the stones `expected` in a run.
static func odds_per_100(expected: float) -> Vector2:
	var none := exp(-expected)
	return Vector2(1.0 - none, 1.0 - none * (1.0 + expected)) * 100.0
