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