///|
/// The tests of the configuration of the `gcm` package.
///
/// The upstream `dowhy.gcm.config` keeps its two settings in module level
/// globals that `enable_progress_bars`, `disable_progress_bars` and
/// `set_default_n_jobs` change in place. MoonBit has no mutable global, so
/// the port keeps the settings in a value and the setters return a copy of it.
/// The two tests of the upstream are therefore the tests of that copy: the
/// copy carries the new setting and the configuration it was made from keeps
/// the old one.
///
/// The two cases of the upstream test file `tests/gcm/test_config.py` are among
/// the cases of this file.

///|
test "the progress bars are turned on and off on a copy of the configuration" {
  let config = @gcm.default_config()
  assert_true(config.shows_progress_bars())
  let without_bars = config.with_show_progress_bars(false)
  assert_false(without_bars.shows_progress_bars())
  assert_true(config.shows_progress_bars())
  assert_true(without_bars.with_show_progress_bars(true).shows_progress_bars())
}

///|
test "the number of the jobs is set on a copy of the configuration" {
  let config = @gcm.default_config()
  let with_jobs = config.with_default_n_jobs(42)
  assert_eq(with_jobs.jobs(), 42)
  assert_eq(config.jobs(), -1)
  assert_eq(with_jobs.with_default_n_jobs(config.jobs()).jobs(), config.jobs())
}
