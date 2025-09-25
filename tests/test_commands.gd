@tool
extends ExtendedTestBase

func test_launch_external_command_async():
	assert_ok(await NovaTools.launch_external_command_async("echo", ["aha", "aga"], false))
	# Technically Godot's OK and any other application's OK my not be the same,
	# but lets just assume that to be the case for the echo command.
	# that means the log message will be more appropriate.

func test_launch_editor_instance_async():
	assert_ok(await NovaTools.launch_editor_instance_async(["--version"], "", false))
	assert_ok(await NovaTools.launch_editor_instance_async(["--help"], "", false))
	var yeah_man_crazy := ["--display-driver headless",
								"I really hope nobody in the future genuinly names a editor param like this and messes up this test in some dumb way. That would be crazy..."
								]
	assert_errs(await NovaTools.launch_editor_instance_async(yeah_man_crazy, "", false), FAILED)