// Stand-in for xochitl's ScreenModeItem, which picks the e-ink refresh mode
// for the area it covers (Pen being the fast, low latency one used for ink).
// On a PC it does nothing.
import QtQuick

Item {
    enum Mode { Content, Animation, Mono, Overlay, Pen, Sleep, UI }
    property int mode: ScreenModeItem.Content
}
