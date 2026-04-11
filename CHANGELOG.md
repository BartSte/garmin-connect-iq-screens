# CHANGELOG

## Interval Workout

### v0.1.0

- Initial release of the Interval Workout field for the Garmin Edge Explore 2.
- Added phone-configurable workout settings for:
  - enabling or disabling the workout field
  - FTP
  - sets and repetitions
  - work, recovery, and between-set recovery durations
  - work, recovery, and between-set recovery power zones
- Added a bordered 4-row workout layout showing:
  - time of day and ride timer
  - 3s power
  - interval time left and current zone goal
  - set progress and repetition progress
- Added 3-second rolling power guidance with background colors for below target, in target, above target, and unavailable power.
- Added lap-to-start interval execution with support for:
  - indefinite warmup before the first lap
  - single-set and multi-set workouts
  - indefinite cooldown after the workout completes
- Added visual transition alerts and device sounds for workout transitions.
- Kept normal rides unaffected when the field is disabled.
- Fixed zone-threshold handling so exact FTP boundaries are classified into the correct Coggan zone.
- Fixed settings reload behavior so workout settings remain editable during warmup and only lock when the first lap starts the interval session.

## Minimal-7

### v1.2.0

- Numeric fields now use the largest built-in number font that fits their current value while keeping a small cell margin.
- Removed the font-size setting from app settings.
- The cadence field is now green when cadence is between a minimal and a maximal value (default: 80-95 rpm) and white otherwise.

### v1.1.0

- Added a user-configurable FTP setting in the app settings. Default: 230 W.
- Font size can be adjusted to small, medium, or large (default).
- Text now falls back to a smaller built-in font when needed so values stay within their cell bounds.

### V1.0.0

- Initial release of Minimal-7 with the following features:
  - 7 fields: time of day, timer, 3s power, speed, cadence, ascent, and distance.
  - No titles or units are displayed to keep it minimalistic.
  - The background color of the 3s power field changes based on the power zone that can is set in the settings through the user's FTP value (default is 230W).
