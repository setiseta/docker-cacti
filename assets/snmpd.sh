#!/bin/bash

exec /usr/sbin/snmpd >>/var/log/snmpd.log 2>&1
