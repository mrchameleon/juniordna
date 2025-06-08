extends Node2D

@export var population_size := 100
@export var mutation_rate := 0.1
@export var canvas_size := 128

const junior_scene = preload("res://junior.tscn")

var population := []
var generation := 0
var mating_pool := []

@onready var subviewport := $SubViewportContainer/SubViewport
@onready var candidate_renderer := subviewport.get_node("CandidateRenderer")

@onready var bestfit_subviewport := $SubViewportContainer_BestFit/SubViewport
@onready var bestfit_renderer := bestfit_subviewport.get_node("CandidateRenderer")

@onready var generation_label : Label = $GenerationLabel
@onready var population_label : Label = $PopulationLabel
@onready var best_fitness_label : Label = $BestFitnessLabel

var best_individual = null
var best_fitness := -1.0

func _ready():
	init_population()
	start_generation_loop()

func init_population():
	for figure in population:
		if is_instance_valid(figure):
			figure.queue_free()
	population.clear()
	generation = 0
	best_individual = null
	best_fitness = -1.0

	for i in range(population_size):
		var figure = junior_scene.instantiate()
		figure.position = subviewport.size / 2
		figure.randomize_traits()
		population.append(figure)

	update_ui()

func start_generation_loop():
	generation_loop()

func generation_loop() -> void:
	while true:
		await get_tree().process_frame
		evaluate_population()
		selection()
		reproduction()
		generation += 1
		update_ui()
		await get_tree().process_frame

func evaluate_population() -> void:
	for child in candidate_renderer.get_children():
		child.queue_free()
	await get_tree().process_frame  # Let Godot fully process the deletions

	for individual in population:
		if not is_instance_valid(individual):
			continue

		var local_dna = individual.dna().duplicate(true)
		candidate_renderer.set_dna(local_dna)
		candidate_renderer.position = subviewport.get_texture().get_size() / 2
		candidate_renderer.queue_redraw()
		await get_tree().process_frame

		var img = subviewport.get_texture().get_image()
		img.convert(Image.FORMAT_L8)

		if not has_node("TargetImage"):
			push_error("TargetImage not found! Skipping fitness evaluation.")
			individual.fitness = 0.0
			continue

		var target_image = get_node("TargetImage").texture.get_image()
		target_image.convert(Image.FORMAT_L8)

		var fitness_score = 0.0
		for y in range(min(img.get_height(), target_image.get_height())):
			for x in range(min(img.get_width(), target_image.get_width())):
				var pix1 = img.get_pixel(x, y).r
				var pix2 = target_image.get_pixel(x, y).r
				fitness_score += 1.0 - abs(pix1 - pix2)

		if is_instance_valid(individual):
			individual.fitness = fitness_score / float(img.get_width() * img.get_height())

			if individual.fitness > best_fitness:
				best_fitness = individual.fitness
				best_individual = individual
				bestfit_renderer.set_dna(individual.dna())
				bestfit_renderer.position = bestfit_subviewport.get_texture().get_size() / 2
				bestfit_renderer.queue_redraw()

func selection():
	mating_pool.clear()
	var max_fit = 0.0
	for ind in population:
		if is_instance_valid(ind) and ind.fitness > max_fit:
			max_fit = ind.fitness

	if max_fit == 0.0:
		mating_pool = population.duplicate()
		return

	for ind in population:
		if not is_instance_valid(ind):
			continue
		var n = int(lerp(0, 100, ind.fitness / max_fit))
		for i in range(n):
			mating_pool.append(ind)

	if mating_pool.size() == 0:
		mating_pool = population.duplicate()

func reproduction():
	var new_population = []
	for i in range(population_size):
		var parent_a = mating_pool[randi() % mating_pool.size()]
		var parent_b = mating_pool[randi() % mating_pool.size()]
		var child = junior_scene.instantiate()
		child.position = subviewport.size / 2
		var new_dna = crossover(parent_a.dna(), parent_b.dna())
		child.set_dna(new_dna)
		mutate(child, mutation_rate)
		new_population.append(child)

	for old_ind in population:
		if is_instance_valid(old_ind):
			old_ind.queue_free()
	population = new_population

func crossover(dna_a: Dictionary, dna_b: Dictionary) -> Dictionary:
	var child = {}
	for key in dna_a.keys():
		child[key] = dna_a[key] if randf() < 0.5 else dna_b[key]
	return child

func mutate(individual, rate):
	var dna = individual.dna()
	if randf() < rate:
		dna["torso_rx"] = clamp(dna["torso_rx"] + randf_range(-5, 5), 20, 70)
	if randf() < rate:
		dna["torso_ry"] = clamp(dna["torso_ry"] + randf_range(-5, 5), 30, 90)
	if randf() < rate:
		dna["limb_length"] = clamp(dna["limb_length"] + randf_range(-10, 10), 50, 150)
	if randf() < rate:
		dna["fill_color"] = Color.from_hsv(randf(), 0.6, 0.9)
	individual.set_dna(dna)

func update_ui():
	generation_label.text = "Generation: %d" % generation
	population_label.text = "Population: %d" % population.size()
	best_fitness_label.text = "Best Fitness: %.4f" % best_fitness
