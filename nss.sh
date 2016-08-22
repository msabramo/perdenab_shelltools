#!/bin/sh
# =============================================================================
# nss		New Shell Script
#
#	Version:
#		1.03
#
#	Description:
#		For each name in $@, create a new executable file containing
#		the following:
#
#		- skeletal head and tail comments; can be completed by the user
#		- a few basic functions like die() and usage()
#		- a getopts section that the user can easily modify
#		- signal handling stubs
#
#		If the filename begins with / , use that filename literally.
#		If there is no initial / , then place it into $defbin.
#
#		If a name already exists, no file is created.
#
#	Primary Application:
#		Unix shell script development.  Create initial (empty)
#		script with standardized command header, to be edited
#		by programmer.
#
#	Usage:
#		nss scriptname [scriptname...]
#
#	Error and Alert Notification:
#		Error messages to user terminal if needed files/dirs missing.
#
#	Logging and Log Maintenance:
#		N/A
#
#	Files:
#		Output script $defbin/scriptname
#
#	Year 2000 Compliance:
#		4 digit date in creation timestamp.
#
#	Remarks:
#		Speed up and standardize the script creation process
#		just a smidge.
#
#	Suggested enhancements:
#		Write the entire script for us, not just the framework :)
#
#	Changes:
#		Sun Mar 27 06:39:47 BST 2005	1.02 -> 1.03
#			-- Added tmpclean, and calls to it in signal handling
#			-- Notify now writes to stderr
#		Wed Oct 13 21:30:04 BST 2004	1.01 -> 1.02
#			-- Added verbose option and notify function
#			-- Added getopts section
#			-- Added nawk check
#			-- Some code cleanup
#		Thu Apr  1 08:53:22 EST 1999	1.00 -> 1.01
#			-- Added skeletal help, usage, warn and die functions.
#
#	Author:
#		perdenab at yahoo dot co dot uk			1998 - 2004
#               http://uk.geocities.com/perdenab
# =============================================================================

#
# global settings
#
prog=`basename $0`
defbin=$HOME/bin

