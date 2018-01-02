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

BME_INTERVAL=3

A_LIMIT_1='1.00'
A_LIMIT_2='2.00'
A_LIMIT_3='3.00'

I_LIMIT_0='0.00'
I_LIMIT_1='50.00'  #   0 -  50: good air
I_LIMIT_2='100.00' #  51 - 100: average air
I_LIMIT_3='150.00' # 101 - 150: little bad air
I_LIMIT_4='200.00' # 151 - 200: bad air
I_LIMIT_5='300.00' # 201 - 300: worse air
I_LIMIT_6='500.00' # 301 - 500: very bad air

T_LIMIT_UP_E='40.00'
T_LIMIT_UP='22.00'
T_LIMIT_DOWN='20.00'
T_LIMIT_DOWN_E='17.00'

H_LIMIT_UP='60.00'
H_LIMIT_UP_E='75.00'
H_LIMIT_DOWN='40.00'

# emoji
E_A_G='😊'
E_A_A='🙂'
E_A_L='😟'
E_A_B='😩'
E_A_W='😨'
E_A_V='😵'

E_T_H='🌡'
E_T_L='❄'
E_H_H='💧'
E_H_L='🌵'

# Bosch supplied accuracies
# triggers will take them into account before reporting limit reach
# this helps preventing jumps on readings near trigger values, favoring a
# limit already reached
TOL_AIR='15.00'
TOL_TEMP='1.00'
TOL_HUM='3.00'
TOL_P='0.12'

# global vars for readings
D=''    # date
A='0'   # IAQ accuracy
I='0'   # IAQ
T='0'   # temperature
H='0'   # humidity
P='0'   # pressure
S='0'   # BSEC status

# how many readings before making an output?
OUT_Q=$(( ${INTERVAL} / ${BME_INTERVAL} ))

# the status array will be used to check whether limit triggers changed
STATUS_ARR[0]=0

# other global vars
LS=''                 # last lilne from the CSV
OUTPUT=''             # string to be put out
OUT_COUNTER=0         # call output() when equal to OUT_Q
PROBLEM=0             # global problem status. unused currently.
FEEDBACKS=''          # list of reading types that already gave feedback
ARRAY_COUNTER=0       # one array index for each limit_trigger() function
STATUS_STRING=''      # status array as string
STATUS_STRING_PAST='' # status string from last round
FIRST_RUN=1           # is this the first round?
NL='                  # newline
'

### functions ###

# clear global vars
clear () {
  LS=''
  OUTPUT=''
  PROBLEM=0
  FEEDBACKS=''
  ARRAY_COUNTER=0
}

# latest status
lstatus () {
  LS="$( tail -n 1 "${LOGFILE}" )"
}

# get a single value
# IN: int of CSV column
sv () {
  # CSV column
  c="$1"
  printf "%s" "${LS}" | awk -v var="${c}" -F ',' '{print $var}'
}

# float comparison
# IN: float as string that is meant to be smaller or equal
# IN: float as string that is meant to be greater
float_gt () {
  smaller="$1"
  greater="$2"
  printf "%s\n" ${smaller}'<='${greater} | bc -l
}

# put together a string to be printed
# IN: string, message to be printed
# IN: int, problem status
# IN: string, type of reading
out_feedback () {
  m="$1"
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
  OUTPUT="${OUTPUT}${conj} ${m}.${p}"
}

# just output the readings from CSV
out_readings () {
  OUTPUT="${OUTPUT} ${D} ${A} ${I} ${T} ${H} ${P} ${S}"
}

# check if a limit was reached, do associated actions
# IN: string, type of reading
# IN: string, limit in float format
# IN: string, limit direction (up or down)
# IN: string, messgae to be printed
# IN: int, is reaching this trigger problematic?
# IN: string, extra actions
limit_trigger () {
  type="$1"
  limit="$2"
  limit_direction="$3"
  msg="$4"
  problem_trigger="$5"
  action="$6"

  # make sure to grow the array to full size
  if [ ${FIRST_RUN} -eq 1 ]; then
    STATUS_ARR[${ARRAY_COUNTER}]='0'
  fi

  # store whether this limit was triggered last time
  last_status=${STATUS_ARR[${ARRAY_COUNTER}]}

  # has a limit of the same type already been reached?
  if printf "%s" "${FEEDBACKS}" | grep -E "^${type}$" > /dev/null; then
    ARRAY_COUNTER=$(( ARRAY_COUNTER + 1 ))
    return
  fi

  # standard values
  tolerance='0.00'
  changes_status=1

  # assign readings, tolerances etc.
  case "${type}" in
    acc)
      reading="${A}"
      changes_status=0
      ;;
    air)
      reading="${I}"
      tolerance="${TOL_AIR}"
      ;;
    temp)
      reading="${T}"
      tolerance="${TOL_TEMP}"
      ;;
    hum)
      reading="${H}"
      tolerance="${TOL_HUM}"
      ;;
  esac

  case "${limit_direction}" in
    up)
      if [ ${last_status} -eq 1 ]; then
        limit="$( printf "%s\n" "${limit}-${tolerance}/2" | bc -l )"
      fi
      smaller="${reading}"
      greater="${limit}"
      ;;
    down)
      smaller="${limit}"
      greater="${reading}"
      if [ ${last_status} -eq 1 ]; then
        limit="$( printf "%s\n" "${limit}+${tolerance}/2" | bc -l )"
      fi
      ;;
  esac

  # float_gt: smaller <= greater -> 1
  if [ "$( float_gt "${smaller}" "${greater}" )" -eq 1 ]; then
    STATUS_ARR[${ARRAY_COUNTER}]=0
  else
    out_feedback "${msg}" "${problem_trigger}" "${type}"
    ${action}
    # add to list of types that reached limit
    FEEDBACKS="${FEEDBACKS}${NL}${type}"
    if [ ${problem_trigger} -ne 0 ]; then
      PROBLEM=1
    fi
    STATUS_ARR[${ARRAY_COUNTER}]=${changes_status}
  fi

  ARRAY_COUNTER=$(( ARRAY_COUNTER + 1 ))
}

