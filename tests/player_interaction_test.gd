extends "res://tests/inventory_grid_test.gd"

class TestTarget extends Node3D:
	var calls: int=0
	func can_interact(_actor: Node) -> bool: return true
	func get_interaction_prompt(_actor: Node) -> String: return "[F] "+name
	func get_interaction_position() -> Vector3: return global_position
	func interact(_actor: Node) -> Dictionary:
		calls+=1
		return {"success":true}

func target(parent: Node3D, location: Vector3, target_name: String) -> TestTarget:
	var result:=TestTarget.new()
	result.name=target_name
	var area:=Area3D.new()
	area.collision_layer=16
	area.collision_mask=0
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3.ONE*0.25
	collision.shape=shape
	area.add_child(collision)
	result.add_child(area)
	parent.add_child(result)
	result.global_position=location
	return result

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/player/player_interactor.gd"),"player interactor exists")
	check(FileAccess.file_exists("res://scripts/ui/interaction_prompt.gd"),"independent prompt exists")
	if failures==0:
		var world:=Node3D.new()
		root.add_child(world)
		current_scene=world
		var player: Variant=load("res://scenes/player/player.tscn").instantiate()
		world.add_child(player)
		player.set_physics_process(false)
		player.firearm.set_physics_process(false)
		var interactor: Variant=player.get_node("PlayerInteractor")
		var prompt: Variant=player.get_node("InteractionPrompt")
		var camera: Camera3D=player.camera
		var origin: Vector3=camera.global_position
		var a:=target(world,origin+Vector3.FORWARD*2,"A")
		await physics_frame
		await physics_frame
		check(interactor.update_target()==a,"center ray resolves target at2m")
		check(prompt.label.visible and prompt.label.text.contains("A"),"target signal updates prompt")
		for distance in [2.49,2.5,2.51]:
			a.global_position=origin+Vector3.FORWARD*distance
			await physics_frame
			await physics_frame
			check((interactor.update_target()==a)==(distance<=2.5),"inclusive root-position range: "+str(distance))
		a.global_position=origin+Vector3.FORWARD*2
		var wall:=StaticBody3D.new()
		var collision:=CollisionShape3D.new()
		collision.shape=BoxShape3D.new()
		wall.add_child(collision)
		world.add_child(wall)
		wall.global_position=origin+Vector3.FORWARD
		await physics_frame
		await physics_frame
		check(interactor.update_target()==null and not prompt.label.visible,"nearest WORLD collision hides blocked interaction")
		wall.queue_free()
		await physics_frame
		await physics_frame
		camera.rotation.y=PI/2
		check(interactor.update_target()==null,"nearby item off crosshair is not target")
		camera.rotation.y=0
		var b:=target(world,origin+Vector3.FORWARD*1.5,"B")
		await physics_frame
		await physics_frame
		check(interactor.update_target()==b and prompt.label.text.contains("B"),"nearest target and prompt change immediately")
		player.set_inventory_open(true)
		check(interactor.update_target()==null and not interactor.try_interact(),"inventory-open blocks target and F interaction")
		player.set_inventory_open(false)
		check(interactor.update_target()==b and interactor.try_interact() and b.calls==1,"generic interaction dispatches to target interface")
		check(InputMap.has_action("interact") and InputMap.action_get_events("interact")[0].physical_keycode==KEY_F,"F Input Map configured")
		var key:=InputEventKey.new()
		key.physical_keycode=KEY_F
		key.keycode=KEY_F
		key.pressed=true
		interactor._unhandled_input(key)
		interactor._physics_process(0.016)
		check(b.calls==2,"F event requests interaction on physics tick")
		b.queue_free()
		await physics_frame
		await physics_frame
		check(interactor.update_target()==a,"deleted current target safely falls back to next target")
		a.queue_free()
		await physics_frame
		await physics_frame
		check(interactor.update_target()==null and not prompt.label.visible,"destroyed last target clears prompt safely")
		player.set_script(null)
		await physics_frame
		check(interactor.update_target()==null,"actor without player script remains safe for acoustic actor fixtures")
		world.queue_free()
		await process_frame
	print("PLAYER_INTERACTION_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)
