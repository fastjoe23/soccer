/*
 * Copyright (C) 2026 fastjoe23
 * 
 * Soccer Match Tracker - Track Scores & Fitness Metrics on the Pitch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */
 
using Toybox.ActivityRecording;
using Toybox.Activity;
using Toybox.FitContributor;
import Toybox.Position;
import Toybox.UserProfile;
import Toybox.Graphics;
import Toybox.Sensor;
import Toybox.Lang;
import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Time;


class SoccerModel {
    // Enum für die verschiedenen Seiten (Scoreboard, Metriken, Uhrzeit)
    enum {
        PAGE_METRICS = 0,
        PAGE_PERFORMANCE = 1,
        PAGE_SCOREBOARD = 2,
        PAGE_CLOCK = 3
    }

    // Modelldaten (aktuelle Seite, Scores, Metriken, etc.)
    var scoreA as Number = 0; // Anzahl Tore Team A
    var scoreB as Number = 0; // Anzahl Tore Team B
    var isIndoor as Boolean = false; // Standard ist Outdoor
    var currentPage as Number = PAGE_METRICS; // Startseite: Metriken
    var maxPages as Number = 4; // Anzahl der Seiten (Scoreboard, 2xMetriken, Uhrzeit)

    var currentHR as Number = 0; // Aktuelle Herzfrequenz
    var distanceKm as Float = 0.0; // Zurückgelegte Distanz in Kilometern
    var currentSpeedKmh as Float = 0.0; // Aktuelle Geschwindigkeit in km/h
    var calories as Number = 0; // Kalorienverbrauch
    private var hiTimeAccumulatorMs as Number = 0; // Sammelt die Millisekunden im roten Bereich
    var hiMinutes as Number = 0;           // Die vollen, erreichten Minuten
    private var _lastHiMinTimerTime as Number = 0;      // Um das Delta zu berechnen
    var activityTimeStr as String = "00:00";
    // --- Variablen für Sprint-Tracking ---
    private var currentCadence as Number = 0; // Aktuelle Schrittfrequenz
    var sprintCount as Number = 0; // Anzahl der erkannten Sprints
    private var fieldSprintCount as FitContributor.Field? = null;
    
    // Interne Zustände für den Zeitfenster-Filter
    private var _isCurrentlySprint as Boolean = false;
    private var _sprintDurationSeconds as Number = 0; 
    
    // Konfiguration der Sprint-Erkennung
    private const MIN_SPRINT_DURATION_SECS = 2.0; // Mindestens 2 Sekunden Vollgas
    private const MIN_SPEED_KMH = 12.0; // Absolute Mindestgeschwindigkeit für einen Sprint
    private const SPRINT_MULTIPLIER = 1.6; //  CurrentSpeed muss Sprint_MULTIPLIER mal höher sein als der Moving Average der letzten 30 Sekunden, um als Sprint zu gelten
    private const SPRINT_CANCEL_FACTOR = 1.1; // Wenn die Geschwindigkeit unter 110% des Moving Average fällt, wird der Sprint abgebrochen
    // --- Variablen für den gleitenden Durchschnitt ---
    private const SPEED_BUFFER_SIZE = 30; // 30 Sekunden Historie
    private var _speedBuffer as Array<Float> = [] as Array<Float>;
    private var _speedBufferSum as Float = 0.0;
    private var _speedBufferIndex as Number = 0;
    private var _movingAvgSpeed as Float = 0.0;
    // Letzte volle Sekunde der Aktivitätszeit, für die die Sprint-Logik gelaufen ist.
    // Dadurch läuft die Logik genau 1x pro Sekunde Spielzeit – unabhängig davon,
    // wie oft der Bildschirm neu gezeichnet wird (z.B. nach Tastendruck).
    private var _lastSprintSec as Number = 0;
    private const MAX_SPRINT_CATCHUP_SECS = 5; // Max. nachzuholende Sekunden (z.B. nach Pause)

    // --- Wiederherstellung nach Absturz / App-Neustart ---
    private const STORAGE_KEY = "match_state";
    private const RECOVERY_MAX_AGE_SECS = 10800; // Gespeicherter Stand gilt max. 3 Stunden

