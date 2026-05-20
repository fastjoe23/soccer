import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;
import Toybox.System;

class SoccerView extends WatchUi.View {

    private var _timer as Timer.Timer;
    private var _model as SoccerModel;

    // Strings für die Button-Hints (werden in initialize() aus Ressourcen geladen)
    private var _goalA as String;
    private var _goalB as String;
    private var _scoreTitle as String;
    private var _distLabel as String;
    private var _hitLabel as String;
    private var _timerLabel as String;
    private var _speedLabel as String;
    private var _calLabel as String;
    private var _sprintLabel as String;


    public function initialize(model as SoccerModel) {
        View.initialize();
        _model = model;
        _timer = new Timer.Timer();
        // Strings aus Resourcen laden
        _goalA = WatchUi.loadResource($.Rez.Strings.ViewGoalA);
        _goalB = WatchUi.loadResource($.Rez.Strings.ViewGoalB);
        _scoreTitle = WatchUi.loadResource($.Rez.Strings.ViewScore);
        _distLabel = WatchUi.loadResource($.Rez.Strings.ViewDistance);
        _hitLabel = WatchUi.loadResource($.Rez.Strings.ViewHIT);
        _timerLabel = WatchUi.loadResource($.Rez.Strings.ViewTimer);
        _speedLabel = WatchUi.loadResource($.Rez.Strings.ViewSpeed);
        _calLabel = WatchUi.loadResource($.Rez.Strings.ViewCalories);
        _sprintLabel = WatchUi.loadResource($.Rez.Strings.ViewSprint);

    }

    public function onShow() as Void {
        _timer.start(method(:onTimer), 1000, true);
    }

    public function onHide() as Void {
        _timer.stop();
    }

    function onUpdate(dc) {
        // 1. ECHTE DATEN VOM SENSOR HOLEN
        _model.updateMetrics();

        // 2. ZEICHNEN
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        if (_model.currentPage == 0) {
            drawMetricsPage(dc, cx, cy);
        } else if (_model.currentPage == 1) {
            drawPerformancePage(dc, cx, cy);
        } else if (_model.currentPage == 2) {
            drawScoreboardPage(dc, cx, cy);
        } else if (_model.currentPage == 3) {
            drawClockPage(dc, cx, cy);
        }

        drawPageIndicator(dc, cx, dc.getHeight() - 15);
    }
    //--------------------------------------------
    // --- Hilfs-Funktionen für die Seiten     ---
    //--------------------------------------------

