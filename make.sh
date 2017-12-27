#!/bin/sh

set  -eu

BSEC_DIR='./src/BSEC_1.4.5.1_Generic_Release_20171214'

ARCH='RaspberryPI/PiZero_ArmV6-32bits'

# Other architectures can be found in BSEC_DIR/algo/bin/.

CONFIG='generic_33v_3s_4d'

# Other configs are:
# generic_18v_300s_28d
# generic_18v_300s_4d
# generic_18v_3s_28d
# generic_18v_3s_4d
# generic_33v_300s_28d
# generic_33v_300s_4d
# generic_33v_3s_28d
# generic_33v_3s_4d

CONFIG_DIR='.'

if [ ! -d "${BSEC_DIR}" ]; then
  echo 'BSEC directory missing.'
  exit 1
fi

if [ ! -d "${CONFIG_DIR}" ]; then
  mkdir "${CONFIG_DIR}"
fi

echo 'Compiling...'
cc -Wall -static \
  -iquote"${BSEC_DIR}"/API \
  -iquote"${BSEC_DIR}"/algo \
  -iquote"${BSEC_DIR}"/example \
  "${BSEC_DIR}"/API/bme680.c \
  "${BSEC_DIR}"/example/bsec_integration.c \
  ./bsec_bme680.c \
  -L"${BSEC_DIR}"/"${ARCH}" -lalgobsec \
  -lm -lrt \
  -o bsec_bme680
echo 'Compiled.'

cp "${BSEC_DIR}"/config/"${CONFIG}"/bsec_iaq.config "${CONFIG_DIR}"/
echo 'Copied config.'
