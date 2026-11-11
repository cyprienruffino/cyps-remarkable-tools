// appload-run: runs an AppLoad application on a PC, with its real backend.
//
// Stands in for AppLoad inside xochitl: provides the net.asivery.AppLoad QML
// module, starts backend/entry with a SOCK_SEQPACKET socket and relays
// messages between it and the frontend, using the same protocol.

#include <QCommandLineParser>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMouseEvent>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QResource>
#include <QSocketNotifier>
#include <QTimer>

#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include <vector>

namespace {

constexpr int MSG_TERMINATE = -1;
constexpr int MSG_NEW_FRONTEND = -2;
constexpr int MAX_MESSAGE_LENGTH = 10485760;

struct Header
{
    int type;
    int length;
};

class AppLoadEndpoint;

// The backend process and its socket; one per application, like in AppLoad
class Backend : public QObject
{
    Q_OBJECT
public:
    static Backend *instance()
    {
        static Backend backend;
        return &backend;
    }

    bool start(const QString &appDir, const QString &appId)
    {
        m_socketPath = QDir::temp().filePath("appload-run-" + appId + ".sock");
        const QByteArray path = m_socketPath.toLocal8Bit();
        unlink(path.constData());

        m_listenFd = socket(AF_UNIX, SOCK_SEQPACKET, 0);
        sockaddr_un address = {};
        address.sun_family = AF_UNIX;
        strncpy(address.sun_path, path.constData(), sizeof address.sun_path - 1);
        if (m_listenFd == -1 || bind(m_listenFd, reinterpret_cast<sockaddr *>(&address), sizeof address) != 0 || listen(m_listenFd, 1) != 0) {
            qWarning("appload-run: can't listen on %s: %s", path.constData(), strerror(errno));
            return false;
        }
        auto *notifier = new QSocketNotifier(m_listenFd, QSocketNotifier::Read, this);
        connect(notifier, &QSocketNotifier::activated, this, &Backend::accept);

        m_process.setWorkingDirectory(appDir);
        m_process.setProcessChannelMode(QProcess::ForwardedChannels);
        connect(&m_process, &QProcess::finished, this, [](int code) {
            qInfo("appload-run: backend exited with code %d", code);
        });
        m_process.start(QDir(appDir).filePath("backend/entry"), { m_socketPath });
        if (!m_process.waitForStarted()) {
            qWarning("appload-run: can't start backend/entry: %s", qPrintable(m_process.errorString()));
            return false;
        }
        return true;
    }

    void addEndpoint(AppLoadEndpoint *endpoint)
    {
        m_endpoints.push_back(endpoint);
        announceFrontends();
    }

    void removeEndpoint(AppLoadEndpoint *endpoint)
    {
        std::erase(m_endpoints, endpoint);
    }

    void send(int type, const QString &contents)
    {
        if (m_fd == -1) {
            qWarning("appload-run: backend isn't connected, dropping message %d", type);
            return;
        }
        const QByteArray bytes = contents.toUtf8();
        const Header header = { type, int(bytes.size()) };
        ::send(m_fd, &header, sizeof header, 0);
        ::send(m_fd, bytes.constData(), bytes.size(), 0);
    }

    void terminate()
    {
        if (m_process.state() == QProcess::NotRunning) {
            return;
        }
        send(MSG_TERMINATE, "close");
        if (!m_process.waitForFinished(2000)) {
            m_process.kill();
            m_process.waitForFinished();
        }
        unlink(m_socketPath.toLocal8Bit().constData());
    }

private:
    void accept()
    {
        m_fd = ::accept(m_listenFd, nullptr, nullptr);
        if (m_fd == -1) {
            return;
        }
        auto *notifier = new QSocketNotifier(m_fd, QSocketNotifier::Read, this);
        connect(notifier, &QSocketNotifier::activated, this, &Backend::receive);
        announceFrontends();
    }

    void announceFrontends()
    {
        if (m_fd != -1 && !m_endpoints.empty()) {
            send(MSG_NEW_FRONTEND, QString::number(m_endpoints.size()));
        }
    }

    void receive();

    QProcess m_process;
    QString m_socketPath;
    int m_listenFd = -1;
    int m_fd = -1;
    std::vector<AppLoadEndpoint *> m_endpoints;
    std::vector<char> m_buffer = std::vector<char>(MAX_MESSAGE_LENGTH);
};

// The AppLoad QML element, as provided by AppLoad's net.asivery.AppLoad module
class AppLoadEndpoint : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString applicationID READ applicationID WRITE setApplicationID NOTIFY applicationIDChanged)
public:
    ~AppLoadEndpoint() override { Backend::instance()->removeEndpoint(this); }

    QString applicationID() const { return m_applicationID; }
    void setApplicationID(const QString &id)
    {
        if (id == m_applicationID) {
            return;
        }
        m_applicationID = id;
        emit applicationIDChanged();
        Backend::instance()->addEndpoint(this);
    }

    Q_INVOKABLE void sendMessage(int type, const QString &contents) { Backend::instance()->send(type, contents); }
    Q_INVOKABLE void terminate()
    {
        Backend::instance()->terminate();
        QTimer::singleShot(0, qApp, &QCoreApplication::quit);
    }

signals:
    void applicationIDChanged();
    void messageReceived(int type, const QString &contents);

private:
    QString m_applicationID;
};

