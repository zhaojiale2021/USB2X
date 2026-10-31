#include "eth_bridge.h"

#include <string.h>

#include "stm32f7xx_hal.h"

/* Ethernet frame buffers must live in DMA-capable SRAM1 (not DTCM).
 * The linker script maps .eth_dma to 0x20040000. */
#define ETH_FRAME_MAX       1536U
#define ETH_RX_POOL_SIZE    8U
#define ETH_TX_QUEUE_SIZE   4U
#define ETH_FRAME_RING_SIZE 16U
#define ETH_LINK_POLL_MS    500U

#define PHY_REG_BSR         1U
#define PHY_REG_ID1         2U
#define PHY_REG_ID2         3U
#define PHY_BSR_LINK_UP     (1U << 2)
#define PHY_BSR_100_FULL    (1U << 13)
#define PHY_BSR_100_HALF    (1U << 12)
#define PHY_BSR_10_FULL     (1U << 11)
#define PHY_BSR_10_HALF     (1U << 10)

typedef struct
{
    uint16_t len;
    uint8_t  data[ETH_FRAME_MAX];
} eth_frame_t;

typedef struct
{
    uint8_t          data[ETH_FRAME_MAX] __attribute__((aligned(32)));
    volatile uint8_t in_use;
} eth_tx_buf_t;

ETH_HandleTypeDef heth;

static ETH_DMADescTypeDef rx_desc[ETH_RX_DESC_CNT] __attribute__((section(".eth_dma"), aligned(32)));
static ETH_DMADescTypeDef tx_desc[ETH_TX_DESC_CNT] __attribute__((section(".eth_dma"), aligned(32)));
static uint8_t            rx_pool[ETH_RX_POOL_SIZE][ETH_FRAME_MAX] __attribute__((section(".eth_dma"), aligned(32)));
static eth_tx_buf_t       tx_queue[ETH_TX_QUEUE_SIZE] __attribute__((section(".eth_dma"), aligned(32)));

static volatile uint8_t rx_pool_busy[ETH_RX_POOL_SIZE];
static uint8_t*         rx_frame_bufs[ETH_RX_DESC_CNT];
static uint32_t         rx_frame_buf_count;

static eth_frame_t       frame_ring[ETH_FRAME_RING_SIZE];
static volatile uint16_t frame_head;
static volatile uint16_t frame_tail;

static uint8_t  eth_mac[6];
static uint8_t  phy_addr;
static bool     phy_found;
static bool     link_up;
static uint32_t last_link_poll;

/*--------------------------------------------------------------------+
 * RX buffer pool and frame ring
 *--------------------------------------------------------------------*/

static void rx_pool_release(uint8_t* buffer)
{
    uintptr_t offset = (uintptr_t)buffer - (uintptr_t)rx_pool;

    if ((offset % ETH_FRAME_MAX) != 0U)
        return;

    uint32_t index = (uint32_t)(offset / ETH_FRAME_MAX);
    if (index < ETH_RX_POOL_SIZE)
        rx_pool_busy[index] = 0U;
}

static eth_frame_t* frame_ring_alloc(void)
{
    uint16_t next = (uint16_t)((frame_head + 1U) % ETH_FRAME_RING_SIZE);

    if (next == frame_tail)
        return NULL;

    return &frame_ring[frame_head];
}

static void frame_ring_push(void)
{
    __DMB();
    frame_head = (uint16_t)((frame_head + 1U) % ETH_FRAME_RING_SIZE);
}

/*--------------------------------------------------------------------+
 * HAL Ethernet callbacks
 *--------------------------------------------------------------------*/

void HAL_ETH_RxAllocateCallback(uint8_t** buff)
{
    *buff = NULL;

    for (uint32_t i = 0U; i < ETH_RX_POOL_SIZE; i++)
    {
        if (!rx_pool_busy[i])
        {
            rx_pool_busy[i] = 1U;
            *buff           = rx_pool[i];
            return;
        }
    }
}

void HAL_ETH_RxLinkCallback(void** pStart, void** pEnd, uint8_t* buff, uint16_t Length)
{
    (void)Length;

    if (rx_frame_buf_count < ETH_RX_DESC_CNT)
        rx_frame_bufs[rx_frame_buf_count++] = buff;

    if (*pStart == NULL)
        *pStart = buff;

    *pEnd = buff;
}

