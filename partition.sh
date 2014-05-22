#!/bin/sh
#
# Copyright 2014, Silverio Diquigiovanni <shineworld.software@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

PART_ID_EXTENDED=5
PART_ID_FAT16=6
PART_ID_FAT32=0xb
PART_ID_LINUX=0x83

part_init() {
	if [ $# -ne 1 ]; then
		echo_red "error: missing argument in part_init()"
		exit 1
	fi
	
	PART_DEV=$1
	
	PART_BLOCK_SIZE=1024
	
	PART_BLOCKS="$(sfdisk -s $DEV 2> /dev/null | awk '{print $1}')"
	PART_CYLINDERS="$(sfdisk -g $DEV 2> /dev/null | grep cylinders | awk '{print $2}')"
	PART_HEADS="$(sfdisk -g $DEV 2> /dev/null | grep cylinders | awk '{print $4}')"
	PART_SECTORS="$(sfdisk -g $DEV 2> /dev/null | grep cylinders | awk '{print $6}')"
	
	if [ -z "$PART_BLOCKS" ]; then
		echo_red "error: part_init(), unavailable device blocks info"
		exit 1
	fi
	if [ -z "$PART_CYLINDERS" ]; then
		echo_red "error: part_init(), unavailable device cylinders info"
		exit 1
	fi
	if [ -z "$PART_HEADS" ]; then
		echo_red "error: part_init(), unavailable device heads info"
		exit 1
	fi
	if [ -z "$PART_SECTORS" ]; then
		echo_red "error: part_init(), unavailable device sectors info"
		exit 1
	fi
	
	PART_BLOCKS_CYLINDER=$(( PART_BLOCKS / PART_CYLINDERS ))
	
	PART_CYLINDER_SIZE=$(( PART_BLOCKS_CYLINDER * PART_BLOCK_SIZE ))
	
	PART_SIZE=$(( PART_CYLINDERS * PART_CYLINDER_SIZE ))
	
	PART_CYL_START=0
	PART_DESCRIPTOR=""
}

part_info() {
	echo "device             = $PART_DEV"
	echo "size               = $PART_SIZE bytes"
	echo "block size         = $PART_BLOCK_SIZE bytes"
	echo "cylinder size      = $PART_CYLINDER_SIZE bytes"
	echo "heads              = $PART_HEADS"
	echo "blocks             = $PART_BLOCKS"
	echo "sectors            = $PART_SECTORS"
	echo "cylinders          = $PART_CYLINDERS"
	echo "blocks in cylinder = $PART_BLOCKS_CYLINDER"
}

part_move_start() {
	part_get_aligned_cylinders $1
	PART_CYL_START=$result
}

part_add() {
	part_get_aligned_cylinders $1
	PART_CYL_SIZE=$result
	if [ -z "$PART_DESCRIPTOR" ]; then
		PART_DESCRIPTOR="$PART_CYL_START,$PART_CYL_SIZE,$2,"
	else
		PART_DESCRIPTOR="$PART_DESCRIPTOR\n$PART_CYL_START,$PART_CYL_SIZE,$2,"
	fi
	PART_CYL_START=$(( PART_CYL_START + PART_CYL_SIZE ))
}

part_create_extended() {
	PART_CYL_SIZE=$(( PART_CYLINDERS - PART_CYL_START ))
	if [ -z "$PART_DESCRIPTOR" ]; then
		echo_red "error: part_init(), invalid extended partition position"
	else
		PART_DESCRIPTOR="$PART_DESCRIPTOR\n$PART_CYL_START,$PART_CYL_SIZE,$PART_ID_EXTENDED,"
	fi
	PART_CYL_START=$(( PART_CYL_START + 1 ))
}

part_get_aligned_cylinders() {
	local BLOCKS=$(( ($1 * 1024 + PART_BLOCK_SIZE - 1) / PART_BLOCK_SIZE ))
	local CYLINDERS=$(( (BLOCKS + PART_BLOCKS_CYLINDER - 1) / PART_BLOCKS_CYLINDER ))
	if [ $CYLINDERS -eq 0 ]; then
		CYLINDERS=1
	fi
	result=$CYLINDERS
}

part_do_job() {
	dd if=/dev/zero of=$PART_DEV bs=512 count=1
	echo "$PART_DESCRIPTOR" | sfdisk -f -D -H $PART_HEADS -S $PART_SECTORS -C $PART_CYLINDERS $PART_DEV
}
