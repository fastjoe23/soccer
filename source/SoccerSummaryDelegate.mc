import Toybox.WatchUi;
// Der Delegate für die Summary: Er wartet nur auf den finalen Tastendruck
class SoccerSummaryDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() {
        System.exit(); // Beendet die App endgültig
  
    }

    function onBack() {
        System.exit(); // Auch über Back beenden

    }
}