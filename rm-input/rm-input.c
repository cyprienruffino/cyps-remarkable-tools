// rm-input: simulates touches and pen strokes on the tablet, by writing input
// events to the touchscreen's and the digitizer's device nodes, which the
// kernel delivers like real ones. Coordinates are screen pixels.
//
//   rm-input tap X Y
//   rm-input swipe X1 Y1 X2 Y2 [milliseconds]
//   rm-input pen X1,Y1 X2,Y2 ...      one pen stroke through the points
//
// RM_SCREEN_WIDTH and RM_SCREEN_HEIGHT set the screen size, by default the
// Paper Pro Move's 954x1696.

#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#define BITS_PER_LONG (sizeof(long) * 8)
#define TEST_BIT(bits, bit) ((bits)[(bit) / BITS_PER_LONG] & (1UL << ((bit) % BITS_PER_LONG)))

struct device {
    int fd;
    struct input_absinfo x, y, pressure;
};

static int screenWidth = 954;
static int screenHeight = 1696;

static void sleepMs(int ms)
{
    struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };
    nanosleep(&ts, NULL);
}

static void emit(int fd, int type, int code, int value)
{
    struct input_event event;
    memset(&event, 0, sizeof event);
    event.type = type;
    event.code = code;
    event.value = value;
    if (write(fd, &event, sizeof event) != sizeof event) {
        perror("write");
        exit(1);
    }
}

static void report(int fd)
{
    emit(fd, EV_SYN, SYN_REPORT, 0);
}

// Finds the first input device with the key and the absolute axis
static int openDevice(struct device *device, int key, int xAxis, int yAxis, int pressureAxis)
{
    DIR *dir = opendir("/dev/input");
    struct dirent *entry;
    while (dir && (entry = readdir(dir))) {
        if (strncmp(entry->d_name, "event", 5) != 0) {
            continue;
        }
        char path[300];
        snprintf(path, sizeof path, "/dev/input/%s", entry->d_name);
        const int fd = open(path, O_RDWR | O_CLOEXEC);
        if (fd < 0) {
            continue;
        }
        unsigned long keys[KEY_MAX / BITS_PER_LONG + 1] = { 0 };
        unsigned long axes[ABS_MAX / BITS_PER_LONG + 1] = { 0 };
        ioctl(fd, EVIOCGBIT(EV_KEY, sizeof keys), keys);
        ioctl(fd, EVIOCGBIT(EV_ABS, sizeof axes), axes);
        if (TEST_BIT(keys, key) && TEST_BIT(axes, xAxis) && TEST_BIT(axes, yAxis)) {
            device->fd = fd;
            ioctl(fd, EVIOCGABS(xAxis), &device->x);
            ioctl(fd, EVIOCGABS(yAxis), &device->y);
            memset(&device->pressure, 0, sizeof device->pressure);
            if (pressureAxis >= 0 && TEST_BIT(axes, pressureAxis)) {
                ioctl(fd, EVIOCGABS(pressureAxis), &device->pressure);
            }
            closedir(dir);
            return 1;
        }
        close(fd);
    }
    if (dir) {
        closedir(dir);
    }
    return 0;
}

static int scale(int value, int size, const struct input_absinfo *axis)
{
    return axis->minimum + (long)value * (axis->maximum - axis->minimum) / size;
}

static void touchDown(struct device *touch, int x, int y)
{
    emit(touch->fd, EV_ABS, ABS_MT_SLOT, 0);
    emit(touch->fd, EV_ABS, ABS_MT_TRACKING_ID, 4242);
    emit(touch->fd, EV_ABS, ABS_MT_POSITION_X, scale(x, screenWidth, &touch->x));
    emit(touch->fd, EV_ABS, ABS_MT_POSITION_Y, scale(y, screenHeight, &touch->y));
    emit(touch->fd, EV_ABS, ABS_MT_TOUCH_MAJOR, 20);
    emit(touch->fd, EV_ABS, ABS_MT_PRESSURE, touch->pressure.maximum ? touch->pressure.maximum / 2 : 1);
    emit(touch->fd, EV_KEY, BTN_TOUCH, 1);
    report(touch->fd);
}

