## One worker of a balance sweep (see BalanceSweep.start): plays its share of
## the run folder's fights and writes what happened next to them.
## Run: godot --headless --path . --script res://tools/balance_worker.gd -- --run=<folder> --share=<k>/<n>
extends SceneTree


func _initialize() -> void:
	var folder := ""
	var share := 0
	var shares := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run="):
			folder = arg.trim_prefix("--run=")
		elif arg.begins_with("--share="):
			share = int(arg.trim_prefix("--share=").get_slice("/", 0))
			shares = int(arg.trim_prefix("--share=").get_slice("/", 1))
	BalanceSweep.from_folder(folder).run_share(folder, share, shares)
	quit()
