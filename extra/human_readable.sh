#!/bin/sh
# (c) alexh 2017

# this will check a CSV from BME680 + BSEC readings for some significant change
# and gives feedback in form of a sentence. useful for automatic notifications.
# bc is needed for float operations.

# you may want to use an output like this to get some simple CSV format.
# to get the output of bsec_bme680 to a file you can use tee or output
# redirection.

#  printf("%d-%02d-%02d %02d:%02d:%02d,", tm.tm_year + 1900,tm.tm_mon + 1,
#         tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec); /* localtime */
#  printf("%d,%.2f", iaq_accuracy, iaq);
#  printf(",%.2f,%.2f,%.2f", temperature,
#         humidity,pressure / 100);
#  printf(",%.0f", gas);
#  printf(",%d", bsec_status);
#  printf("\r\n");

set -eu

### setup ###

LOGFILE="./log.csv"
INTERVAL=30 # seconds, should be multiple of BME_INTERVAL

BME_INTERVAL=3 # seconds, interval of measurements

LS=''
OUTPUT=''
OUT_Q=0
OUT_COUNTER=0
PROBLEM=0 # problem status. unused currently.
FEEDBACKS='' # list of reading types that already gave feedback
EMPTY_ARR[0]=0 # used to clear the status array
# the status array will be used to check whether limit triggers changed
# between problematic / not problematic
STATUS_ARR="${EMPTY_ARR[@]}"
ARRAY_COUNTER=0
STATUS_STRING_PAST=''
STATUS_STRING=''
NL='
'
D=''    # date
I_A='0' # IAQ accuracy
I='0'   # IAQ
T='0'   # temperature
H='0'   # humidity
P='0'   # pressure
S='0'   # BSEC status

A_LIMIT_1=0.99
A_LIMIT_2=1.99
A_LIMIT_3=2.99
I_LIMIT_1='50.00'
I_LIMIT_2='100.00'
I_LIMIT_3='150.00'
I_LIMIT_4='200.00'
I_LIMIT_5='300.00'
T_LIMIT_UP='22.51'
T_LIMIT_DOWN='19.49'
H_LIMIT_UP='60.01'
H_LIMIT_DOWN='29.99'

OUT_Q=$(( ${INTERVAL} / ${BME_INTERVAL} ))

### functions ###

# clear global vars
clear () {
  LS=''
  OUTPUT=''
  PROBLEM=0
  FEEDBACKS=''
  STATUS_ARR="${EMPTY_ARR[@]}"
  ARRAY_COUNTER=0
}

# latest status
lstatus () {
  LS="$( tail -n 1 "${LOGFILE}" )"
}

# get a single value
sv () {
  # CSV column
  c="$1"
  printf "%s" "${LS}" | awk -v var="${c}" -F ',' '{print $var}'
}

# float comparison
float_gt () {
  smaller="$1"
  greater="$2"
  # not portable
  #awk -v s="${smaller}" -v g="${greater}" 'BEGIN{ print s<g }'
  printf "%s\n" ${smaller}'<'${greater} | bc -l
}

out_feedback () {
  f="$1"
  p="$2"
  t="$3"
  conj=''

  # last character in output
  lc="$( printf "%s" "${OUTPUT}" | grep -oE "[01]$" || true )"

  if [ ! -z "${OUTPUT}" ] && [ ! -z "${lc}" ]; then
    if [ ${lc} -eq ${p} ]; then
      conj=', and'
    else
      conj=', but'
    fi  
  fi

  # if type is accuracy, we might want to carry the problem status of the last
  # reading, not our own
  # also we might have a special conj in case of not very good accuracy
  if [ "${t}" == 'acc' ]; then
    p=${lc}
    conj=''
  fi
 
  # remove existing conjunction hints and periods
  OUTPUT="$( printf "%s" "${OUTPUT}" | sed 's/\.[01]$//' )"
  OUTPUT="${OUTPUT}${conj} ${f}.${p}"
}

# just output the readings from CSV
out_readings () {
  OUTPUT="${OUTPUT} ${D} ${I_A} ${I} ${T} ${H} ${P} ${S}"
}

limit_trigger () {
  type="$1"
  reading="$2"
  limit="$3"
  limit_direction="$4"
  msg="$5"
  problem_trigger="$6"
  action="$7"

  # has a limit of the same type already been reached?
  if printf "%s" "${FEEDBACKS}" | grep -E "^${type}$" > /dev/null; then
    return
  fi

  case "${limit_direction}" in
    up)
      smaller="${reading}"
      greater="${limit}"
      ;;
    down)
      smaller="${limit}"
      greater="${reading}"
      ;;
  esac

  # unused currently
  if [ ${problem_trigger} -ne 0 ]; then
    PROBLEM=1
  fi

  # float_gt: smaller < greater -> 1
  if [ "$( float_gt "${smaller}" "${greater}" )" -ne 1 ]; then
    out_feedback "${msg}" "${problem_trigger}" "${type}"
    ${action}
    # add to list of types that reached limit
    FEEDBACKS="${FEEDBACKS}${NL}${type}"
    STATUS_ARR[${ARRAY_COUNTER}]=${problem_trigger}
  else
    STATUS_ARR[${ARRAY_COUNTER}]=0
  fi

  ARRAY_COUNTER=$(( ARRAY_COUNTER + 1 ))
}

