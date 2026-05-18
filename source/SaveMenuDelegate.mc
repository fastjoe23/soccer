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