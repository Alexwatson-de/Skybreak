extends SceneTree
func _initialize() -> void:
	var output=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var license_file=FileAccess.open(output.path_join("Godot-LICENSE.txt"),FileAccess.WRITE)
	license_file.store_string(Engine.get_license_text())
	var copyrights=FileAccess.open(output.path_join("Godot-COPYRIGHT.json"),FileAccess.WRITE)
	copyrights.store_string(JSON.stringify(Engine.get_copyright_info(),"  "))
	var third_party=FileAccess.open(output.path_join("Godot-THIRD-PARTY-LICENSES.json"),FileAccess.WRITE)
	third_party.store_string(JSON.stringify(Engine.get_license_info(),"  "))
	quit()
