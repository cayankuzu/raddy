class_name RaceSettings
## The host's race settings (spec §6.1, §14): the stage (StageCatalog index), difficulty and
## weather, each of which may be Random, and Surprise Rally for all at once. `resolve()` turns the
## choices into a concrete, compatible package from a roll, so every peer can show the same
## summary before the start. The stage decides the biome and the world seed.

const RANDOM := -1
enum Difficulty { EXPLORE, RALLY, REDLINE }
enum Biome { FOREST, DESERT, MOUNTAIN }
enum Weather { CLEAR, RAIN, FOG, SNOW, DUST_STORM }

## Weather that fits each biome (spec §14.3: no snow in the desert, dust storms only where dry).
const COMPATIBLE_WEATHER := {
	Biome.FOREST: [Weather.CLEAR, Weather.RAIN, Weather.FOG],
	Biome.DESERT: [Weather.CLEAR, Weather.FOG, Weather.DUST_STORM],
	Biome.MOUNTAIN: [Weather.CLEAR, Weather.RAIN, Weather.FOG, Weather.SNOW],
}
## Grip multiplier on every surface (spec §14.2).
const GRIP_SCALE := {Weather.CLEAR: 1.0, Weather.RAIN: 0.8, Weather.FOG: 1.0, Weather.SNOW: 0.55, Weather.DUST_STORM: 0.92}
## Fog density for the environment: how far you see.
const FOG_DENSITY := {Weather.CLEAR: 0.0015, Weather.RAIN: 0.004, Weather.FOG: 0.02, Weather.SNOW: 0.008, Weather.DUST_STORM: 0.014}

## Road width multiplier: Explore is wider, Redline narrower and more technical.
const WIDTH_SCALE := {Difficulty.EXPLORE: 1.2, Difficulty.RALLY: 1.0, Difficulty.REDLINE: 0.85}
## Time added to a team's result per recovery (spec 16.3: small, testable, not punishing).
const RECOVERY_PENALTY_MS := {Difficulty.EXPLORE: 0, Difficulty.RALLY: 3000, Difficulty.REDLINE: 6000}

const DIFFICULTY_KEYS := ["DIFFICULTY_EXPLORE", "DIFFICULTY_RALLY", "DIFFICULTY_REDLINE"]
const BIOME_KEYS := ["BIOME_FOREST", "BIOME_DESERT", "BIOME_MOUNTAIN"]
const WEATHER_KEYS := ["WEATHER_CLEAR", "WEATHER_RAIN", "WEATHER_FOG", "WEATHER_SNOW", "WEATHER_DUST_STORM"]


## What the host picks in the room before the random choices are made.
static func defaults() -> Dictionary:
	return {"stage": 0, "difficulty": Difficulty.RALLY, "weather": RANDOM}


static func surprise() -> Dictionary:
	return {"stage": RANDOM, "difficulty": RANDOM, "weather": RANDOM}


## Replaces every Random with a concrete value from `roll` and fixes incompatible pairs (a weather
## the stage's biome cannot have is re-rolled among the stage's own). Adds the stage's "biome" and
## world "seed". Returns a new dictionary; the input is not changed.
static func resolve(choices: Dictionary, roll: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll
	var out := choices.duplicate()
	if int(out.get("stage", RANDOM)) == RANDOM:
		out.stage = rng.randi_range(0, StageCatalog.count() - 1)
	out.stage = clampi(int(out.stage), 0, StageCatalog.count() - 1)
	var stage := StageCatalog.get_stage(out.stage)
	out.biome = int(stage.biome)
	out.seed = int(stage.seed)
	if int(out.get("difficulty", RANDOM)) == RANDOM:
		out.difficulty = rng.randi_range(0, Difficulty.size() - 1)
	out.difficulty = clampi(int(out.difficulty), 0, Difficulty.size() - 1)
	var allowed: Array = []
	for weather in stage.get("weathers", COMPATIBLE_WEATHER[out.biome]):
		if COMPATIBLE_WEATHER[out.biome].has(weather):
			allowed.append(weather)
	if int(out.get("weather", RANDOM)) == RANDOM or not COMPATIBLE_WEATHER[out.biome].has(int(out.weather)):
		out.weather = allowed[rng.randi_range(0, allowed.size() - 1)]
	return out


static func is_resolved(settings: Dictionary) -> bool:
	for key in ["stage", "difficulty", "weather"]:
		if int(settings.get(key, RANDOM)) == RANDOM:
			return false
	return true


static func width_scale(difficulty: int) -> float:
	return WIDTH_SCALE.get(difficulty, 1.0)


static func recovery_penalty_ms(difficulty: int) -> int:
	return RECOVERY_PENALTY_MS.get(difficulty, 3000)


static func note_detail(difficulty: int) -> int:
	match difficulty:
		Difficulty.EXPLORE:
			return PaceNotes.DETAIL_FULL
		Difficulty.REDLINE:
			return PaceNotes.DETAIL_SUMMARY
	return PaceNotes.DETAIL_STANDARD


static func grip_scale(weather: int) -> float:
	return GRIP_SCALE.get(weather, 1.0)


static func fog_density(weather: int) -> float:
	return FOG_DENSITY.get(weather, 0.0015)


## Translation keys of the stage, difficulty and weather (Random shows as its own key), for the
## room summary.
static func summary_keys(settings: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	var stage := int(settings.get("stage", RANDOM))
	keys.append(StageCatalog.name_key(stage) if stage != RANDOM else "CHOICE_RANDOM")
	var difficulty := int(settings.get("difficulty", RANDOM))
	keys.append(DIFFICULTY_KEYS[difficulty] if difficulty != RANDOM else "CHOICE_RANDOM")
	var weather := int(settings.get("weather", RANDOM))
	keys.append(WEATHER_KEYS[weather] if weather != RANDOM else "CHOICE_RANDOM")
	return keys
