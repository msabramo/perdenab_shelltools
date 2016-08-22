#!/bin/sh
# =============================================================================
# bd            	Backup file(s) with Date appended to name
#
#       Description	Create backup copies of one or more files, with ISO
#			standard date/time appended to the name.
#
#			The backup copy of a file is stored into the same
#			directory as the original, with the same ownership and
#			permissions.
#
#	Usage		bd file [ file .. ]
#
#	Version		1.1	2006-02-11
#
#       Author		perdenab at yahoo dot co dot uk		2001 - 2004
#               	http://uk.geocities.com/perdenab
# =============================================================================

prog="`basename $0`"

die () {
        echo "$prog: FATAL: $1" 1>&2
        exit 1
}

warn () {
        echo "$prog: WARNING: $1" 1>&2
}

usage () {
        echo "usage: $prog file [ file .. ]" 1>&2
        exit 1
}

[ $# = 0 ] && usage

for file in $@ ; do
        if [ ! -f "$file" ] ; then
                warn "$file: missing or not a plain file"
                continue
        fi
        date="`/bin/date '+%Y-%m-%d-%H%M%S'`" || die "can't get date/time"
        nf="$file.$date"
        [ -f "$nf" ] && die "SANITY: $nf exists!"
        cp -p "$file" "$nf"
	if [ $? != 0 ] ; then
		warn "copy of $file to $nf failed"
	else
        	echo "copied $file to $nf"
	fi
done

exit 0

# =============================================================================
# END of bd
# =============================================================================
