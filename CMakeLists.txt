cmake_minimum_required(VERSION 3.6)
project(classypay C ASM)

include("CMakeEnv.cmake")
set(NRF_TARGET "nrf52")
include("CMake_nRF5x.cmake")
 
nRF5x_setup()
nRF5x_addAppTimer()
nRF5x_addAppScheduler()
nRF5x_addBLEAdvertising()

include_directories(".")
list(APPEND SOURCE_FILES "main.c")

nRF5x_addExecutable(${PROJECT_NAME} "${SOURCE_FILES}")