void HAL_ETH_RxCpltCallback(ETH_HandleTypeDef* h)
{
    for (;;)
    {
        void* buffer = NULL;

        rx_frame_buf_count = 0U;
        if (HAL_ETH_ReadData(h, &buffer) != HAL_OK || buffer == NULL)
            break;

        uint16_t len = (uint16_t)h->RxDescList.RxDataLength;

        /* Standard Ethernet frames fit in one buffer. Jumbo/multi-buffer
         * frames are dropped rather than forwarded as a partial packet. */
        if (rx_frame_buf_count == 1U && len >= 14U && len <= ETH_FRAME_MAX)
        {
            eth_frame_t* frame = frame_ring_alloc();
            if (frame != NULL)
            {
                frame->len = len;
                memcpy(frame->data, buffer, len);
                frame_ring_push();
            }
        }

        for (uint32_t i = 0U; i < rx_frame_buf_count; i++)
            rx_pool_release(rx_frame_bufs[i]);
    }
}

void HAL_ETH_TxFreeCallback(uint32_t* buff)
{
    if (buff == NULL)
        return;

    uintptr_t offset = (uintptr_t)buff - (uintptr_t)tx_queue;
    if ((offset % sizeof(eth_tx_buf_t)) != 0U)
        return;

    uint32_t index = (uint32_t)(offset / sizeof(eth_tx_buf_t));
    if (index < ETH_TX_QUEUE_SIZE)
        tx_queue[index].in_use = 0U;
}

void HAL_ETH_TxCpltCallback(ETH_HandleTypeDef* h)
{
    (void)HAL_ETH_ReleaseTxPacket(h);
}

void HAL_ETH_ErrorCallback(ETH_HandleTypeDef* h)
{
    /* Reclaim TX descriptors that completed before the error was reported. */
    (void)HAL_ETH_ReleaseTxPacket(h);
}

/*--------------------------------------------------------------------+
 * PHY / link handling
 *--------------------------------------------------------------------*/

static bool phy_read(uint32_t reg, uint32_t* value)
{
    return HAL_ETH_ReadPHYRegister(&heth, phy_addr, reg, value) == HAL_OK;
}

static bool phy_find(void)
{
    for (uint32_t addr = 0U; addr < 32U; addr++)
    {
        uint32_t id1 = 0U;
        uint32_t id2 = 0U;

        if (HAL_ETH_ReadPHYRegister(&heth, addr, PHY_REG_ID1, &id1) == HAL_OK
            && HAL_ETH_ReadPHYRegister(&heth, addr, PHY_REG_ID2, &id2) == HAL_OK && id1 != 0U && id1 != 0xFFFFU
            && id2 != 0xFFFFU)
        {
            phy_addr = (uint8_t)addr;
            return true;
        }
    }

    return false;
}

static void eth_update_link(void)
{
    uint32_t bsr = 0U;

    if (!phy_found || !phy_read(PHY_REG_BSR, &bsr) || bsr == 0xFFFFU)
        return;

    bool up = (bsr & PHY_BSR_LINK_UP) != 0U;
    if (up == link_up)
        return;

    link_up = up;

    if (!up)
        return;

    uint32_t speed  = ETH_SPEED_100M;
    uint32_t duplex = ETH_FULLDUPLEX_MODE;

    if (bsr & PHY_BSR_100_FULL)
    {
        speed  = ETH_SPEED_100M;
        duplex = ETH_FULLDUPLEX_MODE;
    }
    else if (bsr & PHY_BSR_100_HALF)
    {
        speed  = ETH_SPEED_100M;
        duplex = ETH_HALFDUPLEX_MODE;
    }
    else if (bsr & PHY_BSR_10_FULL)
    {
        speed  = ETH_SPEED_10M;
        duplex = ETH_FULLDUPLEX_MODE;
    }
    else
    {
        speed  = ETH_SPEED_10M;
        duplex = ETH_HALFDUPLEX_MODE;
    }

    ETH_MACConfigTypeDef mac = {0};
    if (HAL_ETH_GetMACConfig(&heth, &mac) == HAL_OK)
    {
        mac.Speed      = speed;
        mac.DuplexMode = duplex;
        (void)HAL_ETH_SetMACConfig(&heth, &mac);
    }
}

/*--------------------------------------------------------------------+
 * Public API
 *--------------------------------------------------------------------*/

