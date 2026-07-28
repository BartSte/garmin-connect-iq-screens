import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class Minimal7App extends Application.AppBase {

    hidden var mField as Minimal7 or Null = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var field = new Minimal7();
        mField = field;
        return [field];
    }

    function getSettingsView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null {
        return [new Minimal7SettingsView(), new Minimal7SettingsDelegate(self)];
    }

    function onSettingsChanged() as Void {
        reloadSettings();
        WatchUi.requestUpdate();
    }

    function reloadSettings() as Void {
        if (mField != null) {
            (mField as Minimal7).loadSettings();
        }
    }
}
