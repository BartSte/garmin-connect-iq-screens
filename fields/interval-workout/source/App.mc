import Toybox.Application;
import Toybox.WatchUi;

class IntervalWorkoutApp extends Application.AppBase {

    hidden var mView as IntervalWorkout or Null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        mView = new IntervalWorkout();
        return [mView as IntervalWorkout];
    }

    function onSettingsChanged() as Void {
        if (mView != null) {
            (mView as IntervalWorkout).handleSettingsChanged();
            WatchUi.requestUpdate();
        }
    }
}
