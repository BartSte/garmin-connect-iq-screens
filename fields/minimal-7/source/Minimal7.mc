import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Activity;
import Toybox.Application;
import Toybox.System;
import Toybox.Lang;

// Minimal7 — full-screen data field for the Garmin Edge Explore 2.
//
// Layout (power-emphasis):
//   Row 1: time of day (24 h)  |  activity timer
//   Row 2: 3-second avg power (W)  — full width, zone-colored background
//   Row 3: speed (km/h)  |  cadence (rpm)
//   Row 4: ascent (m)    |  distance (km)
//
// All cells are separated by divider lines forming a visible grid.
// No labels are shown — numbers only.

const POWER_ROW_HEIGHT_PCT = 34;
const CELL_HORIZONTAL_PADDING = 4;
const CELL_VERTICAL_PADDING   = 3;

class Minimal7 extends WatchUi.DataField {

    // ── state — written by compute(), read by onUpdate() ─────────────────
    hidden var mHour       as Number = 0;
    hidden var mMinute     as Number = 0;
    hidden var mTimerMs    as Number = 0;    // activity timer in ms
    hidden var m3sPower    as Number = 0;    // rolling 3-sample average, watts
    hidden var mSpeed      as Float  = 0.0f; // km/h
    hidden var mCadence    as Number = 0;    // rpm
    hidden var mAscent     as Float  = 0.0f; // meters (cumulative); Float matches SDK type
    hidden var mDistanceKm as Float  = 0.0f; // km

    // ── 3-second power ring buffer ────────────────────────────────────────
    // Activity.Info only exposes currentPower (instantaneous), so we maintain
    // a 3-slot ring buffer updated every compute() call (~1 Hz) and average it.
    hidden var mPowerBuf   as Array<Number> = [0, 0, 0];
    hidden var mPowerIdx   as Number = 0;
    hidden var mPowerCount as Number = 0; // tracks warm-up: 0–3 samples seen so far

    // ── FTP ───────────────────────────────────────────────────────────────
    // mFtp == 0 means no valid FTP is configured; zone colouring is disabled.
    hidden var mFtp as Number = 230;
    hidden var mCadenceMin as Number = 80;
    hidden var mCadenceMax as Number = 95;

    function initialize() {
        DataField.initialize();

        var ftpValue = Application.Properties.getValue("ftp");
        mFtp = Minimal7Logic.valueToNumber(ftpValue, 230);

        var cadenceMin = Minimal7Logic.valueToNumber(Application.Properties.getValue("cadence_min"), 80);
        var cadenceMax = Minimal7Logic.valueToNumber(Application.Properties.getValue("cadence_max"), 95);
        if (cadenceMin <= cadenceMax) {
            mCadenceMin = cadenceMin;
            mCadenceMax = cadenceMax;
        } else {
            mCadenceMin = cadenceMax;
            mCadenceMax = cadenceMin;
        }
    }

    // onLayout is intentionally empty.
    // Row geometry is derived from dc.getWidth()/getHeight() in onUpdate(),
    // so the field adapts automatically to whatever size the OS allocates.
    function onLayout(dc as Graphics.Dc) as Void {
    }

    // Called ~1 Hz during an activity. Reads sensors into member variables.
    function compute(info as Activity.Info) as Void {
        var clock = System.getClockTime();
        mHour   = clock.hour;
        mMinute = clock.min;

        mTimerMs = Minimal7Logic.valueToNumber(info has :timerTime ? info.timerTime : null, 0);

        // Advance the ring buffer with the latest power sample.
        var rawPower = Minimal7Logic.valueToNumber(info has :currentPower ? info.currentPower : null, 0);
        var powerState = Minimal7Logic.pushPowerSample(mPowerBuf, mPowerIdx, mPowerCount, rawPower);
        mPowerBuf = powerState[:buffer];
        mPowerIdx = powerState[:nextIndex];
        mPowerCount = powerState[:sampleCount];
        m3sPower = powerState[:average];

        mSpeed = Minimal7Logic.speedToKph(info has :currentSpeed ? info.currentSpeed : null);

        mCadence = Minimal7Logic.valueToNumber(info has :currentCadence ? info.currentCadence : null, 0);

        mAscent = Minimal7Logic.valueToFloat(info has :totalAscent ? info.totalAscent : null, 0.0f);

        mDistanceKm = Minimal7Logic.distanceMetersToKm(info has :elapsedDistance ? info.elapsedDistance : null);
    }

    // Called when the field needs repainting.
    function onUpdate(dc as Graphics.Dc) as Void {
        var w     = dc.getWidth();
        var h     = dc.getHeight();
        var powerRowH = (h * POWER_ROW_HEIGHT_PCT) / 100;
        var otherRowsH = h - powerRowH;
        var row1H = otherRowsH / 3;
        var row3H = otherRowsH / 3;
        var row4H = h - powerRowH - row1H - row3H; // absorb any remainder

        var row1Y = 0;
        var row2Y = row1Y + row1H;
        var row3Y = row2Y + powerRowH;
        var row4Y = row3Y + row3H;

        // Clear the whole field to the device background color.
        var bgColor = getBackgroundColor();
        dc.setColor(bgColor, bgColor);
        dc.clear();

        // Compute foreground color once and pass it down to avoid repeated
        // getBackgroundColor() calls per frame.
        var fg = defaultFgColor();

        drawRow1(dc, w, row1H, row1Y, fg);      // time of day | timer
        drawPowerRow(dc, w, powerRowH, row2Y);  // 3s power (zone background)
        drawRow3(dc, w, row3H, row3Y, fg);      // speed | cadence
        drawRow4(dc, w, row4H, row4Y, fg);      // ascent | distance
        drawDividers(dc, w, h, row1H, powerRowH, row3Y, row4Y, fg);
    }

