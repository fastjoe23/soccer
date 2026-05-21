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
import Toybox.System;

class SaveMenuDelegate extends WatchUi.Menu2InputDelegate {
    var _model;

    function initialize(model) {
        Menu2InputDelegate.initialize();
        _model = model;
    }

    function onSelect(item) {
        var id = item.getId();
        
        if (id == :resume) {
            // Weiter
            _model.startSession();
            WatchUi.popView(WatchUi.SLIDE_DOWN); // Menü schließen
            
        } else if (id == :save) {
            // 1. Session im Modell speichern
            _model.saveSession();
            
            // 2. Das Pause-Menü vom Stack entfernen
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            
            // 3. Zur Summary-View wechseln (statt die App direkt zu killen)
            WatchUi.switchToView(
                new SoccerSummaryView(_model), 
                new SoccerSummaryDelegate(), 
                WatchUi.SLIDE_UP
            ); 
            
        } else if (id == :discard) {
            // Verwerfen
            _model.discardSession();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            // App beenden
            System.exit(); 
        }
    }
}