output () {

  #out_readings

  # get means
  I_A="$( printf "%s\n" "scale=2; ${I_A}/${OUT_COUNTER}" | bc -l )"
  I="$( printf "%s\n" "scale=2; ${I}/${OUT_COUNTER}" | bc -l )"
  T="$( printf "%s\n" "scale=2; ${T}/${OUT_COUNTER}" | bc -l )"
  H="$( printf "%s\n" "scale=2; ${H}/${OUT_COUNTER}" | bc -l )"
  P="$( printf "%s\n" "scale=2; ${P}/${OUT_COUNTER}" | bc -l )"

  # type; reading; limit; direction; message; problem 0|1; extra function
  # make sure to arrange triggers of same type from worst to most harmless
  limit_trigger 'air' "${I}" "${I_LIMIT_5}" 'up' "VERY BAD air [${I}]" "1" ""
  limit_trigger 'air' "${I}" "${I_LIMIT_4}" 'up' "WORSE air [${I}]" "1" ""
  limit_trigger 'air' "${I}" "${I_LIMIT_3}" 'up' "BAD air [${I}]" "1" ""
  limit_trigger 'air' "${I}" "${I_LIMIT_2}" 'up' "little BAD air [${I}]" "1" ""
  limit_trigger 'air' "${I}" "${I_LIMIT_1}" 'up' "average air [${I}]" "1" ""
  limit_trigger 'air' "${I}" "${I_LIMIT_1}" 'down' "good air [${I}]" "0" ""
  limit_trigger 'acc' "${I_A}" "${A_LIMIT_1}" 'down' "(I'm very unsure though)" "0" ""
  limit_trigger 'acc' "${I_A}" "${A_LIMIT_2}" 'down' "(I'm unsure though)" "0" ""
  limit_trigger 'acc' "${I_A}" "${A_LIMIT_3}" 'down' "(I'm not fully sure though)" "0" ""
  limit_trigger 'temp' "${T}" "${T_LIMIT_UP}" 'up' "it's warm [${T}°C]" "1" ""
  limit_trigger 'temp' "${T}" "${T_LIMIT_DOWN}" 'down' "it's cold [${T}°C]" "1" ""
  limit_trigger 'hum' "${H}" "${H_LIMIT_UP}" 'up' "it's dank [${H}%rH]" "1" ""
  limit_trigger 'hum' "${H}" "${H_LIMIT_DOWN}" 'down' "it's dry [${H}%rH]" "1" ""

  # array to string for comparison
  STATUS_STRING="$( printf "%s" "${STATUS_ARR[@]}" )"

  if [ "${STATUS_STRING}" != "${STATUS_STRING_PAST}" ]; then
    # print output and remove leading or trailing whitespace and conjunction hints
    # also uppercase first letter
    OUTPUT="$( printf "%s" "${OUTPUT}" | sed -e 's/^,*\ *//' -e 's/[10]\ *$//' )"
    upper="$( printf "%s" "${OUTPUT}" | cut -c 1 | tr [:lower:] [:upper:] )"
    printf "%s\n" "${OUTPUT}" | sed "s/^./${upper}/"
  fi
  STATUS_STRING_PAST="${STATUS_STRING}"

  #if [ $PROBLEM -ne 0 ]; then
  #  return 1
  #fi
}

### loop ###

main () {
  lstatus

  OUT_COUNTER=$(( ${OUT_COUNTER} + 1 ))

  # add up readings that we want means from
  D="$( sv 1 )"
  I_A="$( printf "%s\n" "${I_A}+$( sv 2 )" | bc -l )"
  I="$( printf "%s\n" "${I}+$( sv 3 )" | bc -l )"
  T="$( printf "%s\n" "${T}+$( sv 4 )" | bc -l )"
  H="$( printf "%s\n" "${H}+$( sv 5 )" | bc -l )"
  P="$( printf "%s\n" "${P}+$( sv 6 )" | bc -l )"
  S="$( sv 8 )"
}

while true; do
  main
  if [ ${OUT_Q} -eq ${OUT_COUNTER} ]; then
    output
    OUT_COUNTER=0
    D='0'
    I_A='0'
    I='0'
    T='0'
    H='0'
    P='0'
    S='0'
  fi
  clear
  sleep ${BME_INTERVAL}
done

