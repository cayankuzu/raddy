class_name RaceSettings
## The host's race settings (spec §6.1, §14): difficulty, laps, biome, weather, each of which may
## be Random, and Surprise Rally for all at once. `resolve()` turns the choices into a concrete,
## compatible package from a seed, so every peer can show the same summary before the start.

const RANDOM := -1
enum Difficulty { EXPLORE, RALLY, REDLINE }
enum Biome { FOREST, DESERT, MOUNTAIN }
enum Weather { CLEAR, RAIN, FOG, SNOW, DUST_STORM }
const MIN_LAPS := 1
const MAX_LAPS := 3

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

const DIFFICULTY_KEYS := ["DIFFICULTY_EXPLORE", "DIFFICULTY_RALLY", "DIFFICULTY_REDLINE"]
const BIOME_KEYS := ["BIOME_FOREST", "BIOME_DESERT", "BIOME_MOUNTAIN"]
const WEATHER_KEYS := ["WEATHER_CLEAR", "WEATHER_RAIN", "WEATHER_FOG", "WEATHER_SNOW", "WEATHER_DUST_STORM"]


## What the host picks in the lobby before the random choices are made.
static func defaults() -> Dictionary:
	return {"difficulty": Difficulty.RALLY, "laps": 1, "biome": Biome.FOREST, "weather": Weather.CLEAR, "seed": RANDOM}


static func surprise() -> Dictionary:
	return {"difficulty": RANDOM, "laps": RANDOM, "biome": RANDOM, "weather": RANDOM, "seed": RANDOM}


## Replaces every Random with a concrete value from `seed` and fixes incompatible pairs
## (an incompatible weather is re-rolled among the biome's own). Returns a new dictionary with
## the final "seed" included; the input is not changed.
static func resolve(choices: Dictionary, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := choices.duplicate()
	out.seed = seed if int(choices.get("seed", RANDOM)) == RANDOM else int(choices.seed)
	if int(out.get("difficulty", RANDOM)) == RANDOM:
		out.difficulty = rng.randi_range(0, Difficulty.size() - 1)
	if int(out.get("laps", RANDOM)) == RANDOM:
		out.laps = rng.randi_range(MIN_LAPS, MAX_LAPS)
	out.laps = clampi(int(out.laps), MIN_LAPS, MAX_LAPS)
	if int(out.get("biome", RANDOM)) == RANDOM:
		out.biome = rng.randi_range(0, Biome.size() - 1)
	out.biome = clampi(int(out.biome), 0, Biome.size() - 1)
	var allowed: Array = COMPATIBLE_WEATHER[out.biome]
	if int(out.get("weather", RANDOM)) == RANDOM or not allowed.has(int(out.weather)):
		out.weather = allowed[rng.randi_range(0, allowed.size() - 1)]
	out.difficulty = clampi(int(out.difficulty), 0, Difficulty.size() - 1)
	return out


static func is_resolved(settings: Dictionary) -> bool:
	for key in ["difficulty", "laps", "biome", "weather", "seed"]:
		if int(settings.get(key, RANDOM)) == RANDOM:
			return false
	return true


static func grip_scale(weather: int) -> float:
	return GRIP_SCALE.get(weather, 1.0)


static func fog_density(weather: int) -> float:
	return FOG_DENSITY.get(weather, 0.0015)


## Translation keys of the four choices (Random shows as its own key), for lobby summaries.
static func summary_keys(settings: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	var difficulty := int(settings.get("difficulty", RANDOM))
	keys.append(DIFFICULTY_KEYS[difficulty] if difficulty != RANDOM else "CHOICE_RANDOM")
	var laps := int(settings.get("laps", RANDOM))
	keys.append(("LAPS_%d" % laps) if laps != RANDOM else "CHOICE_RANDOM")
	var biome := int(settings.get("biome", RANDOM))
	keys.append(BIOME_KEYS[biome] if biome != RANDOM else "CHOICE_RANDOM")
	var weather := int(settings.get("weather", RANDOM))
	keys.append(WEATHER_KEYS[weather] if weather != RANDOM else "CHOICE_RANDOM")
	return keys
