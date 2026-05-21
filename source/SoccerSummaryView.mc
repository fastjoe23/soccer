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
import Toybox.Graphics;
import Toybox.Lang;

class SoccerSummaryView extends WatchUi.View {
    private var _model as SoccerModel;

    function initialize(model as SoccerModel) {
        View.initialize();
        _model = model;
    }

    function onUpdate(dc as Dc) as Void {
        // Hintergrund schwarz
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var cy = height / 2;

        // Titel
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var title = WatchUi.loadResource($.Rez.Strings.SummaryTitle);
        dc.drawText(cx, height * 0.15, Graphics.FONT_SMALL, title, Graphics.TEXT_JUSTIFY_CENTER);


        // Der finale Score (Ganz groß)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var finalScore = _model.scoreA.toString() + " : " + _model.scoreB.toString();
        dc.drawText(cx, cy - 10, Graphics.FONT_NUMBER_HOT, finalScore, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Statistiken darunter
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 50, Graphics.FONT_TINY, _model.distanceKm.format("%.2f") + " km  |  " + _model.activityTimeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Hinweis zum Beenden ganz unten
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width-35, height * 0.25, Graphics.FONT_TINY, "X", Graphics.TEXT_JUSTIFY_CENTER);
    }
}