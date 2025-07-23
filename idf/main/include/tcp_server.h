#ifndef TCP_SERVER_H
#define TCP_SERVER_H

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

// TCP server configuration
#define TCP_PORT 2000
#define BUFFER_SIZE 1024

/**
 * @brief Start TCP server task
 */
void tcp_server_start(void);

#endif // TCP_SERVER_H 