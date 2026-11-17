class_name GateRules
## A farm gate across a shortcut (a bypass's price `gate`): rammed open at speed, at a cost in damage and speed, or opened
## from the standing car by a crew that holds the job for OPEN_SECONDS. Pure; FarmGate plays it, the host decides
## (StageEvents, RaceSession).

## At least this fast toward the gate (m/s, about 20 km/h) and it bursts open; slower, it holds and the car stops on it.
const RAM_SPEED := 5.5
## Of its speed toward the gate a car keeps this share through it.
const RAM_KEEP := 0.6
## The hit the damage judge feels (an impact of this many m/s per m/s of ramming speed, RaceSession._judge_impact).
const RAM_HIT := 0.55
## The car's middle this far before the gate's line: it is on it.
const RAM_REACH := 3.2
## Opening it by hand: how long the job takes, from how close, and how still the car must stand.
const OPEN_SECONDS := 3.0
const OPEN_REACH := 6.0
const STANDING_SPEED := 1.0


## True when a car `ahead` metres before the gate's line (negative: past it), going `speed` m/s toward it, bursts it.
static func rams(ahead: float, speed: float) -> bool:
	return ahead > -0.5 and ahead < RAM_REACH and speed >= RAM_SPEED


## The impact strength of a ram at `speed` m/s.
static func ram_hit(speed: float) -> float:
	return speed * RAM_HIT


## True when a crew may work the gate: the car stands within OPEN_REACH of it.
static func may_open(distance: float, speed: float) -> bool:
	return distance <= OPEN_REACH and absf(speed) < STANDING_SPEED
