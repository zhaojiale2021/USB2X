#pragma once

#include <stdbool.h>
#include <stdint.h>

/* Initialize the STM32F7 Ethernet MAC/DMA and the LAN8742A PHY. */
void eth_bridge_init(const uint8_t mac[6]);

/* Poll the PHY link state (call from the main loop). */
void eth_bridge_poll(void);

/* Current PHY link state. */
bool eth_bridge_link_up(void);

/* Host -> wire: enqueue one Ethernet frame for transmission. Returns false
 * when the TX queue is full or the link is down (TinyUSB will retry). */
bool eth_bridge_transmit(const uint8_t* data, uint16_t len);

/* Wire -> host: single-producer (ETH IRQ) / single-consumer (main loop) frame
 * ring. The consumer must pop a frame after copying it. */
bool     eth_bridge_frame_pending(void);
uint16_t eth_bridge_frame_len(void);
uint16_t eth_bridge_copy_frame(uint8_t* dst, uint16_t max_len);
void     eth_bridge_pop_frame(void);
