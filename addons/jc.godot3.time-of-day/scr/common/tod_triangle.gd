tool
class_name TOD_Triangle extends ArrayMesh

func _init() -> void:
	var verts = PoolVector3Array()
	verts.append(Vector3(-1.0, -1.0, 0.0))
	verts.append(Vector3(-1.0, 3.0, 0.0))
	verts.append(Vector3(3.0, -1.0, 0.0))

	var mesh_array = []
	mesh_array.resize(Mesh.ARRAY_MAX) 
	mesh_array[Mesh.ARRAY_VERTEX] = verts
	
	add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)
