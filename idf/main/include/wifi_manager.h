#ifndef WIFI_MANAGER_H
#define WIFI_MANAGER_H

#include "esp_wifi.h"
#include "esp_event.h"

// WiFi configuration
#define WIFI_SSID "RoeBoat-AP"
#define WIFI_PASS "roeboat123"

/**
 * @brief Initialize WiFi in Access Point mode
 */
void wifi_init_softap(void);

#endif // WIFI_MANAGER_H 