void Backend::receive()
{
    Header header;
    if (recv(m_fd, &header, sizeof header, 0) < ssize_t(sizeof header)) {
        qInfo("appload-run: backend disconnected");
        static_cast<QSocketNotifier *>(sender())->setEnabled(false);
        close(m_fd);
        m_fd = -1;
        return;
    }
    if (header.length < 0 || header.length > MAX_MESSAGE_LENGTH) {
        qWarning("appload-run: invalid message length %d", header.length);
        return;
    }
    // The backend may skip the contents packet when it's empty
    ssize_t received = 0;
    if (header.length > 0) {
        received = recv(m_fd, m_buffer.data(), header.length, 0);
    }
    const QString contents = QString::fromUtf8(m_buffer.data(), std::max<ssize_t>(received, 0));
    for (AppLoadEndpoint *endpoint : m_endpoints) {
        emit endpoint->messageReceived(header.type, contents);
    }
}

QSize parseSize(const QString &size)
{
    if (size == "move") {
        return { 954, 1696 };
    }
    if (size == "pro") {
        return { 1620, 2160 };
    }
    const QStringList parts = size.split('x');
    if (parts.size() == 2) {
        return { parts[0].toInt(), parts[1].toInt() };
    }
    return {};
}

} // namespace

int main(int argc, char *argv[])
{
    // Qt logs to journald when it can; keep the app's and our messages in the terminal
    if (qEnvironmentVariableIsEmpty("QT_FORCE_STDERR_LOGGING")) {
        qputenv("QT_FORCE_STDERR_LOGGING", "1");
    }
    QGuiApplication app(argc, argv);
    app.setApplicationName("appload-run");

    QCommandLineParser parser;
    parser.setApplicationDescription("Runs an AppLoad application on a PC, with its backend");
    parser.addHelpOption();
    parser.addPositionalArgument("app", "Installed application directory, with manifest.json and resources.rcc");
    parser.addOption({ "size", "Window size: move (default), pro or WIDTHxHEIGHT.", "size", "move" });
    parser.addOption({ "screenshot", "Save a screenshot to <file> and quit.", "file" });
    parser.addOption({ "delay", "Milliseconds to wait before the taps and screenshot (default 2000).", "ms", "2000" });
    parser.addOption({ "tap", "Click at X,Y before the screenshot; repeatable, 400ms apart.", "x,y" });
    parser.process(app);

    if (parser.positionalArguments().size() != 1) {
        parser.showHelp(1);
    }
    const QString appDir = QDir(parser.positionalArguments().first()).absolutePath();
    const QSize size = parseSize(parser.value("size"));
    if (size.isEmpty()) {
        qCritical("appload-run: invalid size %s", qPrintable(parser.value("size")));
        return 1;
    }

    QFile manifestFile(QDir(appDir).filePath("manifest.json"));
    if (!manifestFile.open(QIODevice::ReadOnly)) {
        qCritical("appload-run: no manifest.json in %s", qPrintable(appDir));
        return 1;
    }
    const QJsonObject manifest = QJsonDocument::fromJson(manifestFile.readAll()).object();
    const QString id = manifest.value("id").toString();
    const QString entry = manifest.value("entry").toString();

    if (!QResource::registerResource(QDir(appDir).filePath("resources.rcc"), "/app")) {
        qCritical("appload-run: can't load resources.rcc from %s", qPrintable(appDir));
        return 1;
    }
    qmlRegisterType<AppLoadEndpoint>("net.asivery.AppLoad", 1, 0, "AppLoad");

    QQmlApplicationEngine engine;
    QObject::connect(&app, &QCoreApplication::aboutToQuit, [] { Backend::instance()->terminate(); });

    // Like AppLoad's window: the application's root item fills it, and gets
    // its unloading() function called when closed
    const QByteArray windowQml = R"(
        import QtQuick
        Window {
            id: window
            property url entry
            color: "white"
            visible: true
            Loader {
                id: loader
                anchors.fill: parent
                source: window.entry
            }
            onClosing: {
                if (loader.item && typeof loader.item.unloading === "function") {
                    loader.item.unloading()
                }
            }
        }
    )";
    QQmlComponent component(&engine);
    component.setData(windowQml, QUrl::fromLocalFile(QDir(appDir).filePath("appload-run-window.qml")));
    auto *window = qobject_cast<QQuickWindow *>(component.createWithInitialProperties({
        { "entry", QUrl("qrc:/app" + entry) },
        { "width", size.width() },
        { "height", size.height() },
        { "title", manifest.value("name").toString() },
    }));
    if (!window) {
        qCritical("appload-run: %s", qPrintable(component.errorString()));
        return 1;
    }
    if (manifest.value("loadsBackend").toBool() && !Backend::instance()->start(appDir, id)) {
        delete window;
        return 1;
    }

    // Simulated clicks, for testing without a tablet
    const QStringList taps = parser.values("tap");
    const int delay = parser.value("delay").toInt();
    for (int i = 0; i < taps.size(); i++) {
        const QStringList xy = taps[i].split(',');
        const QPointF position(xy.value(0).toDouble(), xy.value(1).toDouble());
        QTimer::singleShot(delay + i * 400, window, [window, position] {
            for (const QEvent::Type type : { QEvent::MouseButtonPress, QEvent::MouseButtonRelease }) {
                QMouseEvent event(type, position, window->mapToGlobal(position),
                                  Qt::LeftButton, type == QEvent::MouseButtonPress ? Qt::LeftButton : Qt::NoButton, Qt::NoModifier);
                QCoreApplication::sendEvent(window, &event);
            }
        });
    }

    if (parser.isSet("screenshot")) {
        const QString path = parser.value("screenshot");
        QTimer::singleShot(delay + taps.size() * 400 + 500, window, [window, path] {
            if (!window->grabWindow().save(path)) {
                qWarning("appload-run: can't save %s", qPrintable(path));
            }
            QCoreApplication::quit();
        });
    }

    const int result = app.exec();
    delete window;
    return result;
}

#include "main.moc"
