class_name VicinityLootLayout
extends RefCounted

var width: int = 8
var rows: int = 6
var placements: Array[Dictionary]=[]

func rebuild(nodes: Array[DroppedItem], columns: int = 8) -> void:
	placements.clear()
	width=columns
	rows=6
	for node in nodes: width=maxi(width,node.item.get_size().x)
	var occupied: Dictionary={}
	for node in nodes:
		var extent: Vector2i=node.item.get_size()
		var position:=Vector2i.ZERO
		var found: bool=false
		while not found:
			for x in range(width-extent.x+1):
				position.x=x
				found=true
				for y in range(extent.y):
					for dx in range(extent.x):
						if occupied.has(position+Vector2i(dx,y)): found=false
				if found: break
			if not found: position.y+=1
		for y in range(extent.y):
			for x in range(extent.x): occupied[position+Vector2i(x,y)]=true
		placements.append({"item":node.item,"world":node,"position":position,"extent":extent})
		rows=maxi(rows,position.y+extent.y)

func get_at_cell(cell: Vector2i) -> Dictionary:
	for placement in placements:
		if Rect2i(placement.position,placement.extent).has_point(cell): return placement
	return {}
