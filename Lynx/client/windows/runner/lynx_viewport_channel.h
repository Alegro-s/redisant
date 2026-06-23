#ifndef RUNNER_LYNX_VIEWPORT_CHANNEL_H_
#define RUNNER_LYNX_VIEWPORT_CHANNEL_H_

#include <flutter/flutter_engine.h>

#include <windows.h>

void LynxViewportRegister(flutter::BinaryMessenger* messenger, HWND flutter_view_hwnd);

#endif  // RUNNER_LYNX_VIEWPORT_CHANNEL_H_
