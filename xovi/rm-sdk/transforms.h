#ifndef RMSDK_TRANSFORMS_H
#define RMSDK_TRANSFORMS_H

#include <QObject>
#include <QTransform>

// QTransform values for QML, which can't create them, e.g. to map the pen
// with xochitl's PenInputSurface.setTransform(). In QML:
//   import RmSdk
//   surface.setTransform(Transforms.identity())
class Transforms : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    Q_INVOKABLE QTransform identity() const { return QTransform(); }
    Q_INVOKABLE QTransform fromValues(qreal m11, qreal m12, qreal m21, qreal m22, qreal dx, qreal dy) const
    {
        return QTransform(m11, m12, m21, m22, dx, dy);
    }
    Q_INVOKABLE QString describe(const QTransform &transform) const
    {
        return QStringLiteral("QTransform(%1, %2, %3, %4, %5, %6)")
            .arg(transform.m11()).arg(transform.m12()).arg(transform.m21())
            .arg(transform.m22()).arg(transform.dx()).arg(transform.dy());
    }
};

#endif