#
# arg and sanity checks
#
if [ $# -eq 0 ] ; then
	echo "usage: $prog scriptname [scriptname...]" 1>&2
	exit 1
fi

if [ "x$defbin" = x ] ; then
	echo "$prog: SANITY: defbin is not set" 1>&2
	exit 1
fi

for file in $@; do
	case "$file" in
	/*)	;;
	*)	file="$defbin/$file" ;;
	esac
	if [ -f $file ] ; then
		echo "$prog: ERROR: $file already exists -- skipping" 1>&2
		continue
	fi
	cat /dev/null > $file
	if [ $? != 0 ] ; then
		echo "$prog: ERROR: can't create $file -- skipping" 1>&2
		continue
	fi
	sfn=`basename $file`
	cat << EOF > $file
#!/bin/sh
# =============================================================================
# $sfn		SHORT DESCRIPTION
#
#	Version:
#		1.00
#
#	Description:
#		LONG DESCRIPTION
#
#	Primary Application:
#		What do we mainly use this script for?
#
#	Usage:
#		$sfn [ARGS]
#
#	Error and Alert Notification:
#		How do we notify the user of error and alert conditions?
#
#	Logging and Log Maintenance:
#		Where are the logs (if any) ?  How do we manage, prune
#		and archive them (if applicable) ?
#
#	Files:
#		What config or other files are used by this script?
#		Default config file is /home01/dcssec/etc/$sfn.conf .
#
#	Year 2000 Compliance
#		If applicable, outline here
#
#	Remarks:
#		Various helpful comments
#
#	Suggested enhancements:
#		Features / performance we should add later
#
#	Change History:
#
#	Author:
#		$LOGNAME@`hostname`				`date '+%m/%d/%Y'`
#
#	Project ID:
#		Applicable project number(s)
# =============================================================================

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# GLOBAL SETTINGS
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# name of this program
prog=\`basename \$0\`

# we print chatty messages by default
verbose=1

# a tempfile in case you need one
tmp="/tmp/.\$prog.\$\$"

# making sure a decent version of awk is used on Suns; use \$awk if you wish
if [ -x "/usr/bin/nawk" ] ; then
	awk="/usr/bin/nawk"
else
	awk=awk
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# FUNCTION SECTION
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#
# die()         Display the message in "\$1" to stderr, then quit.
#
die () {
        echo "\$prog: FATAL: \$1" 1>&2
	tmpclean
        exit 1
}

#
# warn()        Display the message in "\$1" to stderr.
#
warn () {
        echo "\$prog: WARNING: \$1" 1>&2
}

#
# notify()      Display the message in "\$@" to stderr, but only if \$verbose is set
#
notify () {
        [ 1 = "\$verbose" ] && echo "\$@"
}

#
# usage()       Print usage message and quit.
#
usage () {
	echo "usage: \$prog [ options ]" 1>&2
	tmpclean
	exit 1
}

#
# tmpclean()    Clean up temp files.  Edit to suit.
#
tmpclean () {
	rm -f "\$tmp"
}

#
# help()	Display the top comment block for this script, to serve
#		as on-line documentation.  Suggest invoking using -h option.
#
help () {
	\$awk '{if(NR>1)print;if(NF==0)exit(0)}' < "\$0" | sed 's/^#//'
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# SIGNAL HANDLING
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

trap 'echo "Dying on signal[1]: Hangup" ; tmpclean ; exit 1' 1
trap 'echo "Dying on signal[2]: Interrupt" ; tmpclean ; exit 2' 2
trap 'echo "Dying on signal[3]: Quit" ; tmpclean ; exit 3' 3
trap 'echo "Dying on signal[4]: Illegal Instruction" ; tmpclean ; exit 4' 4
trap 'echo "Dying on signal[6]: Abort" ; tmpclean ; exit 6' 6
trap 'echo "Dying on signal[8]: Arithmetic Exception" ; tmpclean ; exit 8' 8
trap 'echo "Dying on signal[9]: Killed" ; tmpclean ; exit 9' 9
trap 'echo "Dying on signal[10]: Bus Error" ; tmpclean ; exit 10' 10
trap 'echo "Dying on signal[12]: Bad System Call" ; tmpclean ; exit 12' 12
trap 'echo "Dying on signal[13]: Broken Pipe" ; tmpclean ; exit 13' 13
trap 'echo "Dying on signal[15]: Dying on signal" ; tmpclean ; exit 15' 15
trap 'echo "Dying on signal[30]: CPU time limit exceeded" ; tmpclean ; exit 30' 30
trap 'echo "Dying on signal[31]: File size limit exceeded" ; tmpclean ; exit 31' 31
# Solaris doesn't like trap 11
[ ! -f /usr/bin/nawk ] && trap 'echo "Dying on signal[11]: Segmentation Fault" ; tmpclean ; exit 11' 11

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# ARG AND SANITY CHECKS
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

while getopts f:vq c ; do
        case \$c in
        f)      file=\$OPTARG
                ;;
        v)      verbose=1
                ;;
        q)      verbose=0
                ;;
        *)      usage
                ;;
        esac
done
shift \`expr \$OPTIND - 1\`
otherargs="\$@"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# MAIN SECTION
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

notify "This is new shell script created by $prog."
notify "It has evidently not yet been edited."

echo ""
echo "file=\$file"
echo "otherargs=\$otherargs"
echo "verbose=\$verbose"
echo ""

help | \${PAGER-more}

(usage)

notify "testing the notify() function"

warn "testing the warn() function"

die "testing the die() function"

# =============================================================================
# END of $sfn
# =============================================================================
EOF
	if [ $? != 0 ] ; then
		echo "$prog: ERROR: couldn't create $file -- skipping" 1>&2
		continue
	fi
	chmod 750 $file
	if [ $? != 0 ] ; then
		echo "$prog: ERROR: can't set permissions on $file" 1>&2
		continue
	fi
	echo Created new shell script \"$file\"
done

exit 0

# =============================================================================
# END of nss
# =============================================================================