    // Variablen für FIT-Felder
    private var fieldScoreA as FitContributor.Field? = null;
    private var fieldScoreB as FitContributor.Field? = null;
    private var fieldHiMinutes as FitContributor.Field? = null;
    private var fieldCadence as FitContributor.Field? = null;
    private var fieldLapScoreA as FitContributor.Field? = null;
    private var fieldLapScoreB as FitContributor.Field? = null;
    
    // Speichert das Array mit den Schwellenwerten für die Herzfrequenzzonen
    private var hrZones as Array<Number> = [90, 110, 130, 150, 170, 190] as Array<Number>;

    private var session as ActivityRecording.Session? = null;

    // GPS-Qualität (Position.QUALITY_*), wird schon vor dem Start angezeigt
    var gpsQuality as Number = Position.QUALITY_NOT_AVAILABLE;

    // --- Torwartwechsel (Cambio de portero) ---
    // Intervall in Minuten (0 = deaktiviert), wird über die Einstellungen gesetzt
    var gkIntervalMin as Number = 5;
    var gkChangeCount as Number = 0;          // Anzahl der bereits fälligen Wechsel
    var gkRemainingSec as Number = 0;         // Restzeit bis zum nächsten Wechsel (Sekunden)
    var gkAlertPending as Boolean = false;     // true, sobald ein Wechsel fällig wird (View vibriert & setzt zurück)
    private var _gkLastChangeMs as Number = 0; // timerTime des letzten Wechsels
    private var _gkAlertUntilMs as Number = 0; // Bis zu diesem timerTime wird der Hinweis angezeigt
    private var fieldGkChanges as FitContributor.Field? = null;
    private var _gkLastTimerTime as Number = 0;
    private const GK_ALERT_DURATION_MS = 10000; // Hinweis 10 Sekunden lang anzeigen

    function initialize() {
        // Zonen des Nutzers für allgemeinen Sport abfragen. 
        // Das Array enthält 6 Werte (Index 0 = Ruhepuls/Start Z1, Index 5 = Max HR)
        // Default-Werte stehen in der Deklaration von hrZones
        if (Toybox has :UserProfile) {
            var zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
            if (zones != null && zones.size() >= 6) {
                hrZones = zones;
            }
        }

        // Einstellungen (Uhr-Menü oder Connect IQ App auf dem Handy) laden
        loadSettings();

        // SpeedPuffer initialisieren
        _speedBuffer = new Array<Float>[SPEED_BUFFER_SIZE];
        for (var i = 0; i < SPEED_BUFFER_SIZE; i++) {
            _speedBuffer[i] = 0.0;
        }
    }

    // Liest die Einstellungen aus den Properties. Wird beim Start und nach
    // Änderungen in der Connect IQ App auf dem Handy aufgerufen.
    function loadSettings() as Void {
        // Indoor/Outdoor (sicher casten, Fallback auf Outdoor).
        // Während einer laufenden Session nicht umschalten (GPS/Session-Typ stehen fest).
        if (session == null) {
            var isIndoorValue = Application.Properties.getValue("is_indoor");
            isIndoor = (isIndoorValue instanceof Lang.Boolean) ? isIndoorValue : false;
        }

        // Torwartwechsel-Intervall (0 = aus, max. 60 Minuten)
        var gkValue = Application.Properties.getValue("gk_interval");
        if (gkValue instanceof Lang.Number && gkValue >= 0 && gkValue <= 60) {
            gkIntervalMin = gkValue;
        }
        if (session == null) {
            gkRemainingSec = gkIntervalMin * 60;
        }
    }

