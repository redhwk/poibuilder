## PBAtlasTile — Wrap a palette atlas material so one cell can tile on Auto UVs.
##
## Used when a ShaderMaterial exposes `Albedo_Map` (Synty Generic_Standard and
## the Maps_SciFiOutpost variants that share it). Triplanar "worlds" materials
## are left alone. Tile rect lives on PBFace so a colorway swap keeps the cell.
@tool
class_name PBAtlasTile
extends RefCounted

const SHADER_PATH := "res://addons/poibuilder/materials/shaders/pb_atlas_tile.gdshader"

static func shader() -> Shader:
	if not ResourceLoader.exists(SHADER_PATH):
		return null
	return load(SHADER_PATH) as Shader

static func is_wrapper(mat: Material) -> bool:
	if not (mat is ShaderMaterial):
		return false
	var sh: Shader = (mat as ShaderMaterial).shader
	return sh != null and sh.resource_path == SHADER_PATH

## True when the palette card is a UV atlas (not triplanar-only).
## Albedo/base image a material presents (Synty Albedo_Map, wrap albedo_map, splat).
static func albedo_texture(mat: Material) -> Texture2D:
	if mat == null:
		return null
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).albedo_texture
	if mat is ORMMaterial3D:
		return (mat as ORMMaterial3D).albedo_texture
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		for pname in ["Albedo_Map", "albedo_map", "Texture_Map", "base_texture"]:
			var tex = sm.get_shader_parameter(pname)
			if tex is Texture2D:
				return tex
	return null

static func is_atlas_source(mat: Material) -> bool:
	if mat == null:
		return false
	if is_wrapper(mat):
		return true
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		return sm.get_shader_parameter("Albedo_Map") != null \
				or sm.get_shader_parameter("albedo_map") != null
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).albedo_texture != null
	return false

static func tile_key(origin: Vector2, size: Vector2) -> String:
	return "%.5f,%.5f,%.5f,%.5f" % [origin.x, origin.y, size.x, size.y]

static func face_tile_origin(face: PBFace) -> Vector2:
	if face == null:
		return Vector2.ZERO
	return face.atlas_tile_origin

static func face_tile_size(face: PBFace) -> Vector2:
	if face == null:
		return Vector2.ONE
	var s: Vector2 = face.atlas_tile_size
	if s.x <= 0.0001 or s.y <= 0.0001:
		return Vector2.ONE
	return s

static func uv_bounds(mesh_data: PBMeshData, face_indices: Array, channel: int = 0) -> Rect2:
	var empty := Rect2()
	if mesh_data == null or face_indices.is_empty():
		return empty
	var uvs: PackedVector2Array = mesh_data.textures1 if channel == 1 else mesh_data.textures0
	var min_u := INF
	var min_v := INF
	var max_u := -INF
	var max_v := -INF
	var found := false
	for fi in face_indices:
		var idx: int = int(fi)
		if idx < 0 or idx >= mesh_data.faces.size() or mesh_data.faces[idx] == null:
			continue
		for vi in mesh_data.faces[idx].get_distinct_indexes():
			if vi < 0 or vi >= uvs.size():
				continue
			var p: Vector2 = uvs[vi]
			min_u = minf(min_u, p.x)
			min_v = minf(min_v, p.y)
			max_u = maxf(max_u, p.x)
			max_v = maxf(max_v, p.y)
			found = true
	if not found:
		return empty
	return Rect2(min_u, min_v, maxf(max_u - min_u, 0.0001), maxf(max_v - min_v, 0.0001))

static func make_wrapper(source: Material, origin: Vector2, size: Vector2) -> ShaderMaterial:
	var sh := shader()
	if sh == null:
		return null
	var out := ShaderMaterial.new()
	out.shader = sh
	out.resource_path = ""
	_copy_maps(source, out)
	out.set_shader_parameter("tile_origin", origin)
	out.set_shader_parameter("tile_size", size)
	if source != null:
		out.resource_name = source.resource_name
		if out.resource_name.is_empty() and not source.resource_path.is_empty():
			out.resource_name = source.resource_path.get_file().get_basename()
	return out

