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