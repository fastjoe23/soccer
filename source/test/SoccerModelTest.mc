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
    // TEST 3: Sprint Hysterese und Zeitfenster-Filter
    // --------------------------------------------------------
    (:test)
    static function testSprintDetectionFilter(logger ) as Boolean {
        var model = new $.SoccerModel();
        
        // 1. Kurzer Ausreißer (z.B. Einwurf) -> Sollte nicht zählen
        model.processSprintLogic(180); // Sekunde 1
        model.processSprintLogic(180); // Sekunde 2
        model.processSprintLogic(150); // Sekunde 3 (Fällt ab)
        
        if (model.sprintCount != 0) {
            logger.error("Fehler: Sprint wurde zu früh gezählt (Anti-Chatter versagt).");
            return false;
        }
        
        // 2. Echter Sprint (3 Sekunden Vollgas)
        model.processSprintLogic(180); // Sekunde 1
        model.processSprintLogic(185); // Sekunde 2
        model.processSprintLogic(190); // Sekunde 3
        
        if (model.sprintCount != 1) {
            logger.error("Fehler: Echter Sprint wurde nicht erkannt.");
            return false;
        }
        
        // 3. Sprint halten (sollte den Counter nicht weiter hochzählen)
        model.processSprintLogic(180); // Sekunde 4
        if (model.sprintCount != 1) {
            logger.error("Fehler: Gehaltener Sprint hat zweiten Sprint ausgelöst.");
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
}