    // --- HELPER: Hintergrund-Gitter zeichnen ---
    private function drawGridBackground(dc as Dc, width as Number, height as Number) {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, height * 0.32, width, height * 0.32);
        dc.drawLine(0, height * 0.65, width, height * 0.65);
        dc.drawLine(width / 2, height * 0.32, width / 2, height * 0.65);
    }

    // --- HELPER: Mittleren 2er-Block zeichnen ---
    private function drawMiddleDualMetrics(dc as Dc, width as Number, height as Number, labelLeft as String, labelRight as String, valLeft as String, valRight as String) {
        // Labels
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width * 0.25, height * 0.38, Graphics.FONT_XTINY, labelLeft, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width * 0.75, height * 0.38, Graphics.FONT_XTINY, labelRight, Graphics.TEXT_JUSTIFY_CENTER);

        // Werte
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width * 0.25, height * 0.52, Graphics.FONT_MEDIUM, valLeft, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width * 0.75, height * 0.52, Graphics.FONT_MEDIUM, valRight, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // --- HELPER: Timer unten zeichnen ---
    private function drawBottomTimer(dc as Dc, cx as Number, height as Number) {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 0.71, Graphics.FONT_XTINY, _timerLabel, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 0.83, Graphics.FONT_LARGE, _model.activityTimeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Hilfsfunktion: Zeichnet ein Herz aus Primitiven (sehr RAM-schonend)
    private function drawHeart(dc, x, y) {
        dc.fillCircle(x - 5, y - 4, 5); // Linker Bogen
        dc.fillCircle(x + 5, y - 4, 5); // Rechter Bogen
        // Das untere Dreieck des Herzens
        var pts = [ [x - 10, y - 2], [x + 10, y - 2], [x, y + 10] ];
        dc.fillPolygon(pts);
    }

    //--------------------------------------------
    // --- Funktionen für die einzelnen Seiten ---
    //--------------------------------------------

    // --- SEITE: SCOREBOARD (Mit Button-Hints) ---
   private function drawScoreboardPage(dc as Dc, cx as Number, cy as Number) {
        var width = dc.getWidth();
        var height = dc.getHeight();

        // 1. Titel oben (ca. 12% der Höhe)
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 0.12, Graphics.FONT_XTINY, _scoreTitle, Graphics.TEXT_JUSTIFY_CENTER);

        // 2. Team-Bezeichnungen (Relative Y-Position: ca. 32% der Höhe)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var labelY = height * 0.32; 
        dc.drawText(width * 0.30, labelY, Graphics.FONT_SMALL, "A", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width * 0.70, labelY, Graphics.FONT_SMALL, "B", Graphics.TEXT_JUSTIFY_CENTER);

        // 3. Große Score-Anzeige (Relative Y-Position: ca. 55% der Höhe)
        var scoreY = height * 0.55;
        dc.drawText(cx, scoreY, Graphics.FONT_NUMBER_HOT, _model.scoreA.toString() + " : " + _model.scoreB.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // 4. Button-Hints (Nur anzeigen, wenn das Spiel läuft)
        if (_model.isRecording()) {
            // Rechter Rand für die Hints: 85% der Bildschirmbreite 
            // (15% Einrückung schützt vor dem Abschneiden auf runden Displays)
            var hintX = width * 0.85;

            // Hint für Team A (Oben Rechts -> START Taste bei ca. 25% Höhe)
            dc.drawText(hintX, height * 0.25, Graphics.FONT_XTINY, _goalA, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

            // Hint für Team B (Unten Rechts -> BACK Taste bei ca. 75% Höhe)
            dc.drawText(hintX, height * 0.75, Graphics.FONT_XTINY, _goalB, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // --- SEITE 0: METRIKEN (Puls, Distanz, HIT) ---
    private function drawMetricsPage(dc, cx, cy) {
        var width = dc.getWidth();
        var height = dc.getHeight();

        drawGridBackground(dc, width, height);

        // BEREICH 1: HERZFREQUENZ (Individuell)
        var hrY = height * 0.16;
        dc.setColor(_model.getHrColor(), Graphics.COLOR_TRANSPARENT);
        drawHeart(dc, cx - 35, hrY); // Herz-Icon
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 10, hrY, Graphics.FONT_LARGE, _model.currentHR.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // BEREICH 2 & 3: Über Helper-Funktionen zeichnen
        drawMiddleDualMetrics(dc, width, height, _distLabel, _hitLabel, _model.distanceKm.format("%.2f"), _model.hiMinutes.toString());
        drawBottomTimer(dc, cx, height);
    }

    // --- SEITE 1: PERFORMANCE METRIKEN (Speed, Kalorien, Sprints) ---
    private function drawPerformancePage(dc as Dc, cx as Number, cy as Number) {
        var width = dc.getWidth();
        var height = dc.getHeight();

        drawGridBackground(dc, width, height);

        // BEREICH 1: AKTULLE GESCHWINDIGKEIT (Individuell)
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 0.06, Graphics.FONT_XTINY, _speedLabel, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 0.18, Graphics.FONT_LARGE, _model.currentSpeedKmh.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // BEREICH 2 & 3: Über Helper-Funktionen zeichnen
        drawMiddleDualMetrics(dc, width, height, _calLabel, _sprintLabel, _model.calories.toString(), _model.sprintCount.toString());
        drawBottomTimer(dc, cx, height);
    }


    // --- SEITE: UHRZEIT ---
    private function drawClockPage(dc as Dc, cx as Number, cy as Number) {
        var clockTime = System.getClockTime();
        var timeStr = clockTime.hour.format("%02d") + ":" + clockTime.min.format("%02d");
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // --- HELPER: PUNKTE FÜR DAS KARUSSELL ---
    private function drawPageIndicator(dc as Dc, cx as Number, y as Number) {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        var spacing = 15;
        var startX = cx - ((_model.maxPages - 1) * spacing) / 2;

        for (var i = 0; i < _model.maxPages; i++) {
            if (i == _model.currentPage) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(startX + (i * spacing), y, 4);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(startX + (i * spacing), y, 3);
            }
        }
    }

    public function onTimer() as Void {
        WatchUi.requestUpdate();
    }
}