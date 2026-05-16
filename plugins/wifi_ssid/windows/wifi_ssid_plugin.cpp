#include "wifi_ssid_plugin.h"

#include <windows.h>
#include <wlanapi.h>
#include <objbase.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#pragma comment(lib, "wlanapi.lib")
#pragma comment(lib, "ole32.lib")

namespace wifi_ssid {

namespace {

enum class SsidQueryStatus {
  kSuccess,
  kNoSsid,
  kAccessDenied,
  kError,
};

struct SsidQueryResult {
  SsidQueryStatus status;
  std::string ssid;
  DWORD error_code;
};

std::unique_ptr<
    flutter::MethodChannel<flutter::EncodableValue>,
    std::default_delete<flutter::MethodChannel<flutter::EncodableValue>>>
    channel = nullptr;

constexpr int kPermissionGranted = 0;
constexpr int kPermissionDenied = 1;

SsidQueryResult QuerySsid() {
  HANDLE hClient = nullptr;
  DWORD dwMaxClient = 2;
  DWORD dwCurVersion = 0;
  DWORD dwResult =
      WlanOpenHandle(dwMaxClient, nullptr, &dwCurVersion, &hClient);
  if (dwResult != ERROR_SUCCESS) {
    return {dwResult == ERROR_ACCESS_DENIED ? SsidQueryStatus::kAccessDenied
                                            : SsidQueryStatus::kError,
            "", dwResult};
  }

  PWLAN_INTERFACE_INFO_LIST pIfList = nullptr;
  dwResult = WlanEnumInterfaces(hClient, nullptr, &pIfList);
  if (dwResult != ERROR_SUCCESS) {
    WlanCloseHandle(hClient, nullptr);
    return {dwResult == ERROR_ACCESS_DENIED ? SsidQueryStatus::kAccessDenied
                                            : SsidQueryStatus::kError,
            "", dwResult};
  }

  std::string ssid;
  DWORD query_error = ERROR_SUCCESS;
  for (DWORD i = 0; i < pIfList->dwNumberOfItems; i++) {
    PWLAN_CONNECTION_ATTRIBUTES pConnAttrib = nullptr;
    DWORD dwDataSize = sizeof(WLAN_CONNECTION_ATTRIBUTES);
    WLAN_INTF_OPCODE opCode = wlan_intf_opcode_current_connection;

    dwResult = WlanQueryInterface(
        hClient, &pIfList->InterfaceInfo[i].InterfaceGuid, opCode, nullptr,
        &dwDataSize, (PVOID *)&pConnAttrib, nullptr);

    if (dwResult == ERROR_SUCCESS && pConnAttrib != nullptr) {
      if (pConnAttrib->isState == wlan_interface_state_connected) {
        DWORD ssidLen =
            pConnAttrib->wlanAssociationAttributes.dot11Ssid.uSSIDLength;
        if (ssidLen > 0 && ssidLen <= 32) {
          ssid.assign(
              reinterpret_cast<const char *>(
                  pConnAttrib->wlanAssociationAttributes.dot11Ssid.ucSSID),
              ssidLen);
        }
        WlanFreeMemory(pConnAttrib);
        break;
      }
      WlanFreeMemory(pConnAttrib);
    } else if (dwResult == ERROR_ACCESS_DENIED) {
      query_error = dwResult;
      break;
    } else if (query_error == ERROR_SUCCESS) {
      query_error = dwResult;
    }
  }

  WlanFreeMemory(pIfList);
  WlanCloseHandle(hClient, nullptr);

  if (query_error == ERROR_ACCESS_DENIED) {
    return {SsidQueryStatus::kAccessDenied, "", query_error};
  }

  if (ssid.empty()) {
    return {SsidQueryStatus::kNoSsid, "", query_error};
  }

  return {SsidQueryStatus::kSuccess, ssid, ERROR_SUCCESS};
}

}  // namespace

void WifiSsidPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "wifi_ssid",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WifiSsidPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

WifiSsidPlugin::WifiSsidPlugin() {}

WifiSsidPlugin::~WifiSsidPlugin() {}

void WifiSsidPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getSsid") == 0) {
    GetSsid(std::move(result));
  } else if (method_call.method_name().compare("checkPermission") == 0 ||
             method_call.method_name().compare("requestPermission") == 0) {
    const auto query_result = QuerySsid();
    const bool denied =
        query_result.status == SsidQueryStatus::kAccessDenied;
    result->Success(flutter::EncodableValue(
        denied ? kPermissionDenied : kPermissionGranted));
  } else {
    result->NotImplemented();
  }
}

void WifiSsidPlugin::GetSsid(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto query_result = QuerySsid();
  if (query_result.status == SsidQueryStatus::kSuccess) {
    result->Success(flutter::EncodableValue(query_result.ssid));
    return;
  }

  if (query_result.status == SsidQueryStatus::kNoSsid ||
      query_result.status == SsidQueryStatus::kAccessDenied) {
    result->Success(flutter::EncodableValue());
    return;
  }

  result->Error("WLAN_ERROR", "Failed to query current WiFi SSID",
                flutter::EncodableValue(
                    static_cast<int>(query_result.error_code)));
}

}  // namespace wifi_ssid