    // GPS schon vor dem Anpfiff einschalten, damit beim Start ein Fix vorhanden ist.
    // Indoor wird das GPS ausgeschaltet.
    function updateGpsMode() as Void {
        if (isIndoor) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
            gpsQuality = Position.QUALITY_NOT_AVAILABLE;
        } else {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        }
    }

    // Die Schaltzentrale für die Aufnahme
    function startSession() as Void {
        if (session == null) {
            createSession();
        }
        
        // Session nur starten, wenn sie existiert und nicht läuft
        if (session != null && !session.isRecording()) {
            session.start();
            // Herzfrequenz-Sensor aktivieren
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
            Sensor.enableSensorEvents(method(:onSensor));
        }
    }
    
    // Hilfsfunktion: Erstellt die ActivityRecording Session und initialisiert FIT-Felder
    private function createSession() as Void {
        // GPS-Chip an/aus basierend auf der Einstellung
        if (isIndoor) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        } else {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        }
        
        // Neue Aktivitätssession erstellen
        var sessionName = isIndoor ? (WatchUi.loadResource($.Rez.Strings.SessionNameIndoor) as String) : (WatchUi.loadResource($.Rez.Strings.SessionNameOutdoor) as String);
        session = ActivityRecording.createSession({
            :name => sessionName,
            :sport => Activity.SPORT_SOCCER,
            :subSport => Activity.SUB_SPORT_MATCH
        });
        
        // Prüfen, ob Session erfolgreich erstellt wurde
        if (session == null) {
            return;
        }
        
        initializeFitFields();
    }
    
    // Hilfsfunktion: Erstellt alle FIT-Felder mit Null-Checks
    private function initializeFitFields() as Void {
        if (session == null) { return; }
        
        var labelA = (WatchUi.loadResource($.Rez.Strings.ScoreALabel) as String);
        var labelB = (WatchUi.loadResource($.Rez.Strings.ScoreBLabel) as String);
        var labelHi = (WatchUi.loadResource($.Rez.Strings.HiMinLabel) as String);
        var unitScore = (WatchUi.loadResource($.Rez.Strings.ScoreUnit) as String);
        var unitMin = (WatchUi.loadResource($.Rez.Strings.HiMinUnit) as String);
        var labelSprint = (WatchUi.loadResource($.Rez.Strings.SprintLabel) as String);
        var unitSprint = (WatchUi.loadResource($.Rez.Strings.SprintUnit) as String);
        var labelCadence = (WatchUi.loadResource($.Rez.Strings.CadenceLabel) as String);
        var unitCadence = (WatchUi.loadResource($.Rez.Strings.CadenceUnit) as String);

        // Score-Felder
        fieldScoreA = session.createField(labelA, 0, FitContributor.DATA_TYPE_UINT8, {
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => unitScore
        });
        
        fieldScoreB = session.createField(labelB, 1, FitContributor.DATA_TYPE_UINT8, {
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => unitScore
        });
        
        // HIT-Minuten-Feld
        fieldHiMinutes = session.createField(labelHi, 2, FitContributor.DATA_TYPE_UINT16, {
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => unitMin
        });

        // Sprint-Feld
        fieldSprintCount = session.createField(labelSprint, 3, FitContributor.DATA_TYPE_UINT8, {
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => unitSprint
        });

        // Schrittfrequenz-Feld
        fieldCadence = session.createField(labelCadence, 4, FitContributor.DATA_TYPE_UINT8, {
            :mesgType => FitContributor.MESG_TYPE_RECORD,
            :units => unitCadence
        });

        // Runden-Felder
        fieldLapScoreA = session.createField("lapScoreA", 5, FitContributor.DATA_TYPE_UINT8, {
            :mesgType => FitContributor.MESG_TYPE_LAP,
            :units => unitScore
        });
        
        fieldLapScoreB = session.createField("lapScoreB", 6, FitContributor.DATA_TYPE_UINT8, {
            :mesgType => FitContributor.MESG_TYPE_LAP,
            :units => unitScore
        });
        
        // Torwartwechsel-Feld
        fieldGkChanges = session.createField((WatchUi.loadResource($.Rez.Strings.GkChangesLabel) as String), 7, FitContributor.DATA_TYPE_UINT8, {
            :mesgType => FitContributor.MESG_TYPE_SESSION,
            :units => unitSprint
        });

        // Initiale Werte in FIT schreiben (mit Null-Checks)
        if (fieldScoreA != null) { fieldScoreA.setData(scoreA); }
        if (fieldScoreB != null) { fieldScoreB.setData(scoreB); }
        if (fieldHiMinutes != null) { fieldHiMinutes.setData(hiMinutes); }
        if (fieldSprintCount != null) { fieldSprintCount.setData(sprintCount); }
        if (fieldCadence != null) { fieldCadence.setData(0); }
        if (fieldGkChanges != null) { fieldGkChanges.setData(gkChangeCount); }
    }


    // Garmin erfordert zwingend eine Callback-Funktion für enableLocationEvents, 
    // auch wenn sie leer bleibt, da wir die Daten über Activity.getActivityInfo() holen.
    // Zusätzlich merken wir uns die GPS-Qualität für die Anzeige vor dem Start.
    function onPosition(info as Position.Info) as Void {
        gpsQuality = info.accuracy;
    }

    // Callback-Funktion für den Herzfrequenz-Sensor
    function onSensor(info as Sensor.Info) as Void {
        var hr = info.heartRate;
        if (hr != null) {
            currentHR = hr;
        }
    }



    // Eigene Funktion, um Tore für A zu erhöhen und direkt ins FIT-File zu schreiben
    function addGoalTeamA() as Void {
        scoreA++;
        if (fieldScoreA != null) {
            fieldScoreA.setData(scoreA);
        }
        logGoal();
    }

    // Eigene Funktion für Team B
    function addGoalTeamB() as Void {
        scoreB++;
        if (fieldScoreB != null) {
            fieldScoreB.setData(scoreB);
        }
        // Eintrag in die Runden-Tabelle schreiben
        logGoal();
    }

    // Funktion zum Loggen eines Tores
    function logGoal() as Void {
        // Eintrag in die Runden-Tabelle schreiben
        if (session != null && session.isRecording()) {
            if (fieldLapScoreA != null) { fieldLapScoreA.setData(scoreA); }
            if (fieldLapScoreB != null) { fieldLapScoreB.setData(scoreB); }
            addLap();// Schließt die aktuelle "Runde" ab und loggt den Spielstand
        }
        saveState(); // Spielstand sichern (Absturzschutz)
    }

    // Eigene Funktion, um Tore für A abzuziehen
    function subGoalTeamA() as Void {
        if (scoreA > 0) { // Verhindert negative Tore
            scoreA--;
            if (fieldScoreA != null) {
                fieldScoreA.setData(scoreA);
            }
            logGoal(); // Auch hier die Runden-Tabelle aktualisieren, damit die Historie der Tore korrekt bleibt
        }
    }

    // Eigene Funktion, um Tore für B abzuziehen
    function subGoalTeamB() as Void {
        if (scoreB > 0) { // Verhindert negative Tore
            scoreB--;
            if (fieldScoreB != null) {
                fieldScoreB.setData(scoreB);
            }
            logGoal(); // Auch hier die Runden-Tabelle aktualisieren, damit die Historie der Tore korrekt bleibt
        }
    }

    function pauseSession() as Void {
        if (session != null && session.isRecording()) {
            session.stop();
        }
    }

    function saveSession() as Void {
        if (session != null) {
            // Session erst pausieren, dann speichern
            if (session.isRecording()) {
                session.stop();
            }
            session.save();
            session = null; // Session aufräumen
            clearSavedState(); // Spiel regulär beendet -> nichts wiederherzustellen
            cleanupResources(); // Sensoren und GPS abschalten
        }
    }

    function discardSession() as Void {
        if (session != null) {
            // Session erst pausieren, dann verwerfen
            if (session.isRecording()) {
                session.stop();
            }
            session.discard();
            session = null; // Session aufräumen
            clearSavedState();
            cleanupResources(); // Sensoren und GPS abschalten
        }
    }

    // Hilfsfunktion, um Sensoren und GPS nach dem Spiel komplett schlafen zu legen
    private function cleanupResources() as Void {
        // GPS ausschalten (deaktiviert die Ortsbestimmung komplett)
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        gpsQuality = Position.QUALITY_NOT_AVAILABLE;
        
        // Sensor-Events abmelden (Callback auf null setzen löscht das Abo)
        Sensor.enableSensorEvents(null);
        Sensor.setEnabledSensors([]);
    }

    // Hilfsfunktion für die View (um z.B. ein "REC" Icon anzuzeigen)
    function isRecording() as Boolean {
        var s = session;
        return s != null && s.isRecording();
    }

    // Hilfsfunktion: Prüft, ob wir in echten Pause sind
    function isPaused() as Boolean {
        var s = session;
        return s != null && !s.isRecording();
    }

    // Setzt einen Runden-Marker (Lap) in der FIT-Datei
    function addLap() as Void {
        if (session != null && session.isRecording()) {
            session.addLap();
        }
    }

    function updateMetrics() as Void {
        var info = Activity.getActivityInfo();
        if (info != null) {
            // Heart Rate
            var hr = info.currentHeartRate;
            if (hr != null) {
                currentHR = hr;
            }
            // Distanz in km umrechnen (info.elapsedDistance ist in Metern)
            var dist = info.elapsedDistance;
            if (dist != null) {
                distanceKm = dist / 1000.0;
            }
            // Dauer der Aktivität in Minuten:Sekunden umrechnen
            var tTime = info.timerTime;
            if (tTime != null) {
                var timeInSeconds = tTime / 1000;
                var minutes = timeInSeconds / 60;
                var seconds = timeInSeconds % 60;
                activityTimeStr = minutes.format("%02d") + ":" + seconds.format("%02d");
            }
            // Aktuelle Geschwindigkeit in km/h
            var speed = info.currentSpeed;
            if (speed != null) {
                currentSpeedKmh = speed * 3.6; // m/s in km/h umrechnen
            } else {
                currentSpeedKmh = 0.0;
            }
            // Kalorienverbrauch
            var cal = info.calories;
            calories = (cal != null) ? cal : 0;

            // Werte für die HIT und Sprint-Funktionen auslesen
            var cad = info.currentCadence;
            currentCadence = (cad != null) ? cad : 0;
            // Nur in die Datei schreiben, wenn die Aufzeichnung aktiv läuft
            if (isRecording() && fieldCadence != null) {
                    fieldCadence.setData(currentCadence);
               
            }          
            if (isRecording()) {
                // HIT-Minuten berechnen
                processHiMinutes(tTime, currentHR);
                // Torwartwechsel-Countdown
                processGoalkeeperChange(tTime);
                // Sprints berechnen (nur outdoor), genau 1x pro Sekunde Spielzeit
                if (!isIndoor && tTime != null) {
                    var nowSec = tTime / 1000;
                    var elapsedSecs = nowSec - _lastSprintSec;
                    if (elapsedSecs < 0) {
                        elapsedSecs = 0; // Zeit wurde zurückgesetzt
                    } else if (elapsedSecs > MAX_SPRINT_CATCHUP_SECS) {
                        elapsedSecs = MAX_SPRINT_CATCHUP_SECS;
                    }
                    for (var i = 0; i < elapsedSecs; i++) {
                        processSprintLogic(currentSpeedKmh);
                    }
                    _lastSprintSec = nowSec;
                }
            }            
        }   
    }

    // --- Funktion für HIT-Minuten ---
    function processHiMinutes(timerTime as Number?, hr as Number) as Void {
        if (timerTime == null) { return; }
        if (hrZones.size() < 4) { return; } // Keine Zonen oder unvollständig
        
        // 1. Delta-Zeit seit dem letzten Aufruf berechnen
        var deltaMs = timerTime - _lastHiMinTimerTime;

        // Schutz gegen negative Werte (z.B. beim Zurücksetzen der Session)
        if (deltaMs > 0 && deltaMs < 5000) {
            // 2. Sind wir in der roten oder orangenen Zone? (hrZones[3] = Grenze zu Zone 4)
            if (hr > 0 && hr >= hrZones[3]) {
                // 3. Wenn ja, Delta-Zeit zum Akkumulator hinzufügen
                hiTimeAccumulatorMs += deltaMs;
                // 4. Vollendete Minuten berechnen
                var calculatedMinutes = hiTimeAccumulatorMs / 60000;
                // 5. Wenn wir eine neue volle Minute erreicht haben, in hiMinutes speichern und ins FIT-File schreiben
                if (calculatedMinutes > hiMinutes) {
                    hiMinutes = calculatedMinutes;
                    if (fieldHiMinutes != null) {
                        fieldHiMinutes.setData(hiMinutes);
                    }
                }
            }
        }
        // 6. Aktuelle Zeit als Referenz für den nächsten Aufruf speichern
        _lastHiMinTimerTime = timerTime;
    }

    // --- Funktion für den Torwartwechsel ---
    // Basiert auf der Aktivitätszeit (timerTime), läuft also bei Pause nicht weiter.
    // Gibt true zurück, wenn in diesem Aufruf ein Wechsel fällig wurde.
    function processGoalkeeperChange(timerTime as Number?) as Boolean {
        if (timerTime == null || gkIntervalMin <= 0) { return false; }

        var intervalMs = gkIntervalMin * 60000;
        var changed = false;

        // Falls die Zeit zurückgesetzt wurde (neue Session), Referenz neu setzen
        if (timerTime < _gkLastChangeMs) {
            _gkLastChangeMs = 0;
        }

        // Fällige Wechsel nachholen (Referenz um volle Intervalle verschieben -> kein Drift)
        while (timerTime - _gkLastChangeMs >= intervalMs) {
            _gkLastChangeMs += intervalMs;
            gkChangeCount++;
            changed = true;
        }

        if (changed) {
            gkAlertPending = true;
            saveState();
            _gkAlertUntilMs = timerTime + GK_ALERT_DURATION_MS;
            if (fieldGkChanges != null) {
                fieldGkChanges.setData(gkChangeCount);
            }
        }

        gkRemainingSec = (intervalMs - (timerTime - _gkLastChangeMs)) / 1000;
        _gkLastTimerTime = timerTime;
        return changed;
    }

    // Manuell bestätigter Torwartwechsel (DOWN lange gedrückt).
    // Der Countdown startet ab jetzt neu. Wurde der Wechsel gerade automatisch
    // angekündigt (Hinweis noch sichtbar), wird er nicht doppelt gezählt.
    function confirmGoalkeeperChange(timerTime as Number?) as Void {
        if (timerTime == null || gkIntervalMin <= 0) { return; }
        if (!isGkAlertActive()) {
            gkChangeCount++;
            if (fieldGkChanges != null) {
                fieldGkChanges.setData(gkChangeCount);
            }
        }
        _gkLastChangeMs = timerTime;
        _gkAlertUntilMs = 0;   // Hinweis ausblenden
        gkAlertPending = false;
        _gkLastTimerTime = timerTime;
        gkRemainingSec = gkIntervalMin * 60;
        saveState();
    }

    // Aktuelle Aktivitätszeit in ms (für den manuellen Wechsel)
    function getTimerTime() as Number? {
        var info = Activity.getActivityInfo();
        return (info != null) ? info.timerTime : null;
    }

    // Soll gerade der Hinweis "Torwartwechsel" angezeigt werden?
    function isGkAlertActive() as Boolean {
        return gkIntervalMin > 0 && gkChangeCount > 0 && _gkLastTimerTime < _gkAlertUntilMs;
    }

    // Restzeit als "m:ss"
    function getGkRemainingStr() as String {
        var sec = gkRemainingSec < 0 ? 0 : gkRemainingSec;
        return (sec / 60).toString() + ":" + (sec % 60).format("%02d");
    }

