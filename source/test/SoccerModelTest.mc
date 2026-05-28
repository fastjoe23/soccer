import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;

(:test)
class SoccerModelTest {

    // --------------------------------------------------------
    // TEST 1: Tor-Logik und Boundaries (Keine negativen Tore)
    // --------------------------------------------------------
    (:test)
    static function testGoalScoringLogic(logger ) as Boolean {
        var model = new $.SoccerModel();
        
        // Arrange & Act
        model.addGoalTeamA();
        model.addGoalTeamA();
        model.subGoalTeamA();
        
        model.addGoalTeamB();
        model.subGoalTeamB();
        model.subGoalTeamB(); // Versuch, unter 0 zu gehen
        
        // Assert
        if (model.scoreA != 1) {
            logger.error("Score A sollte 1 sein, ist aber " + model.scoreA);
            return false;
        }
        if (model.scoreB != 0) {
            logger.error("Score B sollte nicht unter 0 fallen, ist aber " + model.scoreB);
            return false;
        }
        
        return true;
    }

    // --------------------------------------------------------
    // TEST 2: Herzfrequenz-Farbgebung
    // --------------------------------------------------------
    (:test)
    static function testHeartRateColors(logger ) as Boolean {
        var model = new $.SoccerModel();
        // Zonen: [90, 110, 130, 150, 170, 190]
        
        model.currentHR = 100; // Unter hrZones[1] (110) -> LT_GRAY
        if (model.getHrColor() != Graphics.COLOR_LT_GRAY) {
            logger.error("Fehler bei Zone 1 Farbe."); return false;
        }

        model.currentHR = 160; // Unter hrZones[4] (170) -> ORANGE
        if (model.getHrColor() != Graphics.COLOR_ORANGE) {
            logger.error("Fehler bei Zone 4 Farbe."); return false;
        }

        model.currentHR = 180; // Über hrZones[4] -> RED
        if (model.getHrColor() != Graphics.COLOR_RED) {
            logger.error("Fehler bei Zone 5 Farbe."); return false;
        }
        
        return true;
    }

    // --------------------------------------------------------
    // TEST 3: Sprint-Erkennung mit gleitendem Durchschnitt (Moving Average)
    // --------------------------------------------------------
    (:test)
    static function testSprintDetectionMovingAverage(logger) as Boolean {
        var model = new $.SoccerModel();
        
        // --- EDGE CASE 1: Antritt aus dem Stand (Akute Beschleunigung) ---
        // Wenn der Hobbysportler steht, ist der Moving Average 0.0 km/h.
        // Ein Antritt auf 11 km/h ist zwar doppelt so schnell wie der Schnitt (0 * 2 = 0),
        // MUSS aber durch die absolute Mindestgeschwindigkeit von 12.0 km/h blockiert werden!
        
        model.processSprintLogic(11.0); // 1. Sekunde: unter MIN_SPEED_KMH
        model.processSprintLogic(11.0); // 2. Sekunde
        model.processSprintLogic(11.0); // 3. Sekunde
        
        if (model.sprintCount != 0) {
            logger.error("EC1 fehlgeschlagen: Sprint aus dem Stand gezählt, obwohl unter MIN_SPEED_KMH.");
            return false;
        }

        // --- EDGE CASE 2: Echter, gültiger Sprint für Hobbysportler ---
        // Wir simulieren gemütliches Traben (6 km/h) für 30 Sekunden, um den Puffer zu füllen.
        for (var i = 0; i < 30; i++) {
            model.processSprintLogic(6.0);
        }
        
        // Jetzt explosionsartiger Antritt: Schnitt ist 6 km/h -> Schwelle für Multiplier (1.6) ist 9.6 km/h.
        // Da wir über 12.0 km/h (MIN_SPEED) und über 9.6 km/h springen, muss das greifen!
        model.processSprintLogic(16.0); // Sekunde 1 des Sprints
        model.processSprintLogic(16.0); // Sekunde 2 des Sprints -> JETZT muss der Counter fliegen (MIN_SPRINT_DURATION_SECS = 2)
        
        if (model.sprintCount != 1) {
            logger.error("EC2 fehlgeschlagen: Echter Sprint (2s, >12km/h, >1.6x Schnitt) wurde nicht erkannt.");
            return false;
        }

        // --- EDGE CASE 3: Sprint halten (Dauer-Vollgas) ---
        // Wir rennen weiter mit 16 km/h. Der Counter darf nicht weiter hochzählen!
        model.processSprintLogic(16.0); // Sekunde 3
        model.processSprintLogic(16.0); // Sekunde 4
        
        if (model.sprintCount != 1) {
            logger.error("EC3 fehlgeschlagen: Gehaltener Sprint hat den Counter mehrfach erhöht.");
            return false;
        }

        return true;
    }