output () {
  #out_readings

  # get means
  A="$( printf "%s\n" "scale=2; ${A}/${OUT_COUNTER}" | bc -l )"
  I="$( printf "%s\n" "scale=2; ${I}/${OUT_COUNTER}" | bc -l )"
  T="$( printf "%s\n" "scale=2; ${T}/${OUT_COUNTER}" | bc -l )"
  H="$( printf "%s\n" "scale=2; ${H}/${OUT_COUNTER}" | bc -l )"
  P="$( printf "%s\n" "scale=2; ${P}/${OUT_COUNTER}" | bc -l )"
  # round for output
  I_R="$( printf "%.0f" "${I}" )"
  T_R="$( printf "%.1f" "${T}" )"
  H_R="$( printf "%.0f" "${H}" )"

  # type; reading; limit; direction; message; problem 0|1; extra function
  # make sure to arrange triggers of same type from worst to most harmless
  limit_trigger 'air'  "${I_LIMIT_5}"      'up'   "VERY BAD air ${E_A_V} [${I_R} IAQ]"    1 ""
  limit_trigger 'air'  "${I_LIMIT_4}"      'up'   "WORSE air ${E_A_W} [${I_R} IAQ]"       1 ""
  limit_trigger 'air'  "${I_LIMIT_3}"      'up'   "BAD air ${E_A_B} [${I_R} IAQ]"         1 ""
  limit_trigger 'air'  "${I_LIMIT_2}"      'up'   "little BAD air ${E_A_L} [${I_R} IAQ]"  1 ""
  limit_trigger 'air'  "${I_LIMIT_1}"      'up'   "average air ${E_A_A} [${I_R} IAQ]"     0 ""
  limit_trigger 'air'  "${I_LIMIT_1}"      'down' "good air ${E_A_G} [${I_R} IAQ]"        0 ""

  limit_trigger 'acc'  "${A_LIMIT_1}"      'down' "(I'm very unsure though)"              0 ""
  limit_trigger 'acc'  "${A_LIMIT_2}"      'down' "(I'm unsure though)"                   0 ""
  limit_trigger 'acc'  "${A_LIMIT_3}"      'down' "(I'm not fully sure though)"           0 ""

  limit_trigger 'temp' "${T_LIMIT_UP_E}"   'up'   "it's HOT ${E_T_H} [${T_R} °C]"         1 ""
  limit_trigger 'temp' "${T_LIMIT_UP}"     'up'   "it's warm ${E_T_H} [${T_R} °C]"        1 ""
  limit_trigger 'temp' "${T_LIMIT_DOWN_E}" 'down' "it's FREEZING ${E_T_L} [${T_R} °C]"    1 ""
  limit_trigger 'temp' "${T_LIMIT_DOWN}"   'down' "it's cold ${E_T_L} [${T_R} °C]"        1 ""

  limit_trigger 'hum'  "${H_LIMIT_UP_E}"   'up'   "it's VERY humid ${E_H_H} [${H_R} %rH]" 1 ""
  limit_trigger 'hum'  "${H_LIMIT_UP}"     'up'   "it's humid ${E_H_H} [${H_R} %rH]"      1 ""
  limit_trigger 'hum'  "${H_LIMIT_DOWN}"   'down' "it's arid ${E_H_L} [${H_R} %rH]"       1 ""

  # array to string for comparison
  STATUS_STRING="$( printf "%s" "${STATUS_ARR[@]}" )"

  if [ "${STATUS_STRING}" != "${STATUS_STRING_PAST}" ]; then
    # print output and remove leading or trailing whitespace and conjunction hints
    # also uppercase first letter
    OUTPUT="$( printf "%s" "${OUTPUT}" | sed -e 's/^,*\ *//' -e 's/[10]\ *$//' )"
    upper="$( printf "%s" "${OUTPUT}" | cut -c 1 | tr [:lower:] [:upper:] )"
    OUTPUT="$( printf "%s" "${OUTPUT}" | sed "s/^./${upper}/" )"

    #if [ $PROBLEM -ne 0 ]; then
    #else
    #fi

    #t update "${OUTPUT}" > /dev/null || true

    printf "%s\n" "${OUTPUT}"
  fi

  STATUS_STRING_PAST="${STATUS_STRING}"

  OUT_COUNTER=0
  D='0'
  A='0'
  I='0'
  T='0'
  H='0'
  P='0'
  S='0'
  FIRST_RUN=0
}

### loop ###

main () {
  lstatus

  OUT_COUNTER=$(( ${OUT_COUNTER} + 1 ))

  # add up readings that we want means from
  D="$( sv 1 )"
  A="$( printf "%s\n" "${A}+$( sv 2 )" | bc -l )"
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
  fi
  clear
  sleep ${BME_INTERVAL}
done

