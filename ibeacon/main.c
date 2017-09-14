#include <stdbool.h>
#include <stdint.h>
#include <ble_gap.h>
#include "nordic_common.h"
#include "nrf_soc.h"
#include "nrf_sdh.h"
#include "nrf_sdh_ble.h"
#include "ble_advdata.h"
#include "app_scheduler.h"
#include "app_timer.h"
#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "nrf_log_default_backends.h"
#include "nrf_drv_gpiote.h"
#include "app_button.h"

#define LED_PIN                         25
#define BUTTON_PIN                      24

#define APP_BLE_CONN_CFG_TAG            1                                 /**< A tag identifying the SoftDevice BLE configuration. */
#define NON_CONNECTABLE_ADV_INTERVAL    MSEC_TO_UNITS(100, UNIT_0_625_MS) /**< The advertising interval for non-connectable advertisement (100 ms). This value can vary between 100ms to 10.24s). */

#define APP_BEACON_INFO_LENGTH          0x17                              /**< Total length of information advertised by the Beacon. */
#define APP_ADV_DATA_LENGTH             0x15                              /**< Length of manufacturer specific data in the advertisement. */
#define APP_DEVICE_TYPE                 0x02                              /**< 0x02 refers to Beacon. */
#define APP_MEASURED_RSSI               0xC3                              /**< The Beacon's measured RSSI at 1 meter distance in dBm. */
#define APP_COMPANY_IDENTIFIER          0x004c                            /** Company identifier for Apple iBeacon */
#define APP_MAJOR_VALUE                 0x00, 0xCC                        /**< Major value used to identify Beacons. */
#define APP_MINOR_VALUE                 0x00, 0x00                        /**< Initial minor value used to identify Beacons. */
#define APP_BEACON_UUID                 0x33, 0x01, 0x3f, 0x7f,    0xcb, 0x46, 0x4d, 0xb6,     0xb4, 0xbe, 0x54, 0x2c,   0x31, 0x0a, 0x81, 0xeb
#define MINOR_OFFSET_IN_BEACON_INFO     20
#define DEAD_BEEF                       0xDEADBEEF                        /**< Value used as error code on stack dump, can be used to identify stack location on stack unwind. */

static ble_gap_adv_params_t m_adv_params;                                 /**< Parameters to be passed to the stack when starting advertising. */
static uint8_t              m_advertising = 0;
static uint16_t             m_minor = 0;
static ble_gap_addr_t       m_addr;
static uint8_t              m_beacon_info[APP_BEACON_INFO_LENGTH] = {
        APP_DEVICE_TYPE,
        APP_ADV_DATA_LENGTH,
        APP_BEACON_UUID,
        APP_MAJOR_VALUE,
        APP_MINOR_VALUE,
        APP_MEASURED_RSSI
};
static ble_advdata_manuf_data_t m_manuf_specific_data;

/**@brief Callback function for asserts in the SoftDevice.
 *
 * @details This function will be called in case of an assert in the SoftDevice.
 *
 * @warning This handler is an example only and does not fit a final product. You need to analyze
 *          how your product is supposed to react in case of Assert.
 * @warning On assert from the SoftDevice, the system can only recover on reset.
 *
 * @param[in]   line_num   Line number of the failing ASSERT call.
 * @param[in]   file_name  File name of the failing ASSERT call.
 */
void assert_nrf_callback(uint16_t line_num, const uint8_t *p_file_name) {
    app_error_handler(DEAD_BEEF, line_num, p_file_name);
}

static void led_init() {
    ret_code_t err_code;

    err_code = nrf_drv_gpiote_init();
    APP_ERROR_CHECK(err_code);

    nrf_drv_gpiote_out_config_t out_config = GPIOTE_CONFIG_OUT_SIMPLE(false);
    err_code = nrf_drv_gpiote_out_init(LED_PIN, &out_config);
    nrf_gpio_cfg_output(LED_PIN);
    APP_ERROR_CHECK(err_code);
}

static void set_led(int state) {
    if (state) {
        nrf_drv_gpiote_out_set(LED_PIN);
    } else {
        nrf_drv_gpiote_out_clear(LED_PIN);
    }
}

/**@brief Function for initializing the Advertising functionality.
 *
 * @details Encodes the required advertising data and passes it to the stack.
 *          Also builds a structure to be passed to the stack when starting advertising.
 */
