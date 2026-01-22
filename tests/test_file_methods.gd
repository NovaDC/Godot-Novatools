@tool
extends ExtendedTestBase

var _delete_recursive_passed := false

func generate_random_path_name(l:int = -1) -> String:
	var chars = (range(65, 90) + range(97, 122) + range(48, 57) + [95])
	var ret := ""
	if l < 0:
		l = randi_range(1, 5)
	for _ign in l:
		var rand = chars.pick_random()
		ret += char(rand)
	# windows has no idea how to handle directories that end with a '.',
	# trust me, its a whole ordeal managing to actually delete them once their made...
	return ret.lstrip(".").rstrip(".")

func generate_random_nested_files(root_dir := "res://",
								layers:int = 4,
								max_files:int = 5,
								min_files:int = 0
								) -> PackedStringArray:
	root_dir = root_dir.simplify_path()

	var gen_dir := PackedStringArray()
	var appending_dirs := PackedStringArray()
	appending_dirs.resize(layers)
	appending_dirs.fill(root_dir)
	for _ign in layers:
		for app_i in appending_dirs.size():
			var new_dir := appending_dirs[app_i].path_join(generate_random_path_name())
			assert(DirAccess.make_dir_recursive_absolute(new_dir) == OK)
			appending_dirs[app_i] = new_dir
		gen_dir.append(appending_dirs[0])
		appending_dirs.remove_at(0)
	gen_dir.append_array(appending_dirs)
	# when recursing for deletion,
	# make it easier by having the deeper dir's before the shallower ones
	# to avoid non-empty directory deletion errors
	gen_dir.reverse()

	var gen_files := PackedStringArray()
	for deep_dir in gen_dir:
		var active_path := deep_dir
		while root_dir in active_path and not active_path.get_base_dir() in root_dir:
			for _ign2 in range(randi_range(min_files, max_files)):
				var p := active_path.path_join(generate_random_path_name() + ".txt")
				var f := FileAccess.open(p, FileAccess.WRITE)
				f.store_line(generate_random_path_name(randi_range(0, 25)))
				f.close()
				gen_files.append(p)
			active_path = active_path.get_base_dir()

	# best delete the file before the dirs
	return gen_files + gen_dir

func test_delete_recursive():
	var old_fails = get_fail_count()
	var root_dir := "res://test_gen"
	var generated := Array(generate_random_nested_files(root_dir))
	generated = generated.filter(FileAccess.file_exists)
	for p in generated:
		assert_path_does_exist(p)
	assert_gt(generated.size(), 0)
	assert_ok(NovaTools.delete_recursive(root_dir))
	for p in generated:
		assert_path_does_not_exist(p)
	if get_fail_count() - old_fails == 0:
		_delete_recursive_passed = true

func test_copy_recursive_error_ok():
	if not _delete_recursive_passed:
		fail_test("Automatically failed due to failures in this test's dependency 'delete_recursive'")
		return
	var root_dir := "res://test_gen"
	var target_dir := "res://test_copy"
	
	var generated := generate_random_nested_files(root_dir)
	assert_gt(generated.size(), 0)
	for path in generated:
		assert_path_does_exist(path)
	
	var sucessfully_coppied_buffer := PackedStringArray()
	assert_ok(NovaTools.copy_recursive(root_dir, target_dir, PackedStringArray(), -1, false, sucessfully_coppied_buffer))
	
	assert_gt(sucessfully_coppied_buffer.size(), 0)
	for path in sucessfully_coppied_buffer:
		assert_path_does_exist(path)
	
	assert_ok(NovaTools.delete_recursive(root_dir))
	assert_ok(NovaTools.delete_recursive(target_dir))

func test_copy_recursive_error_over_max():
	if not _delete_recursive_passed:
		fail_test("Automatically failed due to failures in this test's dependency 'delete_recursive'")
		return

	#we don't need to create these for the test
	var root_dir := "res://test_gen"
	var target_dir := "res://test_copy"
	
	var sucessfully_coppied_buffer := PackedStringArray()
	assert_errs(NovaTools.copy_recursive(root_dir, target_dir, PackedStringArray(), 0, false, sucessfully_coppied_buffer), ERR_TIMEOUT)

	assert_eq(sucessfully_coppied_buffer.size(), 0)

