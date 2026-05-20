using Toybox.ActivityRecording;
using Toybox.Activity;
using Toybox.FitContributor;
import Toybox.Position;
import Toybox.UserProfile;
import Toybox.Graphics;
import Toybox.Sensor;


class SoccerModel {
    // Enum für die verschiedenen Seiten (Scoreboard, Metriken, Uhrzeit)
    enum {
        PAGE_METRICS = 0,
        PAGE_PERFORMANCE = 1,
        PAGE_SCOREBOARD = 2,
        PAGE_CLOCK = 3
    }

    // Modelldaten (aktuelle Seite, Scores, Metriken, etc.)
    var scoreA = 0; // Anzahl Tore Team A
    var scoreB = 0; // Anzahl Tore Team B
    var isIndoor = false; // Standard ist Outdoor
    var currentPage = PAGE_METRICS; // Startseite: Metriken
    var maxPages = 4; // Anzahl der Seiten (Scoreboard, 2xMetriken, Uhrzeit)

    var currentHR = 0; // Aktuelle Herzfrequenz
    var distanceKm = 0.0; // Zurückgelegte Distanz in Kilometern
    var currentSpeedKmh = 0.0; // Aktuelle Geschwindigkeit in km/h
    var avgSpeedKmh = 0.0; // Durchschnittsgeschwindigkeit in km/h
    var calories = 0; // Kalorienverbrauch
    var hiTimeAccumulatorMs = 0; // Sammelt die Millisekunden im roten Bereich
    var hiMinutes = 0;           // Die vollen, erreichten Minuten
    var _lastHiMinTimerTime = 0;      // Um das Delta zu berechnen
    var activityTimeStr = "00:00";
    // --- Variablen für Sprint-Tracking ---
    var currentCadence = 0; // Aktuelle Schrittfrequenz
    var sprintCount = 0; // Anzahl der erkannten Sprints
    var fieldSprintCount = null;
    
    // Interne Zustände für den Zeitfenster-Filter
    private var _isCurrentlySprint = false;
    private var _sprintDurationSeconds = 0; 
    
    // Konfiguration der Sprint-Erkennung
    private const MIN_SPRINT_DURATION_SECS = 3; // Mindestens 3 Sekunden Vollgas
    private const SPRINT_CADENCE_THRESHOLD_HIGH = 175; // Ab 175 Schritten pro Minute 
    private const SPRINT_CADENCE_THRESHOLD_LOW = 160; // Unter 160 wird zurückgesetzt

    // Variablen für FIT-Felder
    var fieldScoreA = null;
    var fieldScoreB = null;
    var fieldHiMinutes = null;
    
    // Speichert das Array mit den Schwellenwerten für die Herzfrequenzzonen
    var hrZones = [90, 110, 130, 150, 170, 190];

    var session = null;

    function initialize() {
        // Zonen des Nutzers für allgemeinen Sport abfragen. 
        // Das Array enthält 6 Werte (Index 0 = Ruhepuls/Start Z1, Index 5 = Max HR)
        if (Toybox has :UserProfile) {
            hrZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        }

        //Schalter Indoor/Outdoor aus Properties holen
        isIndoor = Application.Properties.getValue("is_indoor");
    }

