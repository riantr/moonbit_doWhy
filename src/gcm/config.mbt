///|
/// The configuration of the `gcm` package.
///
/// The upstream `dowhy.gcm.config` keeps its two settings in module level
/// globals that `enable_progress_bars`, `disable_progress_bars` and
/// `set_default_n_jobs` change in place. MoonBit has no mutable global, so
/// the settings live in a value that the functions which need it take as an
/// argument. A caller that wants a different setting makes its own copy with
/// `with_show_progress_bars` or `with_default_n_jobs`.
///
/// The port does not run anything in parallel, so `default_n_jobs` is carried
/// for the sake of the callers that pass it on, but it changes no result.
pub struct Config {
  /// Whether the progress bars are shown.
  show_progress_bars : Bool
  /// The number of parallel jobs the estimators use by default.
  default_n_jobs : Int32
}

///|
/// The default configuration: the progress bars are on and every core is used.
pub fn Config::default() -> Config {
  { show_progress_bars: true, default_n_jobs: -1, }
}

///|
/// The default configuration.
pub fn default_config() -> Config {
  Config::default()
}

///|
/// Whether the progress bars are shown.
pub fn Config::shows_progress_bars(self : Config) -> Bool {
  self.show_progress_bars
}

///|
/// The number of parallel jobs the estimators use by default.
pub fn Config::jobs(self : Config) -> Int32 {
  self.default_n_jobs
}

///|
/// A copy of the configuration with the progress bars on or off.
pub fn Config::with_show_progress_bars(self : Config, value : Bool) -> Config {
  { show_progress_bars: value, default_n_jobs: self.default_n_jobs, }
}

///|
/// A copy of the configuration with the given number of parallel jobs.
pub fn Config::with_default_n_jobs(self : Config, value : Int32) -> Config {
  { show_progress_bars: self.show_progress_bars, default_n_jobs: value, }
}
