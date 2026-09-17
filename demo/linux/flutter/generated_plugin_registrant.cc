//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <dfm_plus_native/dfm_plus_native_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) dfm_plus_native_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "DfmPlusNativePlugin");
  dfm_plus_native_plugin_register_with_registrar(dfm_plus_native_registrar);
}
