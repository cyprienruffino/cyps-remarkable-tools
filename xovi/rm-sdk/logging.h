#ifndef RMSDK_LOGGING_H
#define RMSDK_LOGGING_H

#include <QLoggingCategory>
#include <QObject>

// Switches Qt logging categories on and off while xochitl runs, e.g. to see
// xochitl's own debug messages, which are compiled in but off by default:
//   import RmSdk
//   Logging.setFilterRules("rm.peninput.debug=true")
// The rules replace any set before.
class Logging : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    Q_INVOKABLE void setFilterRules(const QString &rules) const { QLoggingCategory::setFilterRules(rules); }
};

#endif