    // Die Schaltzentrale für die Aufnahme
    function startSession() {
        if (session == null) {
            


            //  GPS-Chip an/aus basierend auf der Einstellung
            if (isIndoor) {
                // GPS komplett abschalten (indoor oft kein GPS-Signal, spart Akku)
                Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
            } else {
                // GPS aktivieren
                Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
            }
            // Neue Aktivitätssession erstellen 
            // Name abhaengig von indoor/outdoor
            var sessionName = isIndoor ? WatchUi.loadResource($.Rez.Strings.SessionNameIndoor) : WatchUi.loadResource($.Rez.Strings.SessionNameOutdoor);
            session = ActivityRecording.createSession({
                :name => sessionName,
                :sport => Activity.SPORT_SOCCER,
                :subSport => Activity.SUB_SPORT_MATCH
            });



            // FIT-Felder initialisieren (ID muss mit der XML übereinstimmen!)
            // MESG_TYPE_SESSION bedeutet: Das ist ein Wert für das Endergebnis.
            var labelA = WatchUi.loadResource($.Rez.Strings.ScoreALabel);
            var labelB = WatchUi.loadResource($.Rez.Strings.ScoreBLabel);
            var labelHi = WatchUi.loadResource($.Rez.Strings.HiMinLabel);
            var unitScore = WatchUi.loadResource($.Rez.Strings.ScoreUnit);
            var unitMin = WatchUi.loadResource($.Rez.Strings.HiMinUnit);
            var labelSprint =  WatchUi.loadResource($.Rez.Strings.SprintLabel);
            var unitSprint = WatchUi.loadResource($.Rez.Strings.SprintUnit);

            // --- Score-Felder erstellen ---
            fieldScoreA = session.createField(labelA, 0, FitContributor.DATA_TYPE_UINT8, {
                :mesgType => FitContributor.MESG_TYPE_SESSION,
                :units => unitScore
            });
            
            fieldScoreB = session.createField(labelB, 1, FitContributor.DATA_TYPE_UINT8, {
                :mesgType => FitContributor.MESG_TYPE_SESSION,
                :units => unitScore
            });
            // --- High-Intensity-Minuten-Feld erstellen ---
            fieldHiMinutes = session.createField(labelHi, 2, FitContributor.DATA_TYPE_UINT16, {
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => unitMin
            });

            // --- Sprint-Feld erstellen --- 
            fieldSprintCount = session.createField(labelSprint, 3, FitContributor.DATA_TYPE_UINT8, {
                :mesgType => FitContributor.MESG_TYPE_SESSION,
                :units => unitSprint
            });         
            
            // Initiale Werte in die FIT-Datei schreiben
            fieldScoreA.setData(scoreA);
            fieldScoreB.setData(scoreB);
            fieldHiMinutes.setData(0);
            fieldSprintCount.setData(0);
        }
        
        if (!session.isRecording()) {
            session.start();
                        // Herzfrequenz-Sensor aktivieren (benötigt für die Herzfrequenzzonen und die Anzeige)
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
            Sensor.enableSensorEvents(method(:onSensor));
        }
    }


    // Garmin erfordert zwingend eine Callback-Funktion für enableLocationEvents, 
    // auch wenn sie leer bleibt, da wir die Daten über Activity.getActivityInfo() holen.
    function onPosition(info as Position.Info) as Void {
    }

    // Callback-Funktion für den Herzfrequenz-Sensor
    function onSensor(info as Sensor.Info) as Void {
        if (info.heartRate != null) {
            currentHR = info.heartRate;
        }
    }



    // Eigene Funktion, um Tore für A zu erhöhen und direkt ins FIT-File zu schreiben
    function addGoalTeamA() {
        scoreA++;
        if (fieldScoreA != null) {
            fieldScoreA.setData(scoreA);
        }
    }

    // Eigene Funktion für Team B
    function addGoalTeamB() {
        scoreB++;
        if (fieldScoreB != null) {
            fieldScoreB.setData(scoreB);
        }
    }

    // Eigene Funktion, um Tore für A abzuziehen
    function subGoalTeamA() {
        if (scoreA > 0) { // Verhindert negative Tore
            scoreA--;
            if (fieldScoreA != null) {
                fieldScoreA.setData(scoreA);
            }
        }
    }

    // Eigene Funktion, um Tore für B abzuziehen
    function subGoalTeamB() {
        if (scoreB > 0) { // Verhindert negative Tore
            scoreB--;
            if (fieldScoreB != null) {
                fieldScoreB.setData(scoreB);
            }
        }
    }

    function pauseSession() {
        if (session != null && session.isRecording()) {
            session.stop();
        }
    }

    function saveSession() {
        if (session != null) {
            session.save();
            session = null; // Session aufräumen
        }
    }

    function discardSession() {
        if (session != null) {
            session.discard();
            session = null; // Session aufräumen
        }
    }

    // Hilfsfunktion für die View (um z.B. ein "REC" Icon anzuzeigen)
    function isRecording() {
        if (session != null && session.isRecording()) {
            return true;
        }
        return false;
    }

    // Setzt einen Runden-Marker (Lap) in der FIT-Datei
    function addLap() {
        if (session != null && session.isRecording()) {
            session.addLap();
        }
    }