// --- Funktion für dynamische Sprints (mit Moving Average) ---
    function processSprintLogic(speedKmh as Float) as Void {
        
        // Zuerst den Ringpuffer aktualisieren
        var currentMovingAvg = updateMovingAverage(speedKmh);
        
        // DYNAMISCHE BEDINGUNG: 
        // 1. Absolute Mindestgeschwindigkeit erreicht? (z.B. 15.0 km/h)
        // 2. Sprint_Multiplier so schnell wie der Rhythmus der letzten 30 Sekunden?
        var isExplosiveEnough = (speedKmh >= MIN_SPEED_KMH) && (speedKmh > (SPRINT_MULTIPLIER * currentMovingAvg));

        if (isExplosiveEnough) {
            _sprintDurationSeconds++;
            
            if (_sprintDurationSeconds >= MIN_SPRINT_DURATION_SECS) {
                if (!_isCurrentlySprint) {
                    _isCurrentlySprint = true;
                    sprintCount++;
                    if (fieldSprintCount != null) {
                        fieldSprintCount.setData(sprintCount);
                    }
                }
            }
        } 
        // ABBRUCH: Unter die absolute Grenze oder zurück in den Rhythmus (< 110%)
        else if (speedKmh < MIN_SPEED_KMH || speedKmh < (SPRINT_CANCEL_FACTOR * currentMovingAvg)) {
            _isCurrentlySprint = false;
            _sprintDurationSeconds = 0;
        }
    }

