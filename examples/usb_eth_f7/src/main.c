#include <stdint.h>

#include "bsp/board_api.h"
#include "class/net/net_device.h"
#include "stm32f7xx_hal.h"
#include "tusb.h"

#include "eth_bridge.h"

uint8_t tud_network_mac_address[6];

static void mac_init(void)
{
    /* Derive a stable locally-administered MAC address from the MCU UID. */
    uint32_t uid0 = HAL_GetUIDw0();
    uint32_t uid1 = HAL_GetUIDw1();
    uint32_t uid2 = HAL_GetUIDw2();

    tud_network_mac_address[0] = 0x02;
    tud_network_mac_address[1] = (uint8_t)(uid0 >> 0);
    tud_network_mac_address[2] = (uint8_t)(uid1 >> 8);
    tud_network_mac_address[3] = (uint8_t)(uid1 >> 16);
    tud_network_mac_address[4] = (uint8_t)(uid2 >> 0);
    tud_network_mac_address[5] = (uint8_t)(uid2 >> 8);
}

/*--------------------------------------------------------------------+
 * TinyUSB network device callbacks
 *--------------------------------------------------------------------*/

bool tud_network_recv_cb(const uint8_t* src, uint16_t size)
{
    if (!eth_bridge_transmit(src, size))
        return false;

    tud_network_recv_renew();
    return true;
}

uint16_t tud_network_xmit_cb(uint8_t* dst, void* ref, uint16_t arg)
{
    (void)ref;
    return eth_bridge_copy_frame(dst, arg);
}

void tud_network_init_cb(void) {}

int main(void)
{
    board_init();
    mac_init();

    eth_bridge_init(tud_network_mac_address);

    tusb_rhport_init_t dev_init = {.role = TUSB_ROLE_DEVICE, .speed = TUSB_SPEED_AUTO};
    tusb_init(BOARD_TUD_RHPORT, &dev_init);
    board_init_after_tusb();

    bool host_link_up = false;

    while (1)
    {
        tud_task();
        eth_bridge_poll();

        bool link_up = eth_bridge_link_up();
        if (link_up != host_link_up)
        {
            host_link_up = link_up;
            tud_network_link_state(BOARD_TUD_RHPORT, link_up);
        }

        if (tud_ready() && eth_bridge_frame_pending())
        {
            uint16_t len = eth_bridge_frame_len();
            if (tud_network_can_xmit(len))
            {
                tud_network_xmit(NULL, len);
                eth_bridge_pop_frame();
            }
        }
    }
}