    (:test)
    static function testSprintCancelAndHysteresis(logger) as Boolean {
        var model = new $.SoccerModel();

        // --- EDGE CASE 4: Die unfaire Hysterese (Sanftes Auslaufen) ---
        // Wir füllen den Puffer wieder mit moderatem Tempo (10 km/h).
        for (var i = 0; i < 30; i++) {
            model.processSprintLogic(10.0);
        }
        
        // Sprint starten: Schnitt 10 -> Multiplier (1.6) erfordert > 16.0 km/h
        model.processSprintLogic(20.0); // Sekunde 1
        model.processSprintLogic(20.0); // Sekunde 2 -> Sprint flippt auf true (sprintCount = 1)
        
        // Jetzt werden wir langsam müde und bremsen ab auf 14 km/h.
        // Der Moving Average zieht durch das Renntempo leicht an (auf ca. 10.6 km/h).
        // 130% von 10.6 km/h wären ~13.8 km/h. Da wir mit 14 km/h noch über dem SPRINT_CANCEL_FACTOR (1.1 bis 1.3) liegen,
        // darf der Sprint noch NICHT abgebrochen werden! Er läuft im Puffer weiter.
        model.processSprintLogic(14.0); 
        
        // Wenn wir jetzt sofort wieder Gas geben, darf KEIN neuer Sprint zählen, weil der alte nie beendet war.
        model.processSprintLogic(20.0);
        model.processSprintLogic(20.0);
        
        if (model.sprintCount != 1) {
            logger.error("EC4 fehlgeschlagen: Unvollständiger Abbruch (Hysterese-Schutz) hat Folge-Sprint fälschlicherweise getriggert.");
            return false;
        }

        // --- EDGE CASE 5: Harter Abbruch (Unter das Limit fallen) ---
        // Wir bremsen radikal ab auf Geh-Tempo (4.0 km/h) -> Das reißt sofort die MIN_SPEED_KMH (12.0)
        model.processSprintLogic(4.0); 
        
        // Jetzt ist der Sprint-Status im Modell garantiert wieder 'false'.
        // Ein erneuter Antritt muss sofort wieder als neuer Sprint zählen.
        model.processSprintLogic(20.0);
        model.processSprintLogic(20.0);
        
        if (model.sprintCount != 2) {
            logger.error("EC5 fehlgeschlagen: Nach hartem Geschwindigkeitsabfall wurde der nächste Sprint blockiert.");
            return false;
        }

        return true;
    }

 // --------------------------------------------------------
    // TEST 4: High-Intensity Minuten Aggregation
    // --------------------------------------------------------
    (:test)
    static function testHighIntensityMinutes(logger) as Boolean {
        var model = new $.SoccerModel();
        // Zonen: [90, 110, 130, 150, 170, 190] -> Zone 4 beginnt bei Index 3 (150)
        
        var currentTimeMs = 1000;
        
        // 1. Initiale Zeit setzen (1 Sekunde vergangen, HR 120 -> Keine HIT)
        model.processHiMinutes(currentTimeMs, 120); 
        
        // 2. 30 Sekunden im roten Bereich simulieren (in 1-Sekunden-Schritten)
        for (var i = 0; i < 30; i++) {
            currentTimeMs += 1000; // 1 Sekunde weiter
            model.processHiMinutes(currentTimeMs, 160); // HR 160 ist >= hrZones[3]
        }
        
        // Nach 30 Sekunden darf noch keine volle Minute erreicht sein
        if (model.hiMinutes != 0) {
            logger.error("Fehler: HIT Minuten zu früh inkrementiert. Ist: " + model.hiMinutes);
            return false;
        }
        
        // 3. Weitere 30 Sekunden im roten Bereich simulieren
        for (var i = 0; i < 30; i++) {
            currentTimeMs += 1000; 
            model.processHiMinutes(currentTimeMs, 165); 
        }
        
        // Nach insgesamt 60 Sekunden muss hiMinutes exakt 1 sein
        if (model.hiMinutes != 1) {
            logger.error("Fehler: HIT Minute wurde nach 60.000ms nicht gewertet. Ist: " + model.hiMinutes);
            return false;
        }
        
        // 4. Testausstieg: Zurück in die grüne Zone (Puls fällt)
        currentTimeMs += 1000;
        model.processHiMinutes(currentTimeMs, 120);
        
        if (model.hiMinutes != 1) {
            logger.error("Fehler: HIT Minuten haben sich bei niedrigem Puls fälschlicherweise verändert.");
            return false;
        }
        
        return true;
    }

    
    // --------------------------------------------------------
    // TEST 5: Sprint beginnt exakt auf Threshold
    // --------------------------------------------------------
    (:test)
    static function testSprintThresholdBoundary(logger) as Boolean {

        var model = new $.SoccerModel();

        // Durchschnitt vorbereiten
        for (var i = 0; i < 30; i++) {
            model.processSprintLogic(10.0);
        }

        // 10 * 1.6 = exakt 16.0
        model.processSprintLogic(16.0);
        model.processSprintLogic(16.0);

        // Erwartung:
        // Wenn dein Code ">" nutzt -> kein Sprint
        // Wenn dein Code ">=" nutzt -> Sprint

        // HIER ANPASSEN:
        var expectedSprintCount = 0;

        if (model.sprintCount != expectedSprintCount) {
            logger.error("Threshold-Verhalten inkonsistent.");
            return false;
        }

        return true;
    }

