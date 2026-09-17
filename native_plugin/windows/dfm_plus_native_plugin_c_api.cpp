#include "include/dfm_plus_native/dfm_plus_native_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "dfm_plus_native_plugin.h"

void DfmPlusNativePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  dfm_plus_native::DfmPlusNativePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
