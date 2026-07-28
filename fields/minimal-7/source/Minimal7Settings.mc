import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

const MINIMAL7_DEFAULT_FTP = 248;
const MINIMAL7_MIN_FTP = 50;
const MINIMAL7_MAX_FTP = 600;

class Minimal7SettingsView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.clearClip();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var centerX = dc.getWidth() / 2;
        var currentFtp = Minimal7Logic.valueToNumber(
            Application.Properties.getValue("ftp"),
            MINIMAL7_DEFAULT_FTP
        );

        dc.drawText(
            centerX,
            dc.getHeight() / 5,
            Graphics.FONT_MEDIUM,
            WatchUi.loadResource(Rez.Strings.SettingsTitle) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            centerX,
            dc.getHeight() / 2,
            Graphics.FONT_NUMBER_HOT,
            currentFtp.format("%d") + " W",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            centerX,
            dc.getHeight() * 4 / 5,
            Graphics.FONT_SMALL,
            WatchUi.loadResource(Rez.Strings.FtpEditInstruction) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}

class Minimal7SettingsDelegate extends WatchUi.BehaviorDelegate {

    hidden var mApp as Minimal7App;

    function initialize(app as Minimal7App) {
        BehaviorDelegate.initialize();
        mApp = app;
    }

    function onSelect() as Boolean {
        return pushFtpPicker();
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        return pushFtpPicker();
    }

    hidden function pushFtpPicker() as Boolean {
        WatchUi.pushView(
            new Minimal7FtpPicker(),
            new Minimal7FtpPickerDelegate(mApp),
            WatchUi.SLIDE_IMMEDIATE
        );
        return true;
    }
}

class Minimal7FtpPickerFactory extends WatchUi.PickerFactory {

    function initialize() {
        PickerFactory.initialize();
    }

    function getIndex(value as Number) as Number {
        var clampedValue = value;
        if (clampedValue < MINIMAL7_MIN_FTP) {
            clampedValue = MINIMAL7_MIN_FTP;
        } else if (clampedValue > MINIMAL7_MAX_FTP) {
            clampedValue = MINIMAL7_MAX_FTP;
        }
        return clampedValue - MINIMAL7_MIN_FTP;
    }

    function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable or Null {
        var value = getValue(index) as Number;
        return new WatchUi.Text({
            :text => value.format("%d") + " W",
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_NUMBER_HOT,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }

    function getValue(index as Number) as Lang.Object or Null {
        return MINIMAL7_MIN_FTP + index;
    }

    function getSize() as Number {
        return MINIMAL7_MAX_FTP - MINIMAL7_MIN_FTP + 1;
    }
}

class Minimal7FtpPicker extends WatchUi.Picker {

    function initialize() {
        var factory = new Minimal7FtpPickerFactory();
        var currentFtp = Minimal7Logic.valueToNumber(
            Application.Properties.getValue("ftp"),
            MINIMAL7_DEFAULT_FTP
        );
        var title = new WatchUi.Text({
            :text => Rez.Strings.FtpTitle,
            :color => Graphics.COLOR_WHITE,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
        });

        Picker.initialize({
            :title => title,
            :pattern => [factory],
            :defaults => [factory.getIndex(currentFtp)]
        });
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

class Minimal7FtpPickerDelegate extends WatchUi.PickerDelegate {

    hidden var mApp as Minimal7App;

    function initialize(app as Minimal7App) {
        PickerDelegate.initialize();
        mApp = app;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onAccept(values as Array) as Boolean {
        var value = values[0];
        if (value instanceof Lang.Number) {
            Application.Properties.setValue("ftp", value);
            mApp.reloadSettings();
        }

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.requestUpdate();
        return true;
    }
}