    // --------------------------------------------------------
    // TEST 6: Sprint wird durch kurzen Peak NICHT ausgelöst
    // --------------------------------------------------------
    (:test)
    static function testShortSpeedSpikeDoesNotTriggerSprint(logger) as Boolean {

        var model = new $.SoccerModel();

        for (var i = 0; i < 30; i++) {
            model.processSprintLogic(6.0);
        }

        // Nur 1 Sekunde Peak
        model.processSprintLogic(20.0);

        if (model.sprintCount != 0) {
            logger.error("Sprint wurde durch kurzen Peak ausgelöst.");
            return false;
        }

        return true;
    }

    // --------------------------------------------------------
    // TEST 7: Mehrere Sprints korrekt getrennt zählen
    // --------------------------------------------------------
    (:test)
    static function testMultipleIndependentSprints(logger) as Boolean {

        var model = new $.SoccerModel();

        for (var i = 0; i < 30; i++) {
            model.processSprintLogic(6.0);
        }

        // Sprint 1
        model.processSprintLogic(20.0);
        model.processSprintLogic(20.0);

        // Vollständiger Abbruch
        model.processSprintLogic(4.0);
        model.processSprintLogic(4.0);

        // Sprint 2
        model.processSprintLogic(20.0);
        model.processSprintLogic(20.0);

        if (model.sprintCount != 2) {
            logger.error("Mehrere getrennte Sprints wurden falsch gezählt.");
            return false;
        }

        return true;
    }

    // --------------------------------------------------------
    // TEST 8: High Intensity Minuten dürfen nicht negativ werden
    // --------------------------------------------------------
    (:test)
    static function testHiMinutesNeverNegative(logger) as Boolean {

        var model = new $.SoccerModel();

        var currentTimeMs = 1000;

        for (var i = 0; i < 100; i++) {
            currentTimeMs += 1000;
            model.processHiMinutes(currentTimeMs, 80);
        }

        if (model.hiMinutes < 0) {
            logger.error("HI Minutes wurden negativ.");
            return false;
        }

        return true;
    }

    // --------------------------------------------------------
    // TEST 9: Sehr hohe Herzfrequenzwerte
    // --------------------------------------------------------
    (:test)
    static function testExtremeHeartRateValues(logger) as Boolean {

        var model = new $.SoccerModel();

        model.currentHR = 999;

        if (model.getHrColor() != Graphics.COLOR_RED) {
            logger.error("Extreme HR-Werte werden falsch behandelt.");
            return false;
        }

        return true;
    }

    // --------------------------------------------------------
    // TEST 10: Negative Herzfrequenzwerte
    // --------------------------------------------------------
    (:test)
    static function testNegativeHeartRate(logger) as Boolean {

        var model = new $.SoccerModel();

        model.currentHR = -10;

        // Erwartung: Niedrigste Zone
        if (model.getHrColor() != Graphics.COLOR_LT_GRAY) {
            logger.error("Negative HR-Werte führen zu falscher Zone.");
            return false;
        }

        return true;
    }

    // --------------------------------------------------------
    // TEST 11: Score darf niemals negativ werden
    // --------------------------------------------------------
    (:test)
    static function testScoreNeverNegative(logger) as Boolean {

        var model = new $.SoccerModel();

        for (var i = 0; i < 20; i++) {
            model.subGoalTeamA();
            model.subGoalTeamB();
        }

        if (model.scoreA < 0 || model.scoreB < 0) {
            logger.error("Score wurde negativ.");
            return false;
        }

        return true;
    }

    // --------------------------------------------------------
    // TEST 12: Sehr hohe Scores
    // --------------------------------------------------------
    (:test)
    static function testVeryHighScores(logger) as Boolean {

        var model = new $.SoccerModel();

        for (var i = 0; i < 200; i++) {
            model.addGoalTeamA();
        }

        if (model.scoreA != 200) {
            logger.error("Hohe Scores werden falsch verarbeitet.");
            return false;
        }

        return true;
    }

    // --------------------------------------------------------
    // TEST 13: Moving Average stabilisiert sich korrekt
    // --------------------------------------------------------
    (:test)
    static function testMovingAverageStability(logger) as Boolean {

        var model = new $.SoccerModel();

        for (var i = 0; i < 200; i++) {
            model.processSprintLogic(10.0);
        }

        // Nach langer stabiler Geschwindigkeit
        // darf kein Sprint entstehen
        if (model.sprintCount != 0) {
            logger.error("Moving Average driftet fehlerhaft.");
            return false;
        }

        return true;
    }


}