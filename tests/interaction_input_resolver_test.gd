extends "res://tests/inventory_grid_test.gd"

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/player/interaction_input_resolver.gd"),"tap/hold resolver exists")
	if failures==0:
		var script: Script=load("res://scripts/player/interaction_input_resolver.gd")
		var target:=Node.new()
		root.add_child(target)
		for duration in [0.0,0.34,0.35,0.50]:
			var resolver: Variant=script.new()
			resolver.press(target)
			var managed: Node=resolver.tick(duration)
			check((managed==target)==(duration>=0.35),"hold inclusive0.35 boundary: "+str(duration))
			check(resolver.tick(1.0)==null if duration>=0.35 else true,"hold opens once only")
			check((resolver.release()==target)==(duration<0.35),"release short or consumed hold")
			check(resolver.release()==null,"repeat release no action")
		var resolver: Variant=script.new()
		resolver.press(target)
		resolver.tick(0.2)
		resolver.press(target,true)
		check(resolver.tick(0.15)==target,"echo never restarts hold timer")
		resolver.release()
		for reason in ["target change","range","ownership","inventory open","lock","ESC","disabled"]:
			resolver.press(target)
			resolver.tick(0.1)
			resolver.cancel()
			check(resolver.tick(1.0)==null and resolver.release()==null,"cancel suppresses both hold and short: "+reason)
		resolver.press(target)
		target.queue_free()
		await process_frame
		check(resolver.tick(0.5)==null and resolver.release()==null,"deleted target never dispatched")
	print("INTERACTION_INPUT_RESOLVER_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)
