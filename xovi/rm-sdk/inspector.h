#ifndef RMSDK_INSPECTOR_H
#define RMSDK_INSPECTOR_H

#include <QMetaMethod>
#include <QMetaObject>
#include <QMetaProperty>
#include <QObject>
#include <QStringList>

// Describes any QObject from QML, using Qt's own metadata: its classes, and
// their properties, methods and signals with full signatures. For finding out
// how xochitl's own types work:
//   import RmSdk
//   console.log(Inspector.describe(someItem))
class Inspector : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    Q_INVOKABLE QString describe(QObject *object) const
    {
        if (!object) {
            return QStringLiteral("null");
        }
        QStringList lines;
        for (const QMetaObject *meta = object->metaObject(); meta; meta = meta->superClass()) {
            const QString className = QString::fromLatin1(meta->className());
            if (className == QLatin1String("QObject")) {
                break;
            }
            lines << QStringLiteral("class %1").arg(className);
            for (int i = meta->propertyOffset(); i < meta->propertyCount(); i++) {
                const QMetaProperty property = meta->property(i);
                lines << QStringLiteral("  property %1 %2%3").arg(QString::fromLatin1(property.typeName()),
                    QString::fromLatin1(property.name()), property.isWritable() ? QString() : QStringLiteral(" (read-only)"));
            }
            for (int i = meta->methodOffset(); i < meta->methodCount(); i++) {
                const QMetaMethod method = meta->method(i);
                const char *kind = method.methodType() == QMetaMethod::Signal ? "signal"
                    : method.methodType() == QMetaMethod::Slot ? "slot" : "method";
                lines << QStringLiteral("  %1 %2 %3").arg(QString::fromLatin1(kind),
                    QString::fromLatin1(method.typeName()), QString::fromLatin1(method.methodSignature()));
            }
        }
        return lines.join(QLatin1Char('\n'));
    }
};

#endif