    // ── Row 1: time of day (left)  |  activity timer (right) ─────────────
    hidden function drawRow1(dc as Graphics.Dc, w as Number, rowH as Number, y as Number, fg as Number) as Void {
        var half    = w / 2;
        var timeStr = mHour.format("%02d") + ":" + mMinute.format("%02d");
        drawCell(dc, 0,    y, half, rowH, fg, null, timeStr);
        drawCell(dc, half, y, half, rowH, fg, null, Minimal7Logic.formatTimer(mTimerMs));
    }

    // ── Row 2: 3-second average power, full width, zone-colored ──────────
    hidden function drawPowerRow(dc as Graphics.Dc, w as Number, rowH as Number, y as Number) as Void {
        var pct    = (mFtp > 0) ? (m3sPower * 100 / mFtp) : 0;
        var zoneBg = Minimal7Logic.powerZoneColor(pct);
        var zoneFg = Minimal7Logic.powerZoneTextColor(pct);
        var text   = m3sPower.format("%d");

        drawCell(dc, 0, y, w, rowH, zoneFg, zoneBg, text);
    }

    // ── Row 3: speed (left)  |  cadence (right) ──────────────────────────
    hidden function drawRow3(dc as Graphics.Dc, w as Number, rowH as Number, y as Number, fg as Number) as Void {
        var half = w / 2;
        var cadenceBg = Minimal7Logic.cadenceTargetBgColor(mCadence, mCadenceMin, mCadenceMax);
        var cadenceFg = Minimal7Logic.cadenceTargetFgColor(mCadence, mCadenceMin, mCadenceMax, fg);
        drawCell(dc, 0,    y, half, rowH, fg, null, mSpeed.format("%.1f"));
        drawCell(dc, half, y, half, rowH, cadenceFg, cadenceBg, mCadence.format("%d"));
    }

    // ── Row 4: ascent (left)  |  distance (right) ────────────────────────
    hidden function drawRow4(dc as Graphics.Dc, w as Number, rowH as Number, y as Number, fg as Number) as Void {
        var half = w / 2;
        drawCell(dc, 0,    y, half, rowH, fg, null, mAscent.format("%.0f"));
        drawCell(dc, half, y, half, rowH, fg, null, mDistanceKm.format("%.2f"));
    }

    // ── Grid dividers ─────────────────────────────────────────────────────
    // Three horizontal lines at every row boundary.
    // Vertical lines split rows 1, 3, and 4; row 2 (power) is full-width.
    hidden function drawDividers(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        row1H as Number,
        row2H as Number,
        row3Y as Number,
        row4Y as Number,
        fg as Number
    ) as Void {
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);

        var row2Y = row1H;
        var row3BoundaryY = row2Y + row2H;

        // Horizontal lines
        dc.drawLine(0, row2Y,         w, row2Y);         // between rows 1 and 2
        dc.drawLine(0, row3BoundaryY, w, row3BoundaryY); // between rows 2 and 3
        dc.drawLine(0, row4Y,         w, row4Y);         // between rows 3 and 4

        // Vertical lines (not on the full-width power row)
        var mid = w / 2;
        dc.drawLine(mid, 0,             mid, row1H);         // row 1 split
        dc.drawLine(mid, row3Y,         mid, row4Y);         // row 3 split
        dc.drawLine(mid, row4Y,         mid, h);             // row 4 split
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    // Centers text inside a rectangular cell.
    hidden function drawCell(
        dc      as Graphics.Dc,
        x       as Number,
        y       as Number,
        w       as Number,
        h       as Number,
        fgColor as Number,
        bgColor as Number or Null,
        text    as String
    ) as Void {
        if (bgColor != null) {
            dc.setColor(bgColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, w, h);
        }

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.setClip(x, y, w, h);
        dc.drawText(
            x + w / 2,
            y + h / 2,
            fittingFont(dc, text, w, h),
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.clearClip();
    }

    // White text on black device background, black text on light background.
    hidden function defaultFgColor() as Number {
        return (getBackgroundColor() == Graphics.COLOR_BLACK)
            ? Graphics.COLOR_WHITE
            : Graphics.COLOR_BLACK;
    }

    hidden function standardCellFonts() as Array<Graphics.FontDefinition> {
        return [
            Graphics.FONT_NUMBER_THAI_HOT,
            Graphics.FONT_NUMBER_HOT,
            Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD
        ];
    }

    hidden function fittingFont(
        dc        as Graphics.Dc,
        text      as String,
        cellW     as Number,
        cellH     as Number
    ) as Graphics.FontDefinition {
        var maxWidth  = cellW - CELL_HORIZONTAL_PADDING;
        var maxHeight = cellH - CELL_VERTICAL_PADDING;
        var candidates = standardCellFonts();

        for (var i = 0; i < candidates.size(); i += 1) {
            var font = candidates[i];
            var dimensions = dc.getTextDimensions(text, font);
            if ((dimensions[0] <= maxWidth) && (dimensions[1] <= maxHeight)) {
                return font;
            }
        }

        return candidates[candidates.size() - 1];
    }

}
