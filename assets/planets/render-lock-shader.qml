// Фони hyprlock для Сонця й поясу астероїдів (lock/sun.jpg, lock/belt.jpg). У них немає
// текстур -- їх малює шейдер ETEA (shaders/planet.frag, kind 1 і 2), тож рендеримо саме ним,
// а не переписуємо шум у numpy, як render-lock.py для планет. Кадр той самий: 2560x1440,
// центр 0.55/0.52, сонце з того ж боку (sunLat 0.2233 = SUN з render-lock.py).
//
// Потрібен справжній GPU-екран (offscreen дає білий кадр), напр. headless sway:
//   WLR_BACKENDS=headless sway -c <конфіг: "output HEADLESS-1 resolution 2560x1440",
//     "default_border none", "for_window [app_id=".*"] fullscreen enable" -- інакше рамка
//     sway з'їдає кілька пікселів і кадр виходить 2556x1413> &
//   WAYLAND_DISPLAY=wayland-N QT_QPA_PLATFORM=wayland \
//     qml render-lock-shader.qml -- <ETEA>/shaders/planet.frag.qsb assets/planets/lock sun
// (те саме з "belt"; QML_IMPORT_PATH / QT_PLUGIN_PATH -- з qt6.qtdeclarative, qtbase, qtwayland).
import QtQuick
import QtQuick.Window

Window {
    id: win

    readonly property var args: Qt.application.arguments.slice(-3)
    readonly property string body: args[2]
    readonly property var spec: ({
            sun: { kind: 1, size: 0.31, tilt: 0.13, rim: "#f0b45a", spin: 1.3 },
            belt: { kind: 2, size: 0.15, tilt: 0.07, rim: "#c2b8aa", spin: 0.6 }
        })[body]

    width: 2560
    height: 1440
    visible: true
    color: "#020304"

    Image {
        id: dummy
        visible: false
        source: Qt.resolvedUrl("2k_saturn_ring_alpha.png")
    }

    component Layer: ShaderEffect {
        anchors.fill: parent
        property vector2d resolution: Qt.vector2d(width, height)
        property vector2d centre: Qt.vector2d(width * 0.55, height * 0.52)
        property real radius: height * win.spec.size
        property real spin: win.spec.spin
        property real tilt: win.spec.tilt
        property real hasRing: 0
        property real hasClouds: 0
        property var cloudMap: dummy
        property real mode: 1
        property real drift: 0
        property real sunLat: 0.2233
        property color rim: win.spec.rim
        property var surface: dummy
        property var ringMap: dummy
        property real kind: win.spec.kind
        fragmentShader: "file://" + win.args[0]
    }

    // Зорі (mode 0), потім тіло з прозорим тлом -- як на робочому столі
    Layer {
        mode: 0
        kind: 0
    }
    Layer {}

    Timer {
        interval: 1500
        running: true
        onTriggered: win.contentItem.grabToImage(r => {
                r.saveToFile(win.args[1] + "/" + win.body + ".jpg");
                Qt.quit();
            })
    }
}
