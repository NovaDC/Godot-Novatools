@tool
class_name ExtendedTestBase
extends GutTest

## ExtendedTestBase
##
## A class used by [Novatools] to provide more verbose assertions for some specific cases.

## Assert that [param err] is one of the [Error] codes defined in [param errs].
## [param errs] an be an array (of any type) of error codes, or a single error code.
func assert_errs(err:int, errs:Variant = [OK], text := ""):
	if errs is int:
		errs = [errs]
	if errs.size() == 1 and errs[0] == OK:
		assert_ok(err, text)
		return
	var err_str = errs.map(func (c:int): return error_string(c))
	var display = str('expected error codes [',
						_str(err_str),
						'] and got: [',
						_str(error_string(err)),
						']:  ',
						text
					)
	if(err in errs):
		_pass(display)
	else:
		_fail(display)

## Assert that [param err] is specifically [const Error.OK].
func assert_ok(err:int, text := ""):
	var display = str('expected OK and got the error:  [',
						_str(error_string(err)),
						']:  ',
						text
					)
	if err == OK:
		_pass(display)
	else:
		_fail(display)

## Assert a [param path] of any type (file or folder) exists
func assert_path_exists(path:String, text := ""):
	var exists := FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
	var display = str('expected path ',
						_str(path),
						' to exist:  [',
						_str(exists),
						']:  ',
						text
					)
	if exists:
		_pass(display)
	else:
		_fail(display)

## Assert a [param path] of any type (file or folder) exists
func assert_path_does_not_exist(path:String, text := ""):
	var not_exists := not FileAccess.file_exists(path) or not DirAccess.dir_exists_absolute(path)
	var display = str('expected path ',
						_str(path),
						' to not exist:  [',
						_str(not_exists),
						']:  ',
						text
					)
	if not_exists:
		_pass(display)
	else:
		_fail(display)
