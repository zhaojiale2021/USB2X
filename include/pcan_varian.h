#pragma once

#include "io_macro.h"

#if (defined CANABLE) || (defined ENTREE) || (defined CANTACT_8) || (defined CANTACT_16)
#define IOPIN_TX B, 1, GPIO_MODE_OUTPUT_PP, GPIO_NOPULL, GPIO_SPEED_FREQ_MEDIUM, GPIO_NOAF
#define IOPIN_RX B, 0, GPIO_MODE_OUTPUT_PP, GPIO_NOPULL, GPIO_SPEED_FREQ_MEDIUM, GPIO_NOAF
#define LED_ON   PIN_HI
#define LED_OFF  PIN_LOW

#define CAN_RX   B, 8, GPIO_MODE_AF_PP, GPIO_NOPULL, GPIO_SPEED_FREQ_HIGH, GPIO_AF4_CAN
#define CAN_TX   B, 9, GPIO_MODE_AF_PP, GPIO_NOPULL, GPIO_SPEED_FREQ_HIGH, GPIO_AF4_CAN

#define pcan_variant_io_init()
#elif (defined OLLIE)
#define CAN_RX        B, 8, GPIO_MODE_AF_PP, GPIO_NOPULL, GPIO_SPEED_FREQ_HIGH, GPIO_AF4_CAN
#define CAN_TX        B, 9, GPIO_MODE_AF_PP, GPIO_NOPULL, GPIO_SPEED_FREQ_HIGH, GPIO_AF4_CAN

#define OUTPUT_EN_5V  C, 13, GPIO_MODE_OUTPUT_PP, GPIO_NOPULL, GPIO_SPEED_FREQ_MEDIUM, GPIO_NOAF
#define OUTPUT_EN_3V3 C, 14, GPIO_MODE_OUTPUT_PP, GPIO_NOPULL, GPIO_SPEED_FREQ_MEDIUM, GPIO_NOAF
#define OUTPUT_EN_1V8 C, 15, GPIO_MODE_OUTPUT_PP, GPIO_NOPULL, GPIO_SPEED_FREQ_MEDIUM, GPIO_NOAF
#define LED_5V        A, 5, GPIO_MODE_OUTPUT_PP, GPIO_NOPULL, GPIO_SPEED_FREQ_MEDIUM, GPIO_NOAF
#define LED_3V3       A, 6, GPIO_MODE_OUTPUT_PP, GPIO_NOPULL, GPIO_SPEED_FREQ_MEDIUM, GPIO_NOAF
#define LED_1V8       A, 7, GPIO_MODE_OUTPUT_PP, GPIO_NOPULL, GPIO_SPEED_FREQ_MEDIUM, GPIO_NOAF
#define SW1           A, 2, GPIO_MODE_INPUT, GPIO_PULLUP, GPIO_SPEED_FREQ_MEDIUM, GPIO_NOAF
#define VS_5V         B, 6, GPIO_MODE_INPUT, GPIO_PULLUP, GPIO_SPEED_FREQ_MEDIUM, GPIO_NOAF
#define VS_3V3        B, 5, GPIO_MODE_INPUT, GPIO_PULLUP, GPIO_SPEED_FREQ_MEDIUM, GPIO_NOAF
#define VS_1V8        B, 4, GPIO_MODE_INPUT, GPIO_PULLUP, GPIO_SPEED_FREQ_MEDIUM, GPIO_NOAF

#define pcan_variant_io_init()                                                                                         \
    do                                                                                                                 \
    {                                                                                                                  \
        PIN_ENABLE_CLOCK(OUTPUT_EN_5V);                                                                                \
        PIN_ENABLE_CLOCK(OUTPUT_EN_3V3);                                                                               \
        PIN_ENABLE_CLOCK(OUTPUT_EN_1V8);                                                                               \
        PIN_ENABLE_CLOCK(LED_5V);                                                                                      \
        PIN_ENABLE_CLOCK(LED_3V3);                                                                                     \
        PIN_ENABLE_CLOCK(LED_1V8);                                                                                     \
        PIN_ENABLE_CLOCK(SW1);                                                                                         \
        PIN_ENABLE_CLOCK(VS_5V);                                                                                       \
        PIN_ENABLE_CLOCK(VS_3V3);                                                                                      \
        PIN_ENABLE_CLOCK(VS_1V8);                                                                                      \
                                                                                                                       \
        PIN_INIT(OUTPUT_EN_5V);                                                                                        \
        PIN_INIT(OUTPUT_EN_3V3);                                                                                       \
        PIN_INIT(OUTPUT_EN_1V8);                                                                                       \
        PIN_INIT(LED_5V);                                                                                              \
        PIN_INIT(LED_3V3);                                                                                             \
        PIN_INIT(LED_1V8);                                                                                             \
        PIN_INIT(SW1);                                                                                                 \
        PIN_INIT(VS_5V);                                                                                               \
        PIN_INIT(VS_3V3);                                                                                              \
        PIN_INIT(VS_1V8);                                                                                              \
                                                                                                                       \
        if (PIN_STAT(VS_5V) == 0)                                                                                      \
        {                                                                                                              \
            PIN_HI(LED_5V);                                                                                            \
            PIN_HI(OUTPUT_EN_5V);                                                                                      \
        }                                                                                                              \
        if (PIN_STAT(VS_3V3) == 0)                                                                                     \
        {                                                                                                              \
            PIN_HI(LED_3V3);                                                                                           \
            PIN_HI(OUTPUT_EN_3V3);                                                                                     \
        }                                                                                                              \
        if (PIN_STAT(VS_1V8) == 0)                                                                                     \
        {                                                                                                              \
            PIN_HI(LED_1V8);                                                                                           \
            PIN_HI(OUTPUT_EN_1V8);                                                                                     \
        }                                                                                                              \
    } while (0)
#else
#error Unknown board variant
#endif
