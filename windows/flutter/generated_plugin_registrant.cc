//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <disk_space_2/disk_space_2_plugin.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  DiskSpace_2PluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DiskSpace_2Plugin"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
}
