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

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SoccerApp extends Application.AppBase {

    private var _model as SoccerModel;

    public function initialize() {
        AppBase.initialize();
        _model = new SoccerModel(); // Modell instanziieren
    }

    public function onStart(state as Dictionary?) as Void {
    }

    public function getInitialView() as [Views] or [Views, InputDelegates] {
        // Modell an View und Delegate übergeben
        return [new $.SoccerView(_model), new $.SoccerDelegate(_model)];
    }

    public function onStop(state as Dictionary?) as Void {
    }
}