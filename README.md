# bsec_bme680_linux

Read the BME680 sensor with the BSEC library on Linux (e.g. Raspberry Pi)

## Intro

Working example of fully using the
[BME680 sensor](https://www.bosch-sensortec.com/en/bst/products/all_products/bme680)
on Linux (e.g. Raspberry Pi) with the precompiled
[BSEC library](https://www.bosch-sensortec.com/bst/products/all_products/bsec),
which allows to read calibrated environment values including an actual Indoor
Air Quality (IAQ) score.

It makes use of
[Bosch's provided driver](https://github.com/BoschSensortec/BME680_driver)
and can be configured in terms of it.
Readings will be directly output to stdout in a loop.

## Prerequisites

[Download the BSEC software package from Bosch](https://www.bosch-sensortec.com/bst/products/all_products/bsec)
and put it into `./src`, then unpack.

## Configure and Compile

Optionally make changes to make.config.

Depending on how your sensor is embedded it might be surrounded by other
components giving off heat. Use an offset in °C in `bsec_bme680.c` to
compensate. The default is 5 °C:
```
#define temp_offset (5.0f)
```

To compile: `./make.sh`

## Usage

Output will be similar to this:

```
$ ./bsec_bme680
2017-12-27 18:47:21,[IAQ (1)]: 33.96,[T degC]: 19.61,[H %rH]: 46.41,[P hPa]: 983.39,[G Ohms]: 540924.00,[S]: 0
2017-12-27 18:47:24,[IAQ (1)]: 45.88,[T degC]: 19.61,[H %rH]: 46.41,[P hPa]: 983.41,[G Ohms]: 535321.00,[S]: 0
2017-12-27 18:47:26,[IAQ (1)]: 40.65,[T degC]: 19.60,[H %rH]: 46.45,[P hPa]: 983.39,[G Ohms]: 537893.00,[S]: 0
2017-12-27 18:47:29,[IAQ (1)]: 30.97,[T degC]: 19.60,[H %rH]: 46.42,[P hPa]: 983.41,[G Ohms]: 542672.00,[S]: 0
```
* IAQ (n) - Accuracy of the IAQ score from 0 (low) to 3 (high).
* S: n - Return value of the BSEC library

It can easily be modified in the `output_ready` function.

The BSEC library is supposed to create an internal state of calibration with
increasing accuracy over time. Each 10.000 samples it will save the internal
calibration state to `./bsec_iaq.state` (or wherever you specify the config
directory to be) so it can pick up where it was after interruption.

## Further

You can find a growing list of tools to further use and visualize the data
[here](https://github.com/alexh-name/bme680_outputs).

## Troubleshooting

### bsec_bme680 just quits without a message

Your bsec_iaq.state file might be corrupt or incompatible after an update of the
BSEC library. Try (re)moving it.

