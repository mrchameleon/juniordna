extends Node2D

# Traits
var limb_length = 100.0
var limb_thickness = 10.0
var wave_amplitude = 15.0
var wave_frequency = 1.5
var torso_rx = 45.0
var torso_ry = 70.0
var hand_foot_size = 20.0

var fitness: float = 0.0


var fill_color = Color(1, 1, 1)
var stroke_color = Color(0, 0, 0)

var torso_center = Vector2.ZERO

# Limb positions
var left_arm_base = Vector2.ZERO
var right_arm_base = Vector2.ZERO
var left_leg_base = Vector2.ZERO
var right_leg_base = Vector2.ZERO

func _ready():
	randomize()
	randomize_traits()
	torso_center = get_viewport_rect().size / 2
	initialize_limb_positions()

func dna():
	# Placeholder DNA function - returns a dictionary or array of traits for now
	return {
		"limb_length": limb_length,
		"limb_thickness": limb_thickness,
		"wave_amplitude": wave_amplitude,
		"wave_frequency": wave_frequency,
		"torso_rx": torso_rx,
		"torso_ry": torso_ry,
		"hand_foot_size": hand_foot_size,
		"fill_color": fill_color,
		"stroke_color": stroke_color
	}
	
func set_dna(dna_dict: Dictionary) -> void:
	if "limb_length" in dna_dict:
		limb_length = dna_dict["limb_length"]
	if "limb_thickness" in dna_dict:
		limb_thickness = dna_dict["limb_thickness"]
	if "wave_amplitude" in dna_dict:
		wave_amplitude = dna_dict["wave_amplitude"]
	if "wave_frequency" in dna_dict:
		wave_frequency = dna_dict["wave_frequency"]
	if "torso_rx" in dna_dict:
		torso_rx = dna_dict["torso_rx"]
	if "torso_ry" in dna_dict:
		torso_ry = dna_dict["torso_ry"]
	if "hand_foot_size" in dna_dict:
		hand_foot_size = dna_dict["hand_foot_size"]
	if "fill_color" in dna_dict:
		fill_color = dna_dict["fill_color"]
	if "stroke_color" in dna_dict:
		stroke_color = dna_dict["stroke_color"]

func randomize_traits():
	limb_length = randf_range(50.0, 150.0)
	limb_thickness = randf_range(5.0, 20.0)
	wave_amplitude = randf_range(5.0, 30.0)
	wave_frequency = randf_range(0.5, 3.0)
	torso_rx = randf_range(30.0, 60.0)
	torso_ry = randf_range(50.0, 90.0)
	hand_foot_size = randf_range(10.0, 30.0)
	fill_color = Color(randf(), randf(), randf())
	stroke_color = Color(randf(), randf(), randf())

func initialize_limb_positions():
	left_arm_base = torso_center + Vector2(-torso_rx, -torso_ry / 4)
	right_arm_base = torso_center + Vector2(torso_rx, -torso_ry / 4)
	left_leg_base = torso_center + Vector2(-torso_rx / 2, torso_ry)
	right_leg_base = torso_center + Vector2(torso_rx / 2, torso_ry)

func _draw():
	# Draw torso as ellipse
	draw_oval(torso_center, torso_rx, torso_ry, fill_color)
	draw_oval_outline(torso_center, torso_rx, torso_ry, stroke_color, limb_thickness / 2)

	# Draw limbs as Bezier curves with waving motion (simplified here)
	var time = Time.get_ticks_msec() / 1000.0
	draw_wavy_limb(left_arm_base, Vector2(-limb_length, 0), time)
	draw_wavy_limb(right_arm_base, Vector2(limb_length, 0), time)
	draw_wavy_limb(left_leg_base, Vector2(-limb_length / 1.5, limb_length), time)
	draw_wavy_limb(right_leg_base, Vector2(limb_length / 1.5, limb_length), time)

	# Draw hands and feet as ovals
	draw_oval(left_arm_base + Vector2(-limb_length, 0), hand_foot_size, hand_foot_size * 0.7, fill_color)
	draw_oval(right_arm_base + Vector2(limb_length, 0), hand_foot_size, hand_foot_size * 0.7, fill_color)
	draw_oval(left_leg_base + Vector2(-limb_length / 1.5, limb_length), hand_foot_size, hand_foot_size * 0.7, fill_color)
	draw_oval(right_leg_base + Vector2(limb_length / 1.5, limb_length), hand_foot_size, hand_foot_size * 0.7, fill_color)

func draw_wavy_limb(base: Vector2, offset: Vector2, time: float):
	# Draw a simple wave along the limb line using a Bezier curve approximation
	var cp1 = base + offset * 0.33 + Vector2(0, sin(time * wave_frequency) * wave_amplitude)
	var cp2 = base + offset * 0.66 + Vector2(0, -sin(time * wave_frequency * 1.5) * wave_amplitude)
	var tip = base + offset
	draw_bezier(base, cp1, cp2, tip, stroke_color, limb_thickness)

# Custom draw functions (implement these in your code)

func draw_oval(center: Vector2, rx: float, ry: float, color: Color):
	var points = PackedVector2Array()
	for i in range(0, 360, 10):
		var rad =  deg_to_rad(i)
		points.append(center + Vector2(cos(rad) * rx, sin(rad) * ry))
	draw_colored_polygon(points, color)

func draw_oval_outline(center: Vector2, rx: float, ry: float, color: Color, thickness: float):
	var points = PackedVector2Array()
	for i in range(0, 360, 10):
		var rad = deg_to_rad(i)
		points.append(center + Vector2(cos(rad) * rx, sin(rad) * ry))
	draw_polyline(points, color, thickness)

func draw_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color: Color, thickness: float):
	var points = PackedVector2Array()
	for t_i in range(0, 101):
		var t = t_i / 100.0
		var point = cubic_bezier_point(p0, p1, p2, p3, t)
		points.append(point)
	draw_polyline(points, color, thickness)

func cubic_bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	return p0 * pow(1 - t, 3) + p1 * 3 * t * pow(1 - t, 2) + p2 * 3 * pow(t, 2) * (1 - t) + p3 * pow(t, 3)