static void advertising_init(void) {
    uint32_t err_code;
    ble_advdata_t advdata;
    ble_advdata_t *scan_response_data = NULL; // no scan response
    uint8_t flags = BLE_GAP_ADV_FLAG_BR_EDR_NOT_SUPPORTED;

    m_manuf_specific_data.company_identifier = APP_COMPANY_IDENTIFIER;
    m_manuf_specific_data.data.p_data = (uint8_t *) m_beacon_info;
    m_manuf_specific_data.data.size = APP_BEACON_INFO_LENGTH;

    // Build and set advertising data.
    memset(&advdata, 0, sizeof(advdata));

    advdata.name_type = BLE_ADVDATA_NO_NAME;
    advdata.flags = flags;
    advdata.p_manuf_specific_data = &m_manuf_specific_data;

    m_beacon_info[MINOR_OFFSET_IN_BEACON_INFO] = (uint8_t)((m_minor >> 16) & 0xff);
    m_beacon_info[MINOR_OFFSET_IN_BEACON_INFO + 1] = (uint8_t)(m_minor & 0xff);

    err_code = ble_advdata_set(&advdata, scan_response_data); // will set on SD sd_ble_gap_adv_data_set
    APP_ERROR_CHECK(err_code);

    // Initialize advertising parameters (used when starting advertising).
    memset(&m_adv_params, 0, sizeof(m_adv_params));

    m_adv_params.type = BLE_GAP_ADV_TYPE_ADV_NONCONN_IND;
    m_adv_params.p_peer_addr = NULL;    // Undirected advertisement.
    m_adv_params.fp = BLE_GAP_ADV_FP_ANY;
    m_adv_params.interval = NON_CONNECTABLE_ADV_INTERVAL;
    m_adv_params.timeout = 0;       // Never time out
}

static void advertising_start(void) {
    ret_code_t err_code;

    NRF_LOG_INFO("Start advertising: %d", m_minor);
    err_code = sd_ble_gap_adv_start(&m_adv_params, APP_BLE_CONN_CFG_TAG);
    APP_ERROR_CHECK(err_code);
    set_led(1);
}

static void advertising_stop(void) {
    ret_code_t err_code;

    err_code = sd_ble_gap_adv_stop();
    APP_ERROR_CHECK(err_code);

    NRF_LOG_INFO("Stop advertising");
    set_led(0);
}

static void ble_stack_init(void) {
    ret_code_t err_code;

    err_code = nrf_sdh_enable_request();
    APP_ERROR_CHECK(err_code);

    // Configure the BLE stack using the default settings.
    // Fetch the start address of the application RAM.
    uint32_t ram_start = 0;
    err_code = nrf_sdh_ble_default_cfg_set(APP_BLE_CONN_CFG_TAG, &ram_start);
    APP_ERROR_CHECK(err_code);

    // Enable BLE stack.
    err_code = nrf_sdh_ble_enable(&ram_start);
    APP_ERROR_CHECK(err_code);

    // Reduce transmission power to the minimum
    err_code = sd_ble_gap_tx_power_set(-16);
    APP_ERROR_CHECK(err_code);

    // Retrieve MAC address for logging
    err_code = sd_ble_gap_addr_get(&m_addr);
    APP_ERROR_CHECK(err_code);
}

static void log_init(void) {
    ret_code_t err_code = NRF_LOG_INIT(NULL);
    APP_ERROR_CHECK(err_code);
    NRF_LOG_DEFAULT_BACKENDS_INIT();
}

static void timer_init(void) {
    ret_code_t err_code = app_timer_init();
    APP_ERROR_CHECK(err_code);
}

void button_press_handler(uint8_t pin_no, uint8_t button_action) {
    if (pin_no == BUTTON_PIN && button_action == APP_BUTTON_RELEASE) {
        if (!m_advertising) {
            m_advertising = 1;
            m_minor++;
            advertising_init(); // reinitialize to cycle minor
            advertising_start();
        } else {
            m_advertising = 0;
            advertising_stop();
        }
    }
}

static app_button_cfg_t m_button_cfg[] = {
        {
                .pin_no = BUTTON_PIN,
                .active_state = APP_BUTTON_ACTIVE_HIGH,
                .pull_cfg = NRF_GPIO_PIN_PULLUP,
                .button_handler = button_press_handler
        }
};

static void button_init() {
    ret_code_t err_code;
    err_code = app_button_init(m_button_cfg, 1, APP_TIMER_TICKS(50));
    APP_ERROR_CHECK(err_code);

    err_code = app_button_enable();
    APP_ERROR_CHECK(err_code);
}


void sd_state_evt_handler(nrf_sdh_state_evt_t state, void *p_context) {
    switch (state) {
        case NRF_SDH_EVT_STATE_ENABLE_PREPARE:
            break;
        case NRF_SDH_EVT_STATE_ENABLED:
            break;
        case NRF_SDH_EVT_STATE_DISABLE_PREPARE:
            break;
        case NRF_SDH_EVT_STATE_DISABLED:
            break;
    }
}

#define OBSERVER_PRIO 1
NRF_SDH_STATE_OBSERVER(m_state_observer, OBSERVER_PRIO) = {
        .handler   = sd_state_evt_handler,
        .p_context = NULL
};

int main(void) {
    log_init();
    timer_init();
    led_init();
    ble_stack_init();
    advertising_init();
    button_init();

    set_led(0);

    uint8_t *const addr = m_addr.addr;
    NRF_LOG_INFO("Init complete, MAC address: %02x:%02x:%02x:%02x:%02x:%02x",
                 addr[5], addr[4], addr[3], addr[2], addr[1], addr[0]);

    while (true) {
        NRF_LOG_PROCESS();
        app_sched_execute();
    }
}
