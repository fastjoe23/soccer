import Toybox.WatchUi;
import Toybox.System;
import Toybox.Timer;

class SoccerDelegate extends WatchUi.BehaviorDelegate {

    private var _model as SoccerModel;
    
    // Timer und Zähler für Team A (START-Taste)
    private var _timerA as Timer.Timer;
    private var _clickCountA = 0;
    
    // Timer und Zähler für Team B (BACK-Taste)
    private var _timerB as Timer.Timer;
    private var _clickCountB = 0;
    
    // Das Zeitfenster, in dem der zweite Klick passieren muss
    private const DOUBLE_CLICK_DELAY = 350;

    public function initialize(model as SoccerModel) {
        BehaviorDelegate.initialize();
        _model = model;
        _timerA = new Timer.Timer();
        _timerB = new Timer.Timer();
    }

// --- RECHTS OBEN: START-TASTE (Team A) ---
    function onSelect() {
        if (_model.isRecording() && _model.currentPage == SoccerModel.PAGE_SCOREBOARD) {
            _clickCountA++;
            
            if (_clickCountA == 1) {
                // Erster Klick: Timer starten. false bedeutet: nur einmalig ausführen
                _timerA.start(method(:executeSingleClickA), DOUBLE_CLICK_DELAY, false);
            } else if (_clickCountA == 2) {
                // Zweiter Klick kam rechtzeitig an!
                _timerA.stop(); // Geplanten einfachen Klick abbrechen
                _clickCountA = 0; // Zähler zurücksetzen
                
                _model.subGoalTeamA(); // Direkt abziehen
                vibrateDouble(); // Spezifisches Feedback für "Minus"
                WatchUi.requestUpdate();
            }
            return true;
        } 
        else if (_model.isRecording()) {
            // Auf anderen Seiten: Normales Pause-Menü
            openPauseMenu();
            return true;
        } else {
            // Spiel starten
            _model.startSession();
            vibrate();
            WatchUi.requestUpdate();
            return true;
        }
    }

    // Callback, wenn der Timer für A abgelaufen ist (Einfacher Klick)
    function executeSingleClickA() as Void {
        _clickCountA = 0; // Zähler wieder nullen
        _model.addGoalTeamA();
        vibrate();
        WatchUi.requestUpdate();
    }

    // Pause-Menü öffnen
    private function openPauseMenu() {
        _timerA.stop(); // Sicherstellen, dass kein Klick mehr ausgeführt wird
        _timerB.stop();
        // Strings aus Resourcen laden
        var title = WatchUi.loadResource($.Rez.Strings.MenuPauseTitle);
        var continueLabel = WatchUi.loadResource($.Rez.Strings.MenuResume);
        var saveLabel = WatchUi.loadResource($.Rez.Strings.MenuSave);
        var discardLabel = WatchUi.loadResource($.Rez.Strings.MenuDiscard);
        var menu = new WatchUi.Menu2({:title=>title});
        menu.addItem(new WatchUi.MenuItem(continueLabel, null, :resume, null));
        menu.addItem(new WatchUi.MenuItem(saveLabel, null, :save, null));
        menu.addItem(new WatchUi.MenuItem(discardLabel, null, :discard, null));
        WatchUi.pushView(menu, new SaveMenuDelegate(_model), WatchUi.SLIDE_UP);
        vibrate();
    }

    // --- RECHTS UNTEN: BACK-TASTE (Team B) ---
    function onBack() {
        if (_model.currentPage == SoccerModel.PAGE_SCOREBOARD) {
            _clickCountB++;
            
            if (_clickCountB == 1) {
                _timerB.start(method(:executeSingleClickB), DOUBLE_CLICK_DELAY, false);
            } else if (_clickCountB == 2) {
                _timerB.stop();
                _clickCountB = 0;
                
                _model.subGoalTeamB();
                vibrateDouble(); // Spezifisches Feedback für "Minus"
                WatchUi.requestUpdate();
            }
            return true;
        }

        if (_model.isRecording()) {
            return true; // Schützt vor dem Schließen der App
        }
        return false;
    }

    // Callback, wenn der Timer für B abgelaufen ist (Einfacher Klick)
    function executeSingleClickB() as Void {
        _clickCountB = 0;
        _model.addGoalTeamB();
        vibrate();
        WatchUi.requestUpdate();
    }


    // Standard-Vibration (Einmal kurz für "+1")
    function vibrate() {
        if (Toybox has :Attention) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(50, 150)]);
        }
    }

    // Doppel-Vibration (Zweimal kurz für "-1")
    function vibrateDouble() {
        if (Toybox has :Attention) {
            Toybox.Attention.vibrate([
                new Toybox.Attention.VibeProfile(50, 100),
                new Toybox.Attention.VibeProfile(0, 100),  // Pause
                new Toybox.Attention.VibeProfile(50, 100)
            ]);
        }
    }

    // --- SEITENWECHSEL (Standard-Verhalten) ---
    function onNextPage() {
        _timerA.stop(); // Sicherstellen, dass kein Klick mehr ausgeführt wird
        _timerB.stop();
        _model.currentPage = (_model.currentPage + 1) % _model.maxPages;
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        _timerA.stop(); // Sicherstellen, dass kein Klick mehr ausgeführt wird
        _timerB.stop();
        _model.currentPage = (_model.currentPage - 1 + _model.maxPages) % _model.maxPages;
        WatchUi.requestUpdate();
        return true;
    }

    // Menu: Wird bei langem Druck auf die UP-Taste aufgerufen
    function onMenu() {
        _timerA.stop(); // Sicherstellen, dass kein Klick mehr ausgeführt wird
        _timerB.stop();
        // Einstellungen nur erlauben, wenn noch nicht aufgezeichnet wird
        if (!_model.isRecording()) {
            var settingsTitle = WatchUi.loadResource($.Rez.Strings.MenuSettingsTitle);
            var menu = new WatchUi.Menu2({:title=>settingsTitle});
            menu.addItem(
                new WatchUi.ToggleMenuItem(
                    WatchUi.loadResource($.Rez.Strings.IndoorMode), 
                    {
                        :enabled=>WatchUi.loadResource($.Rez.Strings.IndoorEnabled), 
                        :disabled=>WatchUi.loadResource($.Rez.Strings.IndoorDisabled)
                    }, 
                    "toggle_indoor", 
                    _model.isIndoor, 
                    null
                )
            );
            
            // Menü anzeigen und unseren neuen Delegate übergeben
            WatchUi.pushView(menu, new $.SoccerSettingsMenuDelegate(_model), WatchUi.SLIDE_UP);
        }
        return true;
    }
    


}