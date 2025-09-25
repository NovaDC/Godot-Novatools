@tool
extends ExtendedTestBase

func test_get_most_relevant_editor_theme():
	assert_not_null(NovaTools.get_most_relevant_editor_theme())

func test_get_editor_icon_named():
	var theme = NovaTools.get_most_relevant_editor_theme()
	var icon_name_list := theme.get_icon_list("EditorIcons")
	if icon_name_list.is_empty():
		pass_test("Could not access editor icons from the most relevant theme," +
				"however, this is likely a result of the environment this is run in," +
				"so this is allowable.")
	for n in icon_name_list:
		var same_ic := NovaTools.get_editor_icon_named(n)
		assert_eq_deep(same_ic, theme.get_icon(n, "EditorIcons"))
		assert_not_null(same_ic)
		assert_gt(same_ic.get_size().length_squared(), 0)
		randomize()
		var scaled_size := Vector2i(randi_range(1, 1024), randi_range(1, 1024))
		var scaled_ic := NovaTools.get_editor_icon_named(n, scaled_size)
		assert_not_null(scaled_ic)
		assert_eq(Vector2i(scaled_ic.get_size()), scaled_size)
