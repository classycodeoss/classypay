#!/bin/sh
export SDK_ROOT=$HOME/nRF5/SDK
export CLT_ROOT=$HOME/nRF5/CommandLineTools
export SOFT_DEVICE=$SDK_ROOT/components/softdevice/s132/hex/s132_nrf52_5.0.0_softdevice.hex
export PATH=$CLT_ROOT/mergehex:$PATH

echo "Flashing $1 with soft device"
mergehex -m $SOFT_DEVICE $1 -o merged.hex
/bin/cp merged.hex /Volumes/DAPLINK/
