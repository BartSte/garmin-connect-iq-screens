import Toybox.Graphics;
import Toybox.Lang;

const INTERVAL_PHASE_DISABLED     = 0;
const INTERVAL_PHASE_INVALID      = 1;
const INTERVAL_PHASE_ARMED        = 2;
const INTERVAL_PHASE_WORK         = 3;
const INTERVAL_PHASE_RECOVERY     = 4;
const INTERVAL_PHASE_SET_RECOVERY = 5;
const INTERVAL_PHASE_COMPLETE     = 6;

const INTERVAL_POWER_UNKNOWN = 9;
const INTERVAL_POWER_BELOW   = -1;
const INTERVAL_POWER_IN      = 0;
const INTERVAL_POWER_ABOVE   = 1;

const INTERVAL_ZONE2_PCT = 55;
const INTERVAL_ZONE3_PCT = 75;
const INTERVAL_ZONE4_PCT = 90;
const INTERVAL_ZONE5_PCT = 105;
const INTERVAL_ZONE6_PCT = 120;
const INTERVAL_ZONE7_PCT = 150;

module IntervalWorkoutLogic {

    function defaultSettings() as Dictionary {
        return {
            :enabled => false,
            :ftp => 230,
            :setCount => 3,
            :repCount => 10,
            :workSecs => 40,
            :recoverySecs => 20,
            :setRecoverySecs => 300,
            :workZone => 5,
            :recoveryZone => 1,
            :setRecoveryZone => 1,
            :valid => true,
            :error => ""
        };
    }

    function defaultSessionState() as Dictionary {
        return {
            :phase => INTERVAL_PHASE_DISABLED,
            :currentSet => 1,
            :currentRep => 1,
            :remainingMs => 0
        };
    }

