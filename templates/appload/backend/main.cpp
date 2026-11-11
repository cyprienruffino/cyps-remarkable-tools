// AppLoad backend: AppLoad starts it with its socket path as the first argument,
// and its working directory set to the application directory.

#include "appload.h"

#include <algorithm>
#include <cctype>
#include <iostream>

// Must match ui/main.qml
constexpr int MSG_SHOUT = 1;     // frontend -> backend: some text
constexpr int MSG_READY = 100;   // backend -> frontend
constexpr int MSG_SHOUTED = 101; // backend -> frontend: the text, upper-cased

int main(int argc, char *argv[])
{
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <appload socket path>" << std::endl;
        return 1;
    }

    appload::Connection appload;
    if (!appload.connect(argv[1])) {
        perror("connect");
        return 1;
    }

    appload::Message message;
    while (appload.receive(&message)) {
        switch (message.type) {
        case appload::MSG_TERMINATE:
            return 0;
        case appload::MSG_NEW_FRONTEND:
            appload.send(MSG_READY, "ready");
            break;
        case MSG_SHOUT: {
            std::string text = message.contents;
            std::transform(text.begin(), text.end(), text.begin(), [](unsigned char c) { return std::toupper(c); });
            appload.send(MSG_SHOUTED, text);
            break;
        }
        default:
            std::cerr << "Unknown message type " << message.type << std::endl;
        }
    }
    return 0;
}