static void touchMove(struct device *touch, int x, int y)
{
    emit(touch->fd, EV_ABS, ABS_MT_POSITION_X, scale(x, screenWidth, &touch->x));
    emit(touch->fd, EV_ABS, ABS_MT_POSITION_Y, scale(y, screenHeight, &touch->y));
    report(touch->fd);
}

static void touchUp(struct device *touch)
{
    emit(touch->fd, EV_ABS, ABS_MT_TRACKING_ID, -1);
    emit(touch->fd, EV_KEY, BTN_TOUCH, 0);
    report(touch->fd);
}

static void penAt(struct device *pen, int x, int y, int pressure)
{
    emit(pen->fd, EV_ABS, ABS_X, scale(x, screenWidth, &pen->x));
    emit(pen->fd, EV_ABS, ABS_Y, scale(y, screenHeight, &pen->y));
    emit(pen->fd, EV_ABS, ABS_PRESSURE, pressure);
    report(pen->fd);
}

static int usage(void)
{
    fprintf(stderr, "Usage: rm-input tap X Y\n"
                    "       rm-input swipe X1 Y1 X2 Y2 [milliseconds]\n"
                    "       rm-input pen X1,Y1 X2,Y2 ...\n");
    return 1;
}

int main(int argc, char *argv[])
{
    if (getenv("RM_SCREEN_WIDTH")) {
        screenWidth = atoi(getenv("RM_SCREEN_WIDTH"));
    }
    if (getenv("RM_SCREEN_HEIGHT")) {
        screenHeight = atoi(getenv("RM_SCREEN_HEIGHT"));
    }
    if (argc < 2) {
        return usage();
    }

    if (strcmp(argv[1], "tap") == 0 || strcmp(argv[1], "swipe") == 0) {
        const int swipe = strcmp(argv[1], "swipe") == 0;
        if ((!swipe && argc != 4) || (swipe && argc != 6 && argc != 7)) {
            return usage();
        }
        struct device touch;
        if (!openDevice(&touch, BTN_TOUCH, ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_PRESSURE)) {
            fprintf(stderr, "No touchscreen found\n");
            return 1;
        }
        const int x1 = atoi(argv[2]), y1 = atoi(argv[3]);
        touchDown(&touch, x1, y1);
        if (swipe) {
            const int x2 = atoi(argv[4]), y2 = atoi(argv[5]);
            const int duration = argc == 7 ? atoi(argv[6]) : 300;
            const int steps = duration / 10 > 1 ? duration / 10 : 1;
            for (int i = 1; i <= steps; i++) {
                sleepMs(10);
                touchMove(&touch, x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps);
            }
        } else {
            sleepMs(80);
        }
        touchUp(&touch);
        return 0;
    }

    if (strcmp(argv[1], "pen") == 0) {
        if (argc < 3) {
            return usage();
        }
        struct device pen;
        if (!openDevice(&pen, BTN_TOOL_PEN, ABS_X, ABS_Y, ABS_PRESSURE)) {
            fprintf(stderr, "No pen digitizer found\n");
            return 1;
        }
        const int pressure = pen.pressure.maximum ? pen.pressure.maximum / 2 : 1;
        int lastX = 0, lastY = 0;
        for (int i = 2; i < argc; i++) {
            int x, y;
            if (sscanf(argv[i], "%d,%d", &x, &y) != 2) {
                return usage();
            }
            if (i == 2) {
                // Hover in, then touch down
                emit(pen.fd, EV_KEY, BTN_TOOL_PEN, 1);
                penAt(&pen, x, y, 0);
                sleepMs(30);
                emit(pen.fd, EV_KEY, BTN_TOUCH, 1);
                penAt(&pen, x, y, pressure);
            } else {
                // Interpolate, like a real pen reporting at a high rate
                for (int step = 1; step <= 10; step++) {
                    sleepMs(8);
                    penAt(&pen, lastX + (x - lastX) * step / 10, lastY + (y - lastY) * step / 10, pressure);
                }
            }
            lastX = x;
            lastY = y;
        }
        emit(pen.fd, EV_KEY, BTN_TOUCH, 0);
        penAt(&pen, lastX, lastY, 0);
        sleepMs(30);
        emit(pen.fd, EV_KEY, BTN_TOOL_PEN, 0);
        report(pen.fd);
        return 0;
    }

    return usage();
}