    function valueToNumber(value as Lang.Object or Null, fallback as Number) as Number {
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.Number) {
            return value as Lang.Number;
        }
        if (value instanceof Lang.Long) {
            return (value as Lang.Long).toNumber();
        }
        if (value instanceof Lang.Float) {
            return (value as Lang.Float).toNumber();
        }
        if (value instanceof Lang.Double) {
            return (value as Lang.Double).toNumber();
        }
        if (value instanceof Lang.String) {
            return (value as Lang.String).toNumber();
        }
        return fallback;
    }

    function valueToBoolean(value as Lang.Object or Null, fallback as Boolean) as Boolean {
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.Boolean) {
            return value as Lang.Boolean;
        }
        if (value instanceof Lang.String) {
            return ((value as Lang.String) == "true");
        }
        if (value instanceof Lang.Number) {
            return (value as Lang.Number) != 0;
        }
        return fallback;
    }

    function valueToString(value as Lang.Object or Null, fallback as String) as String {
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.String) {
            return value as Lang.String;
        }
        return value.toString();
    }

    function secondsFromValue(value as Lang.Object or Null, unit as Lang.Object or Null, fallback as Number) as Number {
        var amount = valueToNumber(value, fallback);
        var multiplier = valueToNumber(unit, 1);
        return amount * multiplier;
    }

    function zoneFromValue(value as Lang.Object or Null, fallback as Number) as Number {
        var zone = valueToNumber(value, fallback);
        if (zone < 1) { return 1; }
        if (zone > 7) { return 7; }
        return zone;
    }

    function normalizeSettings(raw as Dictionary) as Dictionary {
        var settings = {
            :enabled => valueToBoolean(raw[:enabled], false),
            :ftp => valueToNumber(raw[:ftp], 230),
            :setCount => valueToNumber(raw[:set_count], 1),
            :repCount => valueToNumber(raw[:rep_count], 1),
            :workSecs => secondsFromValue(raw[:work_value], raw[:work_unit], 0),
            :recoverySecs => secondsFromValue(raw[:recovery_value], raw[:recovery_unit], 0),
            :setRecoverySecs => secondsFromValue(raw[:set_recovery_value], raw[:set_recovery_unit], 0),
            :workZone => zoneFromValue(raw[:work_zone], 4),
            :recoveryZone => zoneFromValue(raw[:recovery_zone], 1),
            :setRecoveryZone => zoneFromValue(raw[:set_recovery_zone], 1),
            :valid => true,
            :error => ""
        };

        if (settings[:ftp] <= 0) {
            settings[:valid] = false;
            settings[:error] = "FTP";
        } else if (settings[:setCount] < 1) {
            settings[:valid] = false;
            settings[:error] = "SETS";
        } else if (settings[:repCount] < 1) {
            settings[:valid] = false;
            settings[:error] = "REPS";
        } else if (settings[:workSecs] <= 0) {
            settings[:valid] = false;
            settings[:error] = "WORK";
        } else if (settings[:recoverySecs] <= 0) {
            settings[:valid] = false;
            settings[:error] = "REC";
        } else if (settings[:setRecoverySecs] < 0) {
            settings[:valid] = false;
            settings[:error] = "SET";
        }

        return settings;
    }

    function pushPowerSample(
        powerBuf as Array<Number>,
        powerIdx as Number,
        powerCount as Number,
        rawPower as Number
    ) as Dictionary {
        var nextBuf = [powerBuf[0], powerBuf[1], powerBuf[2]];
        var nextCount = powerCount;

        if (nextCount < 3) {
            nextCount += 1;
            if (nextCount == 1) {
                nextBuf[0] = rawPower;
                nextBuf[1] = rawPower;
                nextBuf[2] = rawPower;
            }
        }

        nextBuf[powerIdx] = rawPower;

        return {
            :buffer => nextBuf,
            :nextIndex => (powerIdx + 1) % 3,
            :sampleCount => nextCount,
            :average => (nextBuf[0] + nextBuf[1] + nextBuf[2] + 1) / 3
        };
    }

    function formatClock(hour as Number, minute as Number) as String {
        return hour.format("%02d") + ":" + minute.format("%02d");
    }

    function formatRideTimer(ms as Number) as String {
        var totalSecs = ms / 1000;
        var hours = totalSecs / 3600;
        var minutes = (totalSecs % 3600) / 60;
        var secs = totalSecs % 60;
        if (hours > 0) {
            return hours.format("%d") + ":" + minutes.format("%02d") + ":" + secs.format("%02d");
        }
        return minutes.format("%02d") + ":" + secs.format("%02d");
    }

    function formatCountdown(ms as Number) as String {
        var totalSecs = ms / 1000;
        var hours = totalSecs / 3600;
        var minutes = (totalSecs % 3600) / 60;
        var secs = totalSecs % 60;
        if (hours > 0) {
            return hours.format("%d") + ":" + minutes.format("%02d") + ":" + secs.format("%02d");
        }
        return minutes.format("%02d") + ":" + secs.format("%02d");
    }

    function formatProgress(current as Number, total as Number) as String {
        return current.format("%d") + "/" + total.format("%d");
    }

    function zoneLabel(zone as Number) as String {
        return "Z" + zone.format("%d");
    }

    function zoneBandFromPct(pct as Number) as Number {
        if (pct >= INTERVAL_ZONE7_PCT) { return 7; }
        if (pct >= INTERVAL_ZONE6_PCT) { return 6; }
        if (pct >= INTERVAL_ZONE5_PCT) { return 5; }
        if (pct >= INTERVAL_ZONE4_PCT) { return 4; }
        if (pct >= INTERVAL_ZONE3_PCT) { return 3; }
        if (pct >= INTERVAL_ZONE2_PCT) { return 2; }
        return 1;
    }

    function targetZoneForPhase(settings as Dictionary, phase as Number) as Number or Null {
        if (phase == INTERVAL_PHASE_WORK) {
            return settings[:workZone];
        }
        if (phase == INTERVAL_PHASE_RECOVERY) {
            return settings[:recoveryZone];
        }
        if (phase == INTERVAL_PHASE_SET_RECOVERY) {
            return settings[:setRecoveryZone];
        }
        return null;
    }

    function powerCompliance(power as Number, ftp as Number, targetZone as Number or Null, hasPower as Boolean) as Number {
        if (!hasPower || (ftp <= 0) || (targetZone == null)) {
            return INTERVAL_POWER_UNKNOWN;
        }

        var pct = (power * 100) / ftp;
        var actualZone = zoneBandFromPct(pct);
        if (actualZone < (targetZone as Number)) {
            return INTERVAL_POWER_BELOW;
        }
        if (actualZone > (targetZone as Number)) {
            return INTERVAL_POWER_ABOVE;
        }
        return INTERVAL_POWER_IN;
    }

    function powerBgColor(compliance as Number) as Number {
        if (compliance == INTERVAL_POWER_IN) {
            return 0x00AA00;
        }
        if (compliance == INTERVAL_POWER_BELOW) {
            return 0xCC9900;
        }
        if (compliance == INTERVAL_POWER_ABOVE) {
            return 0xAA0000;
        }
        return 0x666666;
    }

    function powerFgColor(compliance as Number) as Number {
        return (compliance == INTERVAL_POWER_UNKNOWN) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
    }

    function beginArmedState(settings as Dictionary) as Dictionary {
        return {
            :phase => settings[:enabled] ? INTERVAL_PHASE_ARMED : INTERVAL_PHASE_DISABLED,
            :currentSet => 1,
            :currentRep => 1,
            :remainingMs => 0
        };
    }

    function startWorkState(currentSet as Number, currentRep as Number, settings as Dictionary) as Dictionary {
        return {
            :phase => INTERVAL_PHASE_WORK,
            :currentSet => currentSet,
            :currentRep => currentRep,
            :remainingMs => settings[:workSecs] * 1000
        };
    }

    function nextPhaseState(state as Dictionary, settings as Dictionary) as Dictionary {
        if (state[:phase] == INTERVAL_PHASE_WORK) {
            return {
                :phase => INTERVAL_PHASE_RECOVERY,
                :currentSet => state[:currentSet],
                :currentRep => state[:currentRep],
                :remainingMs => settings[:recoverySecs] * 1000
            };
        }

        if (state[:phase] == INTERVAL_PHASE_RECOVERY) {
            if (state[:currentRep] < settings[:repCount]) {
                return startWorkState(state[:currentSet], state[:currentRep] + 1, settings);
            }
            if (state[:currentSet] < settings[:setCount]) {
                if (settings[:setRecoverySecs] > 0) {
                    return {
                        :phase => INTERVAL_PHASE_SET_RECOVERY,
                        :currentSet => state[:currentSet] + 1,
                        :currentRep => 1,
                        :remainingMs => settings[:setRecoverySecs] * 1000
                    };
                }
                return startWorkState(state[:currentSet] + 1, 1, settings);
            }
            return {
                :phase => INTERVAL_PHASE_COMPLETE,
                :currentSet => state[:currentSet],
                :currentRep => state[:currentRep],
                :remainingMs => 0
            };
        }

        if (state[:phase] == INTERVAL_PHASE_SET_RECOVERY) {
            return startWorkState(state[:currentSet], state[:currentRep], settings);
        }

        return state;
    }

    function isTimedPhase(phase as Number) as Boolean {
        return (phase == INTERVAL_PHASE_WORK)
            || (phase == INTERVAL_PHASE_RECOVERY)
            || (phase == INTERVAL_PHASE_SET_RECOVERY);
    }

    function applyElapsed(state as Dictionary, settings as Dictionary, elapsedMs as Number) as Dictionary {
        var nextState = {
            :phase => state[:phase],
            :currentSet => state[:currentSet],
            :currentRep => state[:currentRep],
            :remainingMs => state[:remainingMs]
        };
        var transitions = [];
        var remainingDelta = elapsedMs;

        while ((remainingDelta > 0) && isTimedPhase(nextState[:phase])) {
            if (remainingDelta < nextState[:remainingMs]) {
                nextState[:remainingMs] -= remainingDelta;
                remainingDelta = 0;
            } else {
                remainingDelta -= nextState[:remainingMs];
                nextState = nextPhaseState(nextState, settings);
                transitions.add(nextState[:phase]);
                if (!isTimedPhase(nextState[:phase])) {
                    remainingDelta = 0;
                }
            }
        }

        return {
            :state => nextState,
            :transitions => transitions
        };
    }
}
