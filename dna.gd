extends Node2D

var population_size := 200
var mutation_rate := 0.3
var canvas_size := 128

const junior_scene = preload("res://junior.tscn")

var population := []
var generation := 0
var mating_pool := []

@onready var subviewport := $SubViewportContainer/SubViewport
@onready var candidate_renderer := subviewport.get_node("CandidateRenderer")

@onready var bestfit_subviewport := $SubViewportContainer_BestFit/SubViewport
@onready var bestfit_renderer := bestfit_subviewport.get_node("CandidateRenderer")

@onready var population_node: Node2D = $population

@onready var generation_label: Label = $GenerationLabel
@onready var population_label: Label = $PopulationLabel
@onready var mutation_label: Label = $MutationLabel
@onready var best_fitness_label: Label = $BestFitnessLabel
@onready var best_generation_label: Label = $BestGenerationLabel

var best_individual = null
var best_fitness := -1.0
var best_generation := 0

const RENDER_SCALE := 0.6

var target_image: Image = null

# Target wiggle params
var target_wave_amplitude := 20.0
var target_wave_frequency := 1.5

func _ready():
	population_node.visible = false
	init_population()

	var tex = get_node("TargetImage").texture
	if tex:
		target_image = tex.get_image()
		target_image.convert(Image.FORMAT_L8)
	else:
		push_error("TargetImage texture missing!")

	start_generation_loop()

func init_population():
	for figure in population:
		if is_instance_valid(figure):
			figure.queue_free()
	population.clear()
	generation = 0
	best_individual = null
	best_fitness = -1.0
	best_generation = 0

	for i in range(population_size):
		var figure = junior_scene.instantiate()
		figure.position = Vector2.ZERO
		figure.randomize_traits()
		population_node.add_child(figure)
		population.append(figure)

	update_ui()

func start_generation_loop():
	generation_loop()

func generation_loop():
	while true:
		await get_tree().process_frame
		evaluate_population()
		selection()
		reproduction()
		generation += 1
		update_ui()
		await get_tree().process_frame

func evaluate_population():
	# Remove invalid individuals from population immediately
	population = population.filter(func(ind):
		return is_instance_valid(ind)
	)

	for child in candidate_renderer.get_children():
		child.queue_free()
	await get_tree().process_frame

	var candidate_center = subviewport.get_texture().get_size() / 2
	var candidate_offset = Vector2(0, 15)

	if not target_image:
		push_error("Target image missing! Cannot evaluate fitness.")
		return

	for individual in population:
		if not is_instance_valid(individual):
			continue

		var local_dna = individual.dna().duplicate(true)
		if not is_instance_valid(candidate_renderer):
			continue
		candidate_renderer.set_dna(local_dna)
		candidate_renderer.scale = Vector2(RENDER_SCALE, RENDER_SCALE)
		candidate_renderer.position = candidate_center - candidate_offset

		candidate_renderer.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame

		var img = subviewport.get_texture().get_image()
		img.convert(Image.FORMAT_L8)

		var fitness_score = 0.0
		var active_pixels = 0
		var w = min(img.get_width(), target_image.get_width())
		var h = min(img.get_height(), target_image.get_height())

		for y in range(h):
			for x in range(w):
				var pix1 = img.get_pixel(x, y).r
				var pix2 = target_image.get_pixel(x, y).r

				if pix1 > 0.05 or pix2 > 0.05:
					active_pixels += 1
					fitness_score += 1.0 - abs(pix1 - pix2)

		if is_instance_valid(individual):
			individual.fitness = fitness_score
			if fitness_score > best_fitness:
				best_fitness = fitness_score
				best_individual = individual
				best_generation = generation

				if is_instance_valid(bestfit_renderer):
					bestfit_renderer.set_dna(individual.dna().duplicate(true))
					var bestfit_center = bestfit_subviewport.get_texture().get_size() / 2
					bestfit_renderer.scale = Vector2(RENDER_SCALE, RENDER_SCALE)
					bestfit_renderer.position = bestfit_center - Vector2(0, 15)
					bestfit_renderer.queue_redraw()

					await get_tree().process_frame
					await get_tree().process_frame

func selection():
	mating_pool.clear()
	var max_fit = 0.0
	for ind in population:
		if is_instance_valid(ind):
			max_fit = max(max_fit, ind.fitness)

	if max_fit == 0.0:
		mating_pool = population.duplicate()
		return

	for ind in population:
		if not is_instance_valid(ind):
			continue
		var n = int(lerp(0, 100, ind.fitness / max_fit))
		for _i in range(n):
			mating_pool.append(ind)

	if mating_pool.is_empty():
		mating_pool = population.duplicate()

func reproduction():
	var new_population = []
	for _i in range(population_size):
		var parent_a = mating_pool[randi() % mating_pool.size()]
		var parent_b = mating_pool[randi() % mating_pool.size()]
		var child = junior_scene.instantiate()
		child.position = Vector2.ZERO
		var new_dna = crossover(parent_a.dna(), parent_b.dna())
		child.set_dna(new_dna)

		if is_instance_valid(child):
			mutate(child, mutation_rate)

		population_node.add_child(child)
		new_population.append(child)

	var old_population = population
	population = new_population

	await get_tree().process_frame

	for ind in old_population:
		if is_instance_valid(ind):
			ind.queue_free()

func crossover(dna_a: Dictionary, dna_b: Dictionary) -> Dictionary:
	var child := {}
	for key in dna_a.keys():
		# Always check type safety
		if typeof(dna_a[key]) == TYPE_FLOAT or typeof(dna_a[key]) == TYPE_INT:
			child[key] = dna_a[key] if randf() < 0.5 else dna_b[key]
		else:
			child[key] = dna_a[key] if randf() < 0.5 else dna_b[key]
	return child

func mutate(individual, rate):
	if not is_instance_valid(individual):
		return  # Avoid mutating freed objects

	var dna = individual.dna()
	for key in dna.keys():
		if randf() < rate:
			match key:
				"torso_rx": dna[key] = clamp(dna[key] + randf_range(-10, 10), 20, 70)
				"torso_ry": dna[key] = clamp(dna[key] + randf_range(-10, 10), 30, 90)
				"limb_length": dna[key] = clamp(dna[key] + randf_range(-20, 20), 50, 150)
				"limb_thickness": dna[key] = clamp(dna[key] + randf_range(-5, 5), 2, 20)
				"wave_amplitude": dna[key] = clamp(dna[key] + randf_range(-5, 5), 0, 30)
				"wave_frequency": dna[key] = clamp(dna[key] + randf_range(-0.5, 0.5), 0.1, 5.0)
				"hand_foot_size": dna[key] = clamp(dna[key] + randf_range(-5, 5), 5, 30)
				"fill_color": dna[key] = Color.from_hsv(randf(), 0.6, 0.9)
				"stroke_color": dna[key] = Color.from_hsv(randf(), 0.6, 0.9)
	individual.set_dna(dna)

func update_ui():
	var best_fit_in_pop = -INF
	for individual in population:
		if is_instance_valid(individual):
			best_fit_in_pop = max(best_fit_in_pop, individual.fitness)

	generation_label.text = "Total generations: %d" % generation
	best_fitness_label.text = "Best fitness: %.2f" % best_fitness
	best_generation_label.text = "Generation of best: %d" % best_generation
	population_label.text = "Population per generation: %d" % population_size
	mutation_label.text = "Mutation rate: %.2f%%" % (mutation_rate * 100)
