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

### Raspberry Pi

Make sure you enabled I2C functionality first.

### bsec_bme680 just quits without a message

Your bsec_iaq.state file might be corrupt or incompatible after an update of the
BSEC library. Try (re)moving it.

### remote I/O error

If you get `user_i2c_write: Remote I/O error` on run time, check the I2C address used by your version of the sensor:
```
sudo i2cdetect -y 1
```
If you find a device on `77` but not on `76`, then your sensor is configured to use its secondary I2C address. In this case, change this at the beginning of `bsec_bme680.c`:
```
int i2c_address = BME680_I2C_ADDR_PRIMARY;
```
to
```
int i2c_address = BME680_I2C_ADDR_SECONDARY;
```
and recompile (`./make.sh`).

## Checksums of supported BSEC versions:

```
63ad6fe8f797aa49fef9db31bb380248cb5dc3d08a237698a987b9a31dde4be1  BSEC_1.4.5.1_Generic_Release_20171214.zip
4fcd01568e877d16e3e520f76de5c0d352c793a5604622061d3ee4291e83f887  BSEC_1.4.6.0_Generic_Release_20180323.zip
d4b1d633a55b8238814656f2a056968d25f59a14c9c809504bc54a4988a8b1c0  BSEC_1.4.6.0_Generic_Release_20180425.zip
2345a08cd261774aa41066480e27907f92e329107a02f74183ae608587658445  BSEC_1.4.7.1_Generic_Release_20180907.zip
fb64f03fded01d44fc5fc1ef65934cb3ff089a14e2af5f7c12f9394f92c83192  BSEC_1.4.7.2_Generic_Release_20190122.zip
587c1e6a2a0823d279cda6c59bfcd753e3375444c4d66ab39d92b12fecc9d8b5  BSEC_1.4.7.3_Generic_Release_20190410.zip
d063e2af886656d51aa6787ae9975d932e297448e531a1692e93371a6e575042  BSEC_1.4.7.4_Generic_Release.zip
c56d537538c07db4a778a332ef65f203e4eac2113953f7a104e838d9f6af31e5  bsec_1-4-8-0_generic_release.zip
```