func test_copy_recursive_anti_nesting():
	if not _delete_recursive_passed:
		fail_test("Automatically failed due to failures in this test's dependency 'delete_recursive'")
		return
	var root_dir := "res://test_gen"
	var target_dir := "res://test_gen/test_copy"
	var generated := generate_random_nested_files(root_dir)
	assert_gt(generated.size(), 0)
	for path in generated:
		assert_path_does_exist(path)
	var sucessfully_coppied_buffer := PackedStringArray()
	assert_ok(NovaTools.copy_recursive(root_dir, target_dir, PackedStringArray(), -1, false, sucessfully_coppied_buffer))
	assert_gt(sucessfully_coppied_buffer.size(), 0)
	for path in sucessfully_coppied_buffer:
		assert_path_does_exist(path)
	assert_ok(NovaTools.delete_recursive(target_dir))
	assert_ok(NovaTools.delete_recursive(root_dir))

func test_copy_recursive_reverse_anti_nesting():
	if not _delete_recursive_passed:
		fail_test("Automatically failed due to failures in this test's dependency 'delete_recursive'")
		return
	var root_dir := "res://test_gen/test_copy"
	var target_dir := "res://test_gen"
	var generated := generate_random_nested_files(root_dir)
	assert_gt(generated.size(), 0)
	for path in generated:
		assert_path_does_exist(path)
	var sucessfully_coppied_buffer := PackedStringArray()
	assert_ok(NovaTools.copy_recursive(root_dir, target_dir, PackedStringArray(), -1, false, sucessfully_coppied_buffer))
	assert_gt(sucessfully_coppied_buffer.size(), 0)
	for path in sucessfully_coppied_buffer:
		assert_path_does_exist(path)
	assert_ok(NovaTools.delete_recursive(root_dir))
	assert_ok(NovaTools.delete_recursive(target_dir))

func test_move_recursive():
	# just tests it's dependencies
	test_copy_recursive_error_ok()
	test_copy_recursive_anti_nesting()
	test_copy_recursive_reverse_anti_nesting()
	test_delete_recursive()

func test_file_compress_simple():
	if not _delete_recursive_passed:
		fail_test("Automatically failed due to failures in this test's dependency 'delete_recursive'")
		return
	var root_dir := "res://test_gen"
	var target_path := "res://test_gened.zip"
	assert_file_does_not_exist(target_path)
	var generated := generate_random_nested_files(root_dir)
	assert_gt(generated.size(), 0)
	for path in generated:
		assert_path_does_exist(path)
	assert_ok(await NovaTools.compress_zip_async(root_dir, target_path))
	assert_file_exists(target_path)
	assert_ok(NovaTools.delete_recursive(root_dir))
	assert_ok(DirAccess.remove_absolute(target_path))

func test_file_compress_anti_nesting():
	if not _delete_recursive_passed:
		fail_test("Automatically failed due to failures in this test's dependency 'delete_recursive'")
		return
	var root_dir := "res://test_gen"
	var target_path := "res://test_gen/nest/generated.zip"
	assert_file_does_not_exist(target_path)
	var generated := generate_random_nested_files(root_dir)
	assert_gt(generated.size(), 0)
	for path in generated:
		assert_path_does_exist(path)
	assert_ok(await NovaTools.compress_zip_async(root_dir, target_path))
	assert_file_exists(target_path)
	assert_ok(NovaTools.delete_recursive(root_dir))

func test_generate_version_py():
	if not _delete_recursive_passed:
		fail_test("Automatically failed due to failures in this test's dependency 'delete_recursive'")
		return

	var to_path := "res://test_temp/"
	assert_ok(NovaTools.generate_version_py(to_path))

	assert_ok(NovaTools.delete_recursive(to_path))
