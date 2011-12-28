#!/bin/sh

export HOME="/home/root"

#
# HELP FUNCTIONS
#

get_vsink_id() {
  case ${1} in
    palerts) echo "0" ;;
    pnotifications) echo "1" ;;
    pfeedback) echo "2" ;;
    pringtones) echo "3" ;;
    pmedia) echo "4" ;;
    pflash) echo "5" ;;
    pnavigation) echo "6" ;;
    pvoicedial) echo "7" ;;
    pvvm) echo "8" ;;
    pvoip) echo "9" ;;
    pdefaultapp) echo "10" ;;
    peffects) echo "11" ;;
    pDTMF) echo "12" ;;
    pcalendar) echo "13" ;;
    palarm) echo "14" ;;
  esac
}

#
# MAIN FUNCTION
#

mkdir -p /home/root >/dev/null 2>&1

DIR=$(dirname ${0})

if [ -z "${1}" ]; then
  exit 0
fi

if [ -e /tmp/papctl-lock ]; then
  exit 0
fi

case ${1} in
  reset)
    touch /tmp/papctl-lock

    COUNT="0";

    while [ ${COUNT} -lt 15 ]; do
      ${DIR}/papctl "C ${COUNT} 0 0"

      let COUNT="${COUNT} + 1"
    done

    if [ -e "/tmp/papctl-usbmod" ]; then
      USB_MODULE=$(cat /tmp/papctl-usbmod)

      /usr/bin/pactl unload-module ${USB_MODULE}
    fi

    if [ -e "/tmp/papctl-netmod" ]; then
      NET_MODULE=$(cat /tmp/papctl-netmod)

      /usr/bin/pactl unload-module ${NET_MODULE}
    fi

    if [ -e "/tmp/papctl-listen" ]; then
      CUR_LISTEN=$(cat /tmp/papctl-listen)

      /usr/bin/pactl unload-module ${CUR_LISTEN}
    fi

    sleep 3

    rm -f /tmp/papctl-vsinks >/dev/null 2>&1
    rm -f /tmp/papctl-usbmod >/dev/null 2>&1
    rm -f /tmp/papctl-netmod >/dev/null 2>&1
    rm -f /tmp/papctl-server >/dev/null 2>&1
    rm -f /tmp/papctl-listen >/dev/null 2>&1
    ;;

  usbon)
    touch /tmp/papctl-lock

    VSINKS="${2}"

    if [ -e "/tmp/papctl-vsinks" ]; then
      cat /tmp/papctl-vsinks | sed s/","/"\n"/g >/tmp/papctl-list

      cat /tmp/papctl-list | while read SINK ; do
        ID=$(get_vsink_id ${SINK})

        if [ ! -z "${ID}" ]; then
          ${DIR}/papctl "C ${ID} 0 0"
        fi
      done

      sleep 1
    fi

    if [ -e "/tmp/papctl-usbmod" ]; then
      USB_MODULE=$(cat /tmp/papctl-usbmod)

      /usr/bin/pactl unload-module ${USB_MODULE}

      sleep 2
    fi

    /usr/bin/pactl load-module module-alsa-sink device=hw:1 sink_name=usb mmap=1 tsched=1 channels=2 >/tmp/papctl-usbmod

    if [ "${?}" == "0" ]; then
      sleep 2

      echo ${VSINKS} >/tmp/papctl-vsinks

      echo ${VSINKS} | sed s/","/"\n"/g >/tmp/papctl-list

      cat /tmp/papctl-list | while read SINK ; do
        ID=$(get_vsink_id ${SINK})
 
        if [ ! -z "${ID}" ]; then
          ${DIR}/papctl "O ${ID} 2 0"
        fi
      done
    else
      echo "Module load error"

      rm -f /tmp/papctl-vsinks >/dev/null 2>&1
      rm -f /tmp/papctl-usbmod >/dev/null 2>&1
    fi
    ;;

  usboff)
    touch /tmp/papctl-lock

    if [ -e "/tmp/papctl-vsinks" ]; then
      if [ ! -e "/tmp/papctl-netmod" ]; then
        cat /tmp/papctl-vsinks | sed s/","/"\n"/g >/tmp/papctl-list

        cat /tmp/papctl-list | while read SINK ; do
          ID=$(get_vsink_id ${SINK})
 
          if [ ! -z "${ID}" ]; then
            ${DIR}/papctl "C ${ID} 0 0"
          fi
        done
      fi
    fi

    if [ -e "/tmp/papctl-usbmod" ]; then
      USB_MODULE=$(cat /tmp/papctl-usbmod)

      /usr/bin/pactl unload-module ${USB_MODULE}

      sleep 2
    fi

    rm -f /tmp/papctl-vsinks >/dev/null 2>&1
    rm -f /tmp/papctl-usbmod >/dev/null 2>&1
    ;;

  connect)
    if [ -z "${2}" ]; then
      exit 1
    fi

    touch /tmp/papctl-lock

    SERVER="${2}" ; VSINKS="${3}"

    CUR_SERVER="" ; NET_MODULE="" ; CUR_VSINKS=""

    if [ -e "/tmp/papctl-server" ]; then
      CUR_SERVER=$(cat /tmp/papctl-server)
    fi

    if [ -e "/tmp/papctl-netmod" ]; then
      NET_MODULE=$(cat /tmp/papctl-netmod)
    fi

    if [ -e "/tmp/papctl-vsinks" ]; then
      CUR_VSINKS=$(cat /tmp/papctl-vsinks)
    fi

    if [ "${SERVER}" != "${CUR_SERVER}" ]; then
      echo "${SERVER}" >/tmp/papctl-server

      if [ -e "/tmp/papctl-vsinks" ]; then
        cat /tmp/papctl-vsinks | sed s/","/"\n"/g >/tmp/papctl-list

        cat /tmp/papctl-list | while read SINK ; do
          ID=$(get_vsink_id ${SINK})

          if [ ! -z "${ID}" ]; then
            ${DIR}/papctl "C ${ID} 0 0"
          fi
        done

        sleep 1
      fi

      if [ -e "/tmp/papctl-netmod" ]; then
        /usr/bin/pactl unload-module ${NET_MODULE}

        sleep 2
      fi

      /usr/bin/pactl load-module module-tunnel-sink server=${SERVER} sink_name=wifi >/tmp/papctl-netmod

      if [ "${?}" == "0" ]; then
        sleep 5

        /usr/bin/pactl list | grep -q "wifi"

        if [ "${?}" == "0" ]; then
          echo ${VSINKS} >/tmp/papctl-vsinks

          echo ${VSINKS} | sed s/","/"\n"/g >/tmp/papctl-list

          cat /tmp/papctl-list | while read SINK ; do
            ID=$(get_vsink_id ${SINK})

            if [ ! -z "${ID}" ]; then
              ${DIR}/papctl "O ${ID} 3 0"
            fi
          done
        else
          echo "Connection error"

          NET_MODULE=$(cat /tmp/papctl-netmod)

          /usr/bin/pactl unload-module ${NET_MODULE}

          sleep 2

          rm -f /tmp/papctl-vsinks >/dev/null 2>&1
          rm -f /tmp/papctl-netmod >/dev/null 2>&1
          rm -f /tmp/papctl-server >/dev/null 2>&1
        fi
      else
        echo "Module load error"

        rm -f /tmp/papctl-vsinks >/dev/null 2>&1
        rm -f /tmp/papctl-netmod >/dev/null 2>&1
        rm -f /tmp/papctl-server >/dev/null 2>&1
      fi
    elif [ "${VSINKS}" != "${CUR_VSINKS}" ]; then
      if [ -e "/tmp/papctl-vsinks" ]; then
        cat /tmp/papctl-vsinks | sed s/","/"\n"/g >/tmp/papctl-list

        cat /tmp/papctl-list | while read SINK ; do
          ID=$(get_vsink_id ${SINK})

          if [ ! -z "${ID}" ]; then
            ${DIR}/papctl "C ${ID} 0 0"
          fi
        done
      fi

      echo ${VSINKS} >/tmp/papctl-vsinks

      echo ${VSINKS} | sed s/","/"\n"/g >/tmp/papctl-list

      cat /tmp/papctl-list | while read SINK ; do
        ID=$(get_vsink_id ${SINK})
 
        if [ ! -z "${ID}" ]; then
          ${DIR}/papctl "O ${ID} 3 0"
        fi
      done
    fi
    ;;

  disconnect)
    touch /tmp/papctl-lock

    if [ -e "/tmp/papctl-vsinks" ]; then
      if [ ! -e "/tmp/papctl-usbmod" ]; then
        cat /tmp/papctl-vsinks | sed s/","/"\n"/g >/tmp/papctl-list

        cat /tmp/papctl-list | while read SINK ; do
          ID=$(get_vsink_id ${SINK})

          if [ ! -z "${ID}" ]; then
            ${DIR}/papctl "C ${ID} 0 0"
          fi
        done
      fi
    fi

    if [ -e "/tmp/papctl-netmod" ]; then
      NET_MODULE=$(cat /tmp/papctl-netmod)

      /usr/bin/pactl unload-module ${NET_MODULE}

      sleep 2
    fi

    rm -f /tmp/papctl-vsinks >/dev/null 2>&1
    rm -f /tmp/papctl-netmod >/dev/null 2>&1
    rm -f /tmp/papctl-server >/dev/null 2>&1
    ;;

  enable)
    touch /tmp/papctl-lock

    if [ ! -e "/tmp/papctl-listen" ]; then
      /usr/bin/pactl load-module module-native-protocol-tcp auth-anonymous=1 >/tmp/papctl-listen

      sleep 2
    fi
    ;;

  disable)
    touch /tmp/papctl-lock

    if [ -e "/tmp/papctl-listen" ]; then
      CUR_LISTEN=$(cat /tmp/papctl-listen)

      /usr/bin/pactl unload-module ${CUR_LISTEN}

      sleep 2
    fi

    rm -f /tmp/papctl-listen >/dev/null 2>&1
    ;;
esac

rm -f /tmp/papctl-list >/dev/null 2>&1
rm -f /tmp/papctl-lock >/dev/null 2>&1

exit 0