    function updateMetrics() {
        var info = Activity.getActivityInfo();
        if (info != null) {
            // Heart Rate
            if (info.currentHeartRate != null) {
                currentHR = info.currentHeartRate;
            }
            // Distanz in km umrechnen (info.elapsedDistance ist in Metern)
            if (info.elapsedDistance != null) {
                distanceKm = info.elapsedDistance / 1000.0;
            }
            // Dauer der Aktivität in Minuten:Sekunden umrechnen
            if (info.timerTime != null) {
                var timeInSeconds = info.timerTime / 1000;
                var minutes = timeInSeconds / 60;
                var seconds = timeInSeconds % 60;
                activityTimeStr = minutes.format("%02d") + ":" + seconds.format("%02d");
            }
            // Aktuelle Geschwindigkeit in km/h
            if (info.currentSpeed != null) {
                currentSpeedKmh = info.currentSpeed * 3.6; // m/s in km/h umrechnen
            } else {
                currentSpeedKmh = 0.0;
            }
            // Durchschnittsgeschwindigkeit in km/h
            if (info.averageSpeed != null) {
                avgSpeedKmh = info.averageSpeed * 3.6; // m/s in km/h umrechnen
            } else {
                avgSpeedKmh = 0.0;
            }
            // Kalorienverbrauch
            if (info.calories != null) {
                calories = info.calories;
            } else {
                calories = 0;
            }
            // High Intensity Zeit berechnen (Zeit über der Grenze von Zone 4)
            if(info.timerTime != null) {
                // 1. Delta-Zeit seit dem letzten Aufruf berechnen
                var currentTimerTime = info.timerTime;
                var deltaMs = currentTimerTime - _lastHiMinTimerTime;
                
                // Schutz gegen negative Werte (z.B. beim Zurücksetzen der Session)
                if (deltaMs > 0 && deltaMs < 5000) { 
                    
                // 2. Sind wir in der roten oder orangenen Zone?
                if (currentHR > 0 && hrZones != null && currentHR >= hrZones[3]) {
                    
                    // Exakte Millisekunden auf das High-Intensity-Konto buchen
                    hiTimeAccumulatorMs += deltaMs;
                    
                    // 3. Haben wir eine neue volle Minute erreicht?
                    var calculatedMinutes = hiTimeAccumulatorMs / 60000; 
                    
                    if (calculatedMinutes > hiMinutes) {
                        hiMinutes = calculatedMinutes; // Wert aktualisieren
                        
                        // FIT-File updaten
                        if (fieldHiMinutes != null) {
                            fieldHiMinutes.setData(hiMinutes);
                        }
                    }
                }
            }
            // --- Schrittfrequenz und Sprint-Logik ---
            if (info.currentCadence != null) {
                currentCadence = info.currentCadence;
            } else {
                currentCadence = 0;
            }

            if (currentCadence >= SPRINT_CADENCE_THRESHOLD_HIGH) {
                // Frequenz ist hoch, Sekunden hochzählen
                _sprintDurationSeconds++;

                // Zeitfenster erreicht?
                if (_sprintDurationSeconds >= MIN_SPRINT_DURATION_SECS) {
                    if (!_isCurrentlySprint) {
                        _isCurrentlySprint = true;
                        sprintCount++; // Sprint zählen!
                        
                        // Direkt in die Session schreiben
                        if (fieldSprintCount != null) {
                            fieldSprintCount.setData(sprintCount);
                        }
                    }
                }
            } else if (currentCadence < SPRINT_CADENCE_THRESHOLD_LOW) {
                // Reset: Der Spieler ist wieder im Trab oder steht
                _isCurrentlySprint = false;
                _sprintDurationSeconds = 0; 
            }
            
            // Merker für den nächsten Durchlauf setzen
            _lastHiMinTimerTime = currentTimerTime;
        }
        }   
    }

    // Funktion ermittelt die Farbe anhand des aktuellen Pulses
    function getHrColor() {
        if (currentHR == 0 || hrZones == null) {
            return Graphics.COLOR_WHITE; // Kein Puls = Weiß
        }
        
        // hrZones[1] ist die Obergrenze von Zone 1, etc.
        if (currentHR < hrZones[1]) { return Graphics.COLOR_LT_GRAY; } // Zone 1
        if (currentHR < hrZones[2]) { return Graphics.COLOR_BLUE; }    // Zone 2
        if (currentHR < hrZones[3]) { return Graphics.COLOR_GREEN; }   // Zone 3
        if (currentHR < hrZones[4]) { return Graphics.COLOR_ORANGE; }  // Zone 4
        
        return Graphics.COLOR_RED; // Zone 5 (Alles über der Grenze von Zone 4)
    }
}