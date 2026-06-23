#include "lynx_viewport_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

namespace {

HWND g_flutter_view_hwnd = nullptr;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

}  // namespace

void LynxViewportRegister(flutter::BinaryMessenger* messenger, HWND flutter_view_hwnd) {
  g_flutter_view_hwnd = flutter_view_hwnd;
  g_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "lynx/viewport",
      &flutter::StandardMethodCodec::GetInstance());

  g_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name().compare("getViewHwnd") == 0) {
          if (g_flutter_view_hwnd == nullptr) {
            result->Error("no_hwnd", "Flutter view HWND not set");
            return;
          }
          result->Success(flutter::EncodableValue(
              static_cast<int64_t>(reinterpret_cast<intptr_t>(g_flutter_view_hwnd))));
          return;
        }
        result->NotImplemented();
      });
}
