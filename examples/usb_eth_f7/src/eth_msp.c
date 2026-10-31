#include "stm32f7xx_hal.h"

extern ETH_HandleTypeDef heth;

void ETH_IRQHandler(void);

void HAL_ETH_MspInit(ETH_HandleTypeDef* eth_handle)
{
    (void)eth_handle;

    GPIO_InitTypeDef gpio = {0};

    __HAL_RCC_GPIOA_CLK_ENABLE();
    __HAL_RCC_GPIOC_CLK_ENABLE();
    __HAL_RCC_GPIOG_CLK_ENABLE();
    __HAL_RCC_SYSCFG_CLK_ENABLE();
    __HAL_RCC_ETH_CLK_ENABLE();

    gpio.Mode      = GPIO_MODE_AF_PP;
    gpio.Pull      = GPIO_NOPULL;
    gpio.Speed     = GPIO_SPEED_FREQ_VERY_HIGH;
    gpio.Alternate = GPIO_AF11_ETH;

    /* RMII: REF_CLK, MDIO, CRS_DV */
    gpio.Pin = GPIO_PIN_1 | GPIO_PIN_2 | GPIO_PIN_7;
    HAL_GPIO_Init(GPIOA, &gpio);

    /* RMII: MDC, RXD0, RXD1 */
    gpio.Pin = GPIO_PIN_1 | GPIO_PIN_4 | GPIO_PIN_5;
    HAL_GPIO_Init(GPIOC, &gpio);

    /* RMII: RXER, TX_EN, TXD0, TXD1 */
    gpio.Pin = GPIO_PIN_2 | GPIO_PIN_11 | GPIO_PIN_13 | GPIO_PIN_14;
    HAL_GPIO_Init(GPIOG, &gpio);

    HAL_NVIC_SetPriority(ETH_IRQn, 5U, 0U);
    HAL_NVIC_EnableIRQ(ETH_IRQn);
}

void HAL_ETH_MspDeInit(ETH_HandleTypeDef* eth_handle)
{
    (void)eth_handle;

    HAL_NVIC_DisableIRQ(ETH_IRQn);
    __HAL_RCC_ETH_CLK_DISABLE();
}

void ETH_IRQHandler(void)
{
    HAL_ETH_IRQHandler(&heth);
}
