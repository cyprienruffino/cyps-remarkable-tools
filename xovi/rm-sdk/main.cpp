// rm-sdk: a xovi extension adding helpers to xochitl's QML, for AppLoad apps.
#include "transforms.h"

#include <QQmlEngine>
#include <cstdio>

extern "C" void _xovi_construct()
{
    qmlRegisterSingletonType<Transforms>("RmSdk", 1, 0, "Transforms",
        [](QQmlEngine *, QJSEngine *) -> QObject * { return new Transforms; });
    std::fprintf(stderr, "[rm-sdk]: Extension loaded\n");
}