static func _copy_maps(source: Material, dest: ShaderMaterial) -> void:
	if dest == null:
		return
	if source is ShaderMaterial:
		var sm := source as ShaderMaterial
		if is_wrapper(sm):
			dest.set_shader_parameter("albedo_map", sm.get_shader_parameter("albedo_map"))
			dest.set_shader_parameter("albedo_color", sm.get_shader_parameter("albedo_color"))
			dest.set_shader_parameter("emission_map", sm.get_shader_parameter("emission_map"))
			dest.set_shader_parameter("emission_color", sm.get_shader_parameter("emission_color"))
			dest.set_shader_parameter("enable_emission", sm.get_shader_parameter("enable_emission"))
			dest.set_shader_parameter("normal_map", sm.get_shader_parameter("normal_map"))
			dest.set_shader_parameter("normal_amount", sm.get_shader_parameter("normal_amount"))
			dest.set_shader_parameter("metallic", sm.get_shader_parameter("metallic"))
			dest.set_shader_parameter("smoothness", sm.get_shader_parameter("smoothness"))
			dest.set_shader_parameter("enable_alpha_clip", sm.get_shader_parameter("enable_alpha_clip"))
			dest.set_shader_parameter("alpha_clip_threshold", sm.get_shader_parameter("alpha_clip_threshold"))
			return
		var albedo = sm.get_shader_parameter("Albedo_Map")
		if albedo != null:
			dest.set_shader_parameter("albedo_map", albedo)
		var base_c = sm.get_shader_parameter("BaseColor")
		if base_c != null:
			dest.set_shader_parameter("albedo_color", base_c)
		var em = sm.get_shader_parameter("Emission_Map")
		if em != null:
			dest.set_shader_parameter("emission_map", em)
		var em_c = sm.get_shader_parameter("Emission_Color")
		if em_c != null:
			dest.set_shader_parameter("emission_color", em_c)
		var em_on = sm.get_shader_parameter("Enable_Emission")
		if em_on != null:
			dest.set_shader_parameter("enable_emission", bool(em_on))
		var nrm = sm.get_shader_parameter("Normal_Map")
		if nrm != null:
			dest.set_shader_parameter("normal_map", nrm)
		var nrm_amt = sm.get_shader_parameter("Normal_Amount")
		if nrm_amt != null:
			dest.set_shader_parameter("normal_amount", float(nrm_amt))
		var met = sm.get_shader_parameter("Metallic")
		if met != null:
			dest.set_shader_parameter("metallic", float(met))
		var smth = sm.get_shader_parameter("Smoothness")
		if smth != null:
			dest.set_shader_parameter("smoothness", float(smth))
		var clip = sm.get_shader_parameter("EnableAlphaClipping")
		if clip != null:
			dest.set_shader_parameter("enable_alpha_clip", bool(clip))
		var clip_t = sm.get_shader_parameter("Alpha_Clip_Threshold")
		if clip_t != null:
			dest.set_shader_parameter("alpha_clip_threshold", float(clip_t))
		return
	if source is StandardMaterial3D:
		var std := source as StandardMaterial3D
		dest.set_shader_parameter("albedo_map", std.albedo_texture)
		dest.set_shader_parameter("albedo_color", std.albedo_color)
		dest.set_shader_parameter("emission_map", std.emission_texture)
		dest.set_shader_parameter("emission_color", Color(std.emission))
		dest.set_shader_parameter("enable_emission", std.emission_enabled)
		dest.set_shader_parameter("normal_map", std.normal_texture)
		dest.set_shader_parameter("normal_amount", std.normal_scale)
		dest.set_shader_parameter("metallic", std.metallic)
		dest.set_shader_parameter("smoothness", 1.0 - std.roughness)
		dest.set_shader_parameter("enable_alpha_clip", std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
		dest.set_shader_parameter("alpha_clip_threshold", std.alpha_scissor_threshold)

## Assigns `incoming` to faces, wrapping atlas palette cards and keeping each
## face's stored cell when the user swaps colorways.
static func apply_to_faces(mesh_data: PBMeshData, target_faces: Array, incoming: Material) -> void:
	if mesh_data == null or target_faces.is_empty() or incoming == null:
		return
	if not is_atlas_source(incoming) and not is_wrapper(incoming):
		mesh_data.set_faces_material(target_faces, incoming)
		return

	var groups: Dictionary = {}
	var face_objs: Array = []
	for item in target_faces:
		var face: PBFace = item as PBFace
		if face == null and item is int:
			var fi: int = int(item)
			if fi >= 0 and fi < mesh_data.faces.size():
				face = mesh_data.faces[fi]
		if face == null:
			continue
		face_objs.append(face)
		var key := tile_key(face_tile_origin(face), face_tile_size(face))
		if not groups.has(key):
			groups[key] = {
				"origin": face_tile_origin(face),
				"size": face_tile_size(face),
				"faces": [],
			}
		groups[key]["faces"].append(face)

	if face_objs.is_empty():
		mesh_data.set_faces_material(target_faces, incoming)
		return

	for key in groups:
		var g: Dictionary = groups[key]
		var wrapped := make_wrapper(incoming, g["origin"], g["size"])
		if wrapped == null:
			mesh_data.set_faces_material(g["faces"], incoming)
		else:
			mesh_data.set_faces_material(g["faces"], wrapped)

## Re-applies wrap only on faces that already have it, using each face's own
## material. Never stamps one face's wrap onto the others (that painted
## extrude walls with the cap texture).
static func sync_face_wrappers(mesh_data: PBMeshData, face_ids: PackedInt32Array) -> void:
	if mesh_data == null or face_ids.is_empty():
		return
	var groups: Dictionary = {}
	for fi in face_ids:
		if fi < 0 or fi >= mesh_data.faces.size() or mesh_data.faces[fi] == null:
			continue
		var face: PBFace = mesh_data.faces[fi]
		var mat := mesh_data.get_face_material(face)
		if mat == null:
			continue
		var locked_cell := face_tile_size(face) != Vector2.ONE
		if not is_wrapper(mat) and not (is_atlas_source(mat) and locked_cell):
			continue
		var key := "%s|%s" % [mat.get_instance_id(), tile_key(face_tile_origin(face), face_tile_size(face))]
		if not groups.has(key):
			groups[key] = {"mat": mat, "faces": []}
		groups[key]["faces"].append(face)
	for key in groups:
		var g: Dictionary = groups[key]
		apply_to_faces(mesh_data, g["faces"], g["mat"])

## Reads the current UV island as the atlas cell, stores it on the faces,
## switches them to Auto UV (meter tiling), and updates the wrapper uniforms.
static func lock_tile_from_uvs(mesh_data: PBMeshData, face_indices: Array, channel: int = 0) -> bool:
	if mesh_data == null or face_indices.is_empty():
		return false
	var bounds := uv_bounds(mesh_data, face_indices, channel)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return false
	# A cell on a 0–1 sheet is small. If the island is already Auto-meter UVs
	# (span > 1), do not treat that as a cell.
	if bounds.size.x > 1.0001 or bounds.size.y > 1.0001:
		return false

	var origin := bounds.position
	var size := bounds.size
	var faces: Array = []
	for fi in face_indices:
		var idx: int = int(fi)
		if idx < 0 or idx >= mesh_data.faces.size() or mesh_data.faces[idx] == null:
			continue
		var face: PBFace = mesh_data.faces[idx]
		face.atlas_tile_origin = origin
		face.atlas_tile_size = size
		faces.append(face)

	if faces.is_empty():
		return false

	PBUvOps.convert_to_auto(mesh_data, face_indices)
	var sample: Material = mesh_data.get_face_material(faces[0])
	if sample == null:
		return true
	apply_to_faces(mesh_data, faces, sample)
	return true
