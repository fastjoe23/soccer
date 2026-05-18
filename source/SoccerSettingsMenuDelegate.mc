import Toybox.WatchUi;

class SoccerSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    var _model;

    function initialize(model) {
        Menu2InputDelegate.initialize();
        _model = model;
    }

    function onSelect(item) {
        // Prüfen, ob der Indoor-Schalter geklickt wurde
        if (item.getId().equals("toggle_indoor")) {
            // Der Schalter wurde betätigt, den neuen Zustand auslesen
            var toggleItem = item as WatchUi.ToggleMenuItem;
            // Zustand (true/false) aus dem Schalter auslesen und im Model speichern
            _model.isIndoor = toggleItem.isEnabled();
            // Einstellung in den Properties speichern, damit sie auch nach einem Neustart erhalten bleibt
            Application.Properties.setValue("is_indoor", _model.isIndoor);
        }
    }
}