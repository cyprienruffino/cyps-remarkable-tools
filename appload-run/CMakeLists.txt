cmake_minimum_required(VERSION 3.16)
project(appload-run LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Qml Quick Test)

add_executable(appload-run main.cpp)
target_link_libraries(appload-run PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Test)
install(TARGETS appload-run)
