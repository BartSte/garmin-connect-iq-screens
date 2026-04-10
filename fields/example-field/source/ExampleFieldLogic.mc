import Toybox.Lang;

module ExampleFieldLogic {

    function speedToKph(speed as Lang.Object or Null) as Float {
        if (speed == null) {
            return 0.0f;
        }
        if (speed instanceof Lang.Float) {
            return (speed as Lang.Float) * 3.6f;
        }
        if (speed instanceof Lang.Double) {
            return (speed as Lang.Double).toFloat() * 3.6f;
        }
        if (speed instanceof Lang.Long) {
            return (speed as Lang.Long).toFloat() * 3.6f;
        }
        if (speed instanceof Lang.Number) {
            return (speed as Lang.Number).toFloat() * 3.6f;
        }
        return 0.0f;
    }
}