// Berechnet den gleitenden Durchschnitt über eine Running Sum
    private function updateMovingAverage(currentSpeedKmh as Float) as Float {
        // 1. Den ganz alten Wert, der jetzt rausfliegt, von der Summe abziehen
        var oldestValue = _speedBuffer[_speedBufferIndex];
        _speedBufferSum -= oldestValue;
        
        // 2. Den neuen Wert in den Puffer schreiben
        _speedBuffer[_speedBufferIndex] = currentSpeedKmh;
        
        // 3. Den neuen Wert zur laufenden Summe addieren
        _speedBufferSum += currentSpeedKmh;
        
        // Index für die nächste Sekunde weiterrücken
        _speedBufferIndex = (_speedBufferIndex + 1) % SPEED_BUFFER_SIZE;
        
        // 4. Durchschnitt ist jetzt einfach: Summe geteilt durch 30
        _movingAvgSpeed = _speedBufferSum / SPEED_BUFFER_SIZE.toFloat();
        
        return _movingAvgSpeed;
    }

    // ---------------------------------------------------------------
    // Absturzschutz: Spielstand im Speicher der Uhr sichern
    // ---------------------------------------------------------------

    // Sichert den aktuellen Spielstand (nur während einer laufenden Session)
    function saveState() as Void {
        if (session == null) { return; }
        if (!(Toybox.Application has :Storage)) { return; }
        Application.Storage.setValue(STORAGE_KEY, {
            "a" => scoreA,
            "b" => scoreB,
            "gk" => gkChangeCount,
            "sp" => sprintCount,
            "hi" => hiMinutes,
            "ts" => Time.now().value()
        });
    }

    // Löscht den gesicherten Spielstand
    function clearSavedState() as Void {
        if (Toybox.Application has :Storage) {
            Application.Storage.deleteValue(STORAGE_KEY);
        }
    }

    // Liefert einen gesicherten Spielstand, wenn er jünger als 3 Stunden ist, sonst null
    function getRecoverableState() as Dictionary? {
        if (!(Toybox.Application has :Storage)) { return null; }
        var state = Application.Storage.getValue(STORAGE_KEY);
        if (!(state instanceof Lang.Dictionary)) { return null; }
        state = state as Dictionary;
        var ts = state.get("ts");
        if (!(ts instanceof Lang.Number) || Time.now().value() - ts > RECOVERY_MAX_AGE_SECS) {
            clearSavedState();
            return null;
        }
        return state;
    }

    // Übernimmt einen gesicherten Spielstand (vor dem Start der neuen Session)
    function restoreState(state as Dictionary) as Void {
        scoreA = readNumber(state, "a");
        scoreB = readNumber(state, "b");
        gkChangeCount = readNumber(state, "gk");
        sprintCount = readNumber(state, "sp");
        hiMinutes = readNumber(state, "hi");
        hiTimeAccumulatorMs = hiMinutes * 60000;
    }

    // Liest einen nicht-negativen Zahlenwert aus dem gesicherten Spielstand (sonst 0)
    function readNumber(state as Dictionary, key as String) as Number {
        var value = state.get(key);
        if (value instanceof Lang.Number && value >= 0) {
            return value;
        }
        return 0;
    }

    // Wird beim Beenden der App aufgerufen (Akku, Systemabbruch, ...):
    // Eine laufende oder pausierte Aufnahme speichern statt sie zu verlieren.
    // Der Spielstand bleibt im Speicher, damit er beim nächsten Start angeboten wird.
    function emergencySave() as Void {
        var s = session;
        if (s != null) {
            saveState();
            if (s.isRecording()) {
                s.stop();
            }
            s.save();
            session = null;
            cleanupResources();
        }
    }

    // Funktion ermittelt die Farbe anhand des aktuellen Pulses
    function getHrColor() as Graphics.ColorType {
        if (hrZones.size() < 5) {
            return Graphics.COLOR_WHITE; // Keine oder unvollständige Zonen
        }
        if (currentHR == 0) {
            return Graphics.COLOR_WHITE; // Kein Puls = Weiß
        }
        
        // hrZones[1] ist die Obergrenze von Zone 1, etc.
        if (currentHR < hrZones[1]) { return Graphics.COLOR_LT_GRAY; } // Zone 1
        if (currentHR < hrZones[2]) { return Graphics.COLOR_BLUE; }    // Zone 2
        if (currentHR < hrZones[3]) { return Graphics.COLOR_GREEN; }   // Zone 3
        if (currentHR < hrZones[4]) { return Graphics.COLOR_ORANGE; }  // Zone 4
        
        return Graphics.COLOR_RED; // Zone 5
    }
}