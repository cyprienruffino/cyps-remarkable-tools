// rm-sdk: a xovi extension adding helpers to xochitl's QML, for AppLoad apps.
#include "inspector.h"
#include "logging.h"
#include "transforms.h"

#include <QQmlEngine>
#include <cstdio>

extern "C" void _xovi_construct()
{
    qmlRegisterSingletonType<Transforms>("RmSdk", 1, 0, "Transforms",
        [](QQmlEngine *, QJSEngine *) -> QObject * { return new Transforms; });
    qmlRegisterSingletonType<Inspector>("RmSdk", 1, 0, "Inspector",
        [](QQmlEngine *, QJSEngine *) -> QObject * { return new Inspector; });
    qmlRegisterSingletonType<Logging>("RmSdk", 1, 0, "Logging",
        [](QQmlEngine *, QJSEngine *) -> QObject * { return new Logging; });
    std::fprintf(stderr, "[rm-sdk]: Extension loaded\n");
}