void eth_bridge_init(const uint8_t mac[6])
{
    memcpy(eth_mac, mac, sizeof(eth_mac));

    /* tx_queue lives in the NOLOAD .eth_dma section, so initialise it here. */
    for (uint32_t i = 0U; i < ETH_TX_QUEUE_SIZE; i++)
        tx_queue[i].in_use = 0U;
    for (uint32_t i = 0U; i < ETH_RX_POOL_SIZE; i++)
        rx_pool_busy[i] = 0U;
    frame_head = 0U;
    frame_tail = 0U;
    link_up    = false;
    phy_found  = false;

    heth.Instance            = ETH;
    heth.Init.MACAddr        = eth_mac;
    heth.Init.MediaInterface = HAL_ETH_RMII_MODE;
    heth.Init.RxDesc         = rx_desc;
    heth.Init.TxDesc         = tx_desc;
    heth.Init.RxBuffLen      = ETH_FRAME_MAX;

    if (HAL_ETH_Init(&heth) != HAL_OK)
        return;

    HAL_ETH_SetMDIOClockRange(&heth);
    phy_found = phy_find();

    /* Strip the FCS/padding from every received frame: the host expects a
     * clean Ethernet frame, not one with the 4-byte CRC appended. */
    ETH_MACConfigTypeDef mac_default = {0};
    if (HAL_ETH_GetMACConfig(&heth, &mac_default) == HAL_OK)
    {
        mac_default.AutomaticPadCRCStrip = ENABLE;
        (void)HAL_ETH_SetMACConfig(&heth, &mac_default);
    }

    /* Transparent bridge: the host's MAC address is unknown to the MCU, so
     * receive everything and let the USB side decide what to keep. */
    ETH_MACFilterConfigTypeDef filter = {0};
    if (HAL_ETH_GetMACFilterConfig(&heth, &filter) == HAL_OK)
    {
        filter.PromiscuousMode  = ENABLE;
        filter.PassAllMulticast = ENABLE;
        (void)HAL_ETH_SetMACFilterConfig(&heth, &filter);
    }

    if (HAL_ETH_Start_IT(&heth) != HAL_OK)
        return;

    last_link_poll = HAL_GetTick();
    eth_update_link();
}

void eth_bridge_poll(void)
{
    uint32_t now = HAL_GetTick();

    if ((now - last_link_poll) >= ETH_LINK_POLL_MS)
    {
        last_link_poll = now;
        eth_update_link();
    }
}

bool eth_bridge_link_up(void)
{
    return link_up;
}

bool eth_bridge_transmit(const uint8_t* data, uint16_t len)
{
    if (!link_up || data == NULL || len == 0U || len > ETH_FRAME_MAX)
        return false;

    eth_tx_buf_t* tx = NULL;

    for (uint32_t i = 0U; i < ETH_TX_QUEUE_SIZE; i++)
    {
        if (!tx_queue[i].in_use)
        {
            tx_queue[i].in_use = 1U;
            tx                 = &tx_queue[i];
            break;
        }
    }

    if (tx == NULL)
    {
        (void)HAL_ETH_ReleaseTxPacket(&heth);
        for (uint32_t i = 0U; i < ETH_TX_QUEUE_SIZE; i++)
        {
            if (!tx_queue[i].in_use)
            {
                tx_queue[i].in_use = 1U;
                tx                 = &tx_queue[i];
                break;
            }
        }
    }

    if (tx == NULL)
        return false;

    memcpy(tx->data, data, len);

    ETH_BufferTypeDef buffer = {0};
    buffer.buffer            = tx->data;
    buffer.len               = len;
    buffer.next              = NULL;

    ETH_TxPacketConfigTypeDef config = {0};
    config.Attributes                = ETH_TX_PACKETS_FEATURES_CRCPAD;
    config.Length                    = len;
    config.TxBuffer                  = &buffer;
    config.CRCPadCtrl                = ETH_CRC_PAD_INSERT;
    config.ChecksumCtrl              = ETH_CHECKSUM_DISABLE;
    config.pData                     = tx;

    if (HAL_ETH_Transmit_IT(&heth, &config) != HAL_OK)
    {
        tx->in_use = 0U;
        return false;
    }

    return true;
}

bool eth_bridge_frame_pending(void)
{
    __DMB();
    return frame_head != frame_tail;
}

uint16_t eth_bridge_frame_len(void)
{
    return frame_ring[frame_tail].len;
}

uint16_t eth_bridge_copy_frame(uint8_t* dst, uint16_t max_len)
{
    const eth_frame_t* frame = &frame_ring[frame_tail];
    uint16_t           len   = (frame->len < max_len) ? frame->len : max_len;

    memcpy(dst, frame->data, len);
    return len;
}

void eth_bridge_pop_frame(void)
{
    frame_tail = (uint16_t)((frame_tail + 1U) % ETH_FRAME_RING_SIZE);
}
