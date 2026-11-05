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
import Toybox.Lang;

class SoccerSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _model as SoccerModel;
    // Auswählbare Intervalle für den Torwartwechsel in Minuten (0 = aus)
    private var GK_OPTIONS as Array<Number> = [0, 3, 4, 5, 6, 7, 8, 10] as Array<Number>;

    function initialize(model as SoccerModel) {
        Menu2InputDelegate.initialize();
        _model = model;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        // Prüfen, ob der Indoor-Schalter geklickt wurde
        var itemId = item.getId();
        if (itemId == :toggle_indoor) {
            // Der Schalter wurde betätigt, den neuen Zustand auslesen
            var toggleItem = item as WatchUi.ToggleMenuItem;
            // Zustand (true/false) aus dem Schalter auslesen und im Model speichern
            _model.isIndoor = toggleItem.isEnabled();
            // Einstellung in den Properties speichern, damit sie auch nach einem Neustart erhalten bleibt
            Application.Properties.setValue("is_indoor", _model.isIndoor);
            // GPS sofort passend ein-/ausschalten
            _model.updateGpsMode();
        } else if (itemId == :gk_interval) {
            // Zum nächsten Intervall-Wert springen (0 = aus)
            var idx = 0;
            for (var i = 0; i < GK_OPTIONS.size(); i++) {
                if (GK_OPTIONS[i] == _model.gkIntervalMin) { idx = i; break; }
            }
            var newValue = GK_OPTIONS[(idx + 1) % GK_OPTIONS.size()];
            _model.gkIntervalMin = newValue;
            _model.gkRemainingSec = newValue * 60;
            Application.Properties.setValue("gk_interval", newValue);
            item.setSubLabel(SoccerSettingsMenuDelegate.gkIntervalSubLabel(newValue));
            WatchUi.requestUpdate();
        }
    }

    // Untertitel für den Menüpunkt, z.B. "5 min" oder "Aus"
    static function gkIntervalSubLabel(minutes as Number) as String {
        if (minutes <= 0) {
            return (WatchUi.loadResource($.Rez.Strings.GkOff) as String);
        }
        return minutes.toString() + " " + (WatchUi.loadResource($.Rez.Strings.GkMinUnit) as String);
    }
}