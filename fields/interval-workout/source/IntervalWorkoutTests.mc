import Toybox.Lang;
import Toybox.Test;

(:test)
function intervalWorkoutNormalizesSettings(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking settings normalization");
    var settings = IntervalWorkoutLogic.normalizeSettings({
        :enabled => true,
        :ftp => 250,
        :set_count => 3,
        :rep_count => 10,
        :work_value => 40,
        :work_unit => "seconds",
        :recovery_value => 20,
        :recovery_unit => "seconds",
        :set_recovery_value => 5,
        :set_recovery_unit => "minutes",
        :work_zone => "5",
        :recovery_zone => "1",
        :set_recovery_zone => "2"
    });

    return settings[:enabled]
        && (settings[:ftp] == 250)
        && (settings[:setRecoverySecs] == 300)
        && (settings[:workZone] == 5)
        && settings[:valid];
}

(:test)
function intervalWorkoutRejectsInvalidFtp(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking invalid FTP");
    var settings = IntervalWorkoutLogic.normalizeSettings({
        :enabled => true,
        :ftp => 0,
        :set_count => 1,
        :rep_count => 1,
        :work_value => 1,
        :work_unit => "minutes",
        :recovery_value => 1,
        :recovery_unit => "minutes",
        :set_recovery_value => 0,
        :set_recovery_unit => "seconds",
        :work_zone => "4",
        :recovery_zone => "1",
        :set_recovery_zone => "1"
    });
    return !settings[:valid] && (settings[:error] == "FTP");
}

(:test)
function intervalWorkoutFormatsTimers(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking timer formatting");
    return (IntervalWorkoutLogic.formatRideTimer(495000) == "08:15")
        && (IntervalWorkoutLogic.formatCountdown(20000) == "00:20")
        && (IntervalWorkoutLogic.formatClock(7, 30) == "07:30");
}

(:test)
function intervalWorkoutTracksPowerAverage(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking rolling power average");
    var one = IntervalWorkoutLogic.pushPowerSample([0, 0, 0], 0, 0, 210);
    var two = IntervalWorkoutLogic.pushPowerSample(one[:buffer], one[:nextIndex], one[:sampleCount], 240);
    var three = IntervalWorkoutLogic.pushPowerSample(two[:buffer], two[:nextIndex], two[:sampleCount], 300);
    return (three[:average] == 250) && (three[:sampleCount] == 3);
}

(:test)
function intervalWorkoutAdvancesWithinSingleSet(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking single-set progression");
    var settings = IntervalWorkoutLogic.normalizeSettings({
        :enabled => true,
        :ftp => 250,
        :set_count => 1,
        :rep_count => 2,
        :work_value => 40,
        :work_unit => "seconds",
        :recovery_value => 20,
        :recovery_unit => "seconds",
        :set_recovery_value => 0,
        :set_recovery_unit => "seconds",
        :work_zone => "5",
        :recovery_zone => "1",
        :set_recovery_zone => "1"
    });
    var state = IntervalWorkoutLogic.startWorkState(1, 1, settings);
    var afterWork = IntervalWorkoutLogic.applyElapsed(state, settings, 40000);
    var afterWorkState = afterWork[:state] as Dictionary;
    var afterRecovery = IntervalWorkoutLogic.applyElapsed(afterWorkState, settings, 20000);
    var afterRecoveryState = afterRecovery[:state] as Dictionary;
    return (afterWorkState[:phase] == INTERVAL_PHASE_RECOVERY)
        && (afterRecoveryState[:phase] == INTERVAL_PHASE_WORK)
        && (afterRecoveryState[:currentRep] == 2);
}

(:test)
function intervalWorkoutAdvancesAcrossSets(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking set recovery progression");
    var settings = IntervalWorkoutLogic.normalizeSettings({
        :enabled => true,
        :ftp => 250,
        :set_count => 2,
        :rep_count => 1,
        :work_value => 40,
        :work_unit => "seconds",
        :recovery_value => 20,
        :recovery_unit => "seconds",
        :set_recovery_value => 5,
        :set_recovery_unit => "minutes",
        :work_zone => "5",
        :recovery_zone => "1",
        :set_recovery_zone => "2"
    });
    var state = IntervalWorkoutLogic.startWorkState(1, 1, settings);
    var afterWork = IntervalWorkoutLogic.applyElapsed(state, settings, 40000);
    var afterWorkState = afterWork[:state] as Dictionary;
    var afterRecovery = IntervalWorkoutLogic.applyElapsed(afterWorkState, settings, 20000);
    var afterRecoveryState = afterRecovery[:state] as Dictionary;
    var afterSetRecovery = IntervalWorkoutLogic.applyElapsed(afterRecoveryState, settings, 300000);
    var afterSetRecoveryState = afterSetRecovery[:state] as Dictionary;
    return (afterRecoveryState[:phase] == INTERVAL_PHASE_SET_RECOVERY)
        && (afterRecoveryState[:currentSet] == 2)
        && (afterSetRecoveryState[:phase] == INTERVAL_PHASE_WORK)
        && (afterSetRecoveryState[:currentSet] == 2);
}

(:test)
function intervalWorkoutCompletesAfterFinalRecovery(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking complete state");
    var settings = IntervalWorkoutLogic.normalizeSettings({
        :enabled => true,
        :ftp => 250,
        :set_count => 1,
        :rep_count => 1,
        :work_value => 40,
        :work_unit => "seconds",
        :recovery_value => 20,
        :recovery_unit => "seconds",
        :set_recovery_value => 0,
        :set_recovery_unit => "seconds",
        :work_zone => "5",
        :recovery_zone => "1",
        :set_recovery_zone => "1"
    });
    var state = IntervalWorkoutLogic.startWorkState(1, 1, settings);
    var afterWork = IntervalWorkoutLogic.applyElapsed(state, settings, 40000);
    var afterWorkState = afterWork[:state] as Dictionary;
    var afterRecovery = IntervalWorkoutLogic.applyElapsed(afterWorkState, settings, 20000);
    var afterRecoveryState = afterRecovery[:state] as Dictionary;
    return afterRecoveryState[:phase] == INTERVAL_PHASE_COMPLETE;
}

(:test)
function intervalWorkoutDetectsPowerCompliance(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking power-zone compliance");
    var below = IntervalWorkoutLogic.powerCompliance(120, 250, 4, true);
    var inside = IntervalWorkoutLogic.powerCompliance(250, 250, 4, true);
    var above = IntervalWorkoutLogic.powerCompliance(500, 250, 4, true);
    return (below == INTERVAL_POWER_BELOW)
        && (inside == INTERVAL_POWER_IN)
        && (above == INTERVAL_POWER_ABOVE);
}

(:test)
function intervalWorkoutTreatsThresholdsAsInclusive(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking inclusive zone thresholds");
    return (IntervalWorkoutLogic.zoneBandFromPct(55) == 2)
        && (IntervalWorkoutLogic.zoneBandFromPct(75) == 3)
        && (IntervalWorkoutLogic.zoneBandFromPct(90) == 4)
        && (IntervalWorkoutLogic.zoneBandFromPct(105) == 5)
        && (IntervalWorkoutLogic.zoneBandFromPct(120) == 6)
        && (IntervalWorkoutLogic.zoneBandFromPct(150) == 7);
}
