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
import Toybox.Application;

class SoccerSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    var _model;

    function initialize(model) {
        Menu2InputDelegate.initialize();
        _model = model;
    }

    function onSelect(item) {
        // Prüfen, ob der Indoor-Schalter geklickt wurde
        var itemId = item.getId();
        if (itemId == :toggle_indoor) {
            // Der Schalter wurde betätigt, den neuen Zustand auslesen
            var toggleItem = item as WatchUi.ToggleMenuItem;
            // Zustand (true/false) aus dem Schalter auslesen und im Model speichern
            _model.isIndoor = toggleItem.isEnabled();
            // Einstellung in den Properties speichern, damit sie auch nach einem Neustart erhalten bleibt
            Application.Properties.setValue("is_indoor", _model.isIndoor);
        }
    }
}