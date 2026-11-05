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

import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

class SoccerDelegate extends WatchUi.BehaviorDelegate {

    private var _model as SoccerModel;
    
    // Timer und Zähler für Team A (START-Taste)
    private var _timerA as Timer.Timer;
    private var _clickCountA as Number = 0;
    
    // Timer und Zähler für Team B (BACK-Taste)
    private var _timerB as Timer.Timer;
    private var _clickCountB as Number = 0;
    
    // Das Zeitfenster, in dem der zweite Klick passieren muss
    private const DOUBLE_CLICK_DELAY = 350;

    // --- Torwartwechsel: DOWN-Taste lange gedrückt halten (nur Scoreboard) ---
    private var _holdTimer as Timer.Timer;
    private var _downHeld as Boolean = false;      // DOWN wird gerade auf dem Scoreboard gehalten
    private var _holdFired as Boolean = false;     // Langer Druck wurde bereits ausgelöst
    private const GK_HOLD_DELAY = 800;  // ms bis der lange Druck zählt

    public function initialize(model as SoccerModel) {
        BehaviorDelegate.initialize();
        _model = model;
        _timerA = new Timer.Timer();
        _timerB = new Timer.Timer();
        _holdTimer = new Timer.Timer();
    }

    // Taste gedrückt: Auf dem Scoreboard startet DOWN den Halte-Timer.
    // Der Seitenwechsel wird bis zum Loslassen zurückgestellt.
    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_DOWN && isGkHoldAvailable()) {
            _downHeld = true;
            _holdFired = false;
            _holdTimer.start(method(:onGkHoldTimer), GK_HOLD_DELAY, false);
            return true;
        }
        return false;
    }

    // Verhindert, dass DOWN beim Drücken sofort die Seite wechselt, solange wir halten
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_DOWN && _downHeld) {
            return true;
        }
        return BehaviorDelegate.onKey(keyEvent);
    }

    // Taste losgelassen: kurzer Druck -> normaler Seitenwechsel, langer Druck -> nichts weiter
    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_DOWN && _downHeld) {
            _holdTimer.stop();
            _downHeld = false;
            if (!_holdFired) {
                changePage(1);
            }
            _holdFired = false;
            return true;
        }
        return false;
    }

    // Wenn ein Einzelklick noch auf das Doppelklick-Fenster wartet, wird er sofort
    // ausgeführt. Vorher wurde er beim Seitenwechsel verworfen -> Tor ging verloren.
    private function flushPendingClicks() as Void {
        _timerA.stop();
        _timerB.stop();
        if (_clickCountA == 1) {
            executeSingleClickA();
        }
        if (_clickCountB == 1) {
            executeSingleClickB();
        }
        _clickCountA = 0;
        _clickCountB = 0;
    }

    // Halte-Timer abgelaufen -> Torwartwechsel bestätigen
    function onGkHoldTimer() as Void {
        if (!_downHeld) { return; }
        _holdFired = true;
        _model.confirmGoalkeeperChange(_model.getTimerTime());
        vibrateGkConfirm();
        WatchUi.requestUpdate();
    }

    // Langer Druck nur auf dem Scoreboard, während der Aufnahme und wenn der Wechsel aktiv ist
    private function isGkHoldAvailable() as Boolean {
        return _model.currentPage == SoccerModel.PAGE_SCOREBOARD
            && _model.isRecording()
            && _model.gkIntervalMin > 0;
    }

    // Eine lange Vibration als Bestätigung für den manuellen Wechsel
    function vibrateGkConfirm() as Void {
        if (Toybox has :Attention) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(100, 500)]);
        }
    }

// --- RECHTS OBEN: START-TASTE (Team A) ---
    function onSelect() as Boolean {
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
    private function openPauseMenu() as Void {
        flushPendingClicks(); // Wartende Einzelklicks sofort als Tor zählen statt sie zu verwerfen
        // Session pausieren 
        _model.pauseSession();

        // Strings aus Resourcen laden
        var title = (WatchUi.loadResource($.Rez.Strings.MenuPauseTitle) as String);
        var continueLabel = (WatchUi.loadResource($.Rez.Strings.MenuResume) as String);
        var saveLabel = (WatchUi.loadResource($.Rez.Strings.MenuSave) as String);
        var discardLabel = (WatchUi.loadResource($.Rez.Strings.MenuDiscard) as String);
        var menu = new WatchUi.Menu2({:title=>title});
        menu.addItem(new WatchUi.MenuItem(continueLabel, null, :resume, null));
        menu.addItem(new WatchUi.MenuItem(saveLabel, null, :save, null));
        menu.addItem(new WatchUi.MenuItem(discardLabel, null, :discard, null));
        WatchUi.pushView(menu, new SaveMenuDelegate(_model), WatchUi.SLIDE_UP);
        vibrate();
    }

    // --- RECHTS UNTEN: BACK-TASTE (Team B) ---
    function onBack() as Boolean {
        // Tore nur während einer laufenden Aufnahme zählen (wie bei der START-Taste)
        if (_model.isRecording() && _model.currentPage == SoccerModel.PAGE_SCOREBOARD) {
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
    function vibrate() as Void {
        if (Toybox has :Attention) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(50, 150)]);
        }
    }

    // Doppel-Vibration (Zweimal kurz für "-1")
    function vibrateDouble() as Void {
        if (Toybox has :Attention) {
            Toybox.Attention.vibrate([
                new Toybox.Attention.VibeProfile(50, 100),
                new Toybox.Attention.VibeProfile(0, 100),  // Pause
                new Toybox.Attention.VibeProfile(50, 100)
            ]);
        }
    }

    // --- SEITENWECHSEL (Standard-Verhalten) ---
    function onNextPage() as Boolean {
        // DOWN wird gerade gehalten -> Seitenwechsel erst beim Loslassen (siehe onKeyReleased)
        if (_downHeld) {
            return true;
        }
        changePage(1);
        return true;
    }

    // Gemeinsame Logik für den Seitenwechsel vorwärts
    private function changePage(direction as Number) as Void {
        flushPendingClicks(); // Wartende Einzelklicks sofort als Tor zählen statt sie zu verwerfen

        var nextPage = (_model.currentPage + direction) % _model.maxPages;
    
        // Wenn wir Indoor sind und die nächste Seite die Performance-Seite (1) wäre:
        // Springe direkt weiter zur nächsten Seite!
        if (_model.isIndoor && nextPage == SoccerModel.PAGE_PERFORMANCE) {
            nextPage = (nextPage + 1) % _model.maxPages;
        }
        
        _model.currentPage = nextPage;
        
        WatchUi.requestUpdate();
    }

    function onPreviousPage() as Boolean {
        flushPendingClicks(); // Wartende Einzelklicks sofort als Tor zählen statt sie zu verwerfen
        var prevPage = (_model.currentPage - 1 + _model.maxPages) % _model.maxPages;
    
        // Dynamisches Überspringen rückwärts: Wenn Indoor und die vorherige Seite die Performance-Seite ist,
        // gehen wir einfach noch einen Schritt weiter rückwärts (-1)
        if (_model.isIndoor && prevPage == SoccerModel.PAGE_PERFORMANCE) {
            prevPage = (prevPage - 1 + _model.maxPages) % _model.maxPages;
        }
        
        _model.currentPage = prevPage;
        WatchUi.requestUpdate();
        return true;
    }

    // Menu: Wird bei langem Druck auf die UP-Taste aufgerufen
    function onMenu() as Boolean {
        flushPendingClicks(); // Wartende Einzelklicks sofort als Tor zählen statt sie zu verwerfen
        // Einstellungen nur erlauben, wenn noch nicht aufgezeichnet wird
        if (!_model.isRecording()) {
            var settingsTitle = (WatchUi.loadResource($.Rez.Strings.MenuSettingsTitle) as String);
            var menu = new WatchUi.Menu2({:title=>settingsTitle});
            menu.addItem(
                new WatchUi.ToggleMenuItem(
                    (WatchUi.loadResource($.Rez.Strings.IndoorMode) as String), 
                    {
                        :enabled=>(WatchUi.loadResource($.Rez.Strings.IndoorEnabled) as String), 
                        :disabled=>(WatchUi.loadResource($.Rez.Strings.IndoorDisabled) as String)
                    }, 
                    :toggle_indoor, 
                    _model.isIndoor, 
                    null
                )
            );
            
            // Torwartwechsel-Intervall (Auswahl durch wiederholtes Antippen)
            menu.addItem(
                new WatchUi.MenuItem(
                    (WatchUi.loadResource($.Rez.Strings.GkIntervalTitle) as String),
                    $.SoccerSettingsMenuDelegate.gkIntervalSubLabel(_model.gkIntervalMin),
                    :gk_interval,
                    null
                )
            );

            // Menü anzeigen und unseren neuen Delegate übergeben
            WatchUi.pushView(menu, new $.SoccerSettingsMenuDelegate(_model), WatchUi.SLIDE_UP);
        }
        return true;
    }
    


}