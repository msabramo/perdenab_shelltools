#!/bin/sh
# =============================================================================
# brip		Bulk / stream Resolution of IP addresses and hostnames
#
#	Description:
#		A simple IP and hostname resolver that reads hostnames or IPs
#		from stdin or the commandline.  Useful for bulk DNS lookups or
#		quick manual resolution (forward or reverse) from a commandline.
#
#		Hostnames are converted to their corresponding IP addresses.
#		Numeric IP addresses are reverse-looked-up to provide a hostname.
#
#	Version:
#		1.01		2006-02-17
#
#	License:
#		Personalidad de Nabo (C) 2006 -- Freely Distributable
#
# -----------------------------------------------------------------------------
#       WEB USERS PLEASE NOTE:
#
#               If you save this file, please do it as a Save-As operation, and
#               NOT a copy/paste.  This is to preserve embedded tab characters
#               in some of the SED and GREP expressions below, which may otherwise
#		be converted into blanks during copy/paste.
# -----------------------------------------------------------------------------
#
#	Usage:
#		brip [ options ]
#
#			[ -r ]
#			[ -s [ -F separator ] ]
#			[ -R { host | dig | nslookup } ]
#			[ -f inputfile ]
#			[ -v ]
#			[ { ipaddress | hostname } .. ]
#
#		Options:
#
#		-r	Output is in 'hostname<TAB>ipaddress' format, the
#			reverse of the default output (/etc/hosts format)
#
#		-s	Output is in the form of a sed script, which can be
#			used for bulk substitution within existing data (such
#			as a log file).
#
#			If a hostname cannot be resolved in this mode, it is
#			repeated back into the output, but in uppercase.  This
#			is done to offer some (possible) distinction for
#			unresolvable hostnames without changing their value.
#
#		-F separator
#			Used in conjunction with the -s option, to assure
#			proper delineation of hostnames or ipaddresses in data
#			to which the sed substitutions are being applied
#
#		-R resolver
#			Specify a specific resolver, among host, dig or nslookup.
#
#		-v	Run in verbose mode
#
#		-f inputfile
#			Read data from a file.  Any trailing tokens on the
#			commandline will be looked up along with the contents
#			of the file.
#
#		ipaddress, hostname...
#			Any number of IP addresses and/or hostnames can appear
#			on the commandline, and will be forward or reverse
#			resolved as appropriate.  If none are specified on
#			the commandline, they will be read from STDIN.
#
#
#	Error and Alert Notification:
#		Lookup failures are marked with the tag <LOOKUP_FAILED>.
#
#	Logging and Log Maintenance:
#		None
#
#	Files:
#		None
#
#	Year 2000 Compliance
#		N/A
#
#	Remarks:
#		For best results, the "host" program should be installed and
#		in the user's PATH.  However, dig or nslookup will be used (in
#		that order of preference) if either is present.
#
#	Suggested enhancements:
#		None so far.
#
#	Change History:
#		2006-02-17	1.01	- Now look for gawk, nawk then awk
#					- Fixed handling of Windows nslookup
#					  output when run under Cygwin
#					- Correct arg list in usage message
#					- $awk and $egrep now quoted as they
#					  should have been to begin with
#
#		2006-02-15	Initial release -- 1.00
#
#	Author:
#		Personalidad de Nabo
#		perdenab at yahoo dot co dot uk
#		http://uk.geocities.com/perdenab
#
#	Project ID:
#		None
# =============================================================================

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# GLOBAL SETTINGS
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

prog=`basename $0`

tmp="/tmp/.$prog.$$"

verbose=0
rorder=0
sfmt=0
ssep=
resolver=
infiles=

# add others here if you like
knownresolvers="
	host
	dig
	nslookup
"

# get OS name
osname=`uname -a | awk '{print$1}' | tr '[A-Z]' '[a-z]'`

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# FUNCTION SECTION
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#
# die()         Display the message in "$1" to stderr, then quit.
#
die () {
        echo "$prog: FATAL: $1" 1>&2
	rm -f "$tmp"
        exit 1
}

#
# warn()        Display the message in "$1" to stderr.
#
warn () {
        echo "$prog: WARNING: $1" 1>&2
}

#
# notify()      Display the message in "$@" to stdout, but only if $verbose is set
#
notify () {
        [ 1 = "$verbose" ] && echo "$@" 1>&2
}

#
# usage()       Print usage message and quit.
#
usage () {
	echo "usage: $prog [ options ] [ { ipaddress | hostname } .. ]" 1>&2
	echo "" 1>&2
	echo "       Options:" 1>&2
	echo "" 1>&2
	echo "             [ -r ]" 1>&2
	echo "             [ -s [ -F separator ] ]" 1>&2
	echo "             [ -R { host | dig | nslookup } ]" 1>&2
	echo "             [ -f filename ]" 1>&2
	echo "             [ -v ]" 1>&2
	echo "             [ { ipaddress | hostname } .. ]" 1>&2
	echo "             [ -r ]" 1>&2
	exit 1
}

#
# help()	Display the top comment block for this script, to serve
#		as on-line documentation.  Suggest invoking using -h option.
#
help () {
	"$awk" '{if(NR>1)print;if(NF==0)exit(0)}' < "$0" | sed 's/^#//'
}

#
# use_host()	Perform a DNS lookup using the "host" program
#
use_host () {
	"$rbin" "$1" 2>&1 | "$egrep" -i '(^Name:|^Address:|[ 	]A[ 	]|[ 	]exist[ 	]|[ 	]try again)'
}

#
# use_dig()	Perform a DNS lookup using the "dig" program, and tweak the
#		output to look like host's (required by postprocessing functions)
#
use_dig () {
	host=
	addr=
	echo " $1" | grep '[^0-9\. ]' > /dev/null
	if [ $? = 0 ] ; then
		host="$1"
		addr=`"$rbin" "$1" | \
			grep -i "^$host\.[	 ].*[ 	]IN[ 	][ 	]*A[ 	][ 	]*" | \
			"$awk" '{print$NF}'`
	else
		addr="$1"
		revaddr=`echo "$addr" | "$awk" -F. '{printf("%s\\.%s\\.%s\\.%s",$4,$3,$2,$1)}'`
		host=`"$rbin" -x "$1" | \
			grep -i "^$revaddr\.in-addr\.arpa\..*[ 	]IN[ 	][ 	]*PTR[ 	]" | \
			"$awk" '{print$NF}' | \
			sed 's/\.[ 	]*$//' `
	fi
	host=`echo "$host" | "$awk" '{print$1}'`
	addr=`echo "$addr" | "$awk" '{print$1}'`
	if [ -z "$host" -o -z "$addr" ] ; then
		echo "$1 does not exist, try again" 1>&2
	else
		echo "$host	A	$addr"
	fi
}

#
# use_nslookup()
#		Perform a DNS lookup using the "nslookup" program, and tweak the
#		output to look like host's (required by postprocessing functions)
#
use_nslookup () {
	host=
	addr=
	echo " $1" | grep '[^0-9\. ]' > /dev/null
	if [ $? = 0 ] ; then
		host="$1"
		addr=`"$rbin" "$1" 2>/dev/null | \
			"$awk" '{if(NR>2)print}' | \
			"$egrep" -i "^Address:[ 	]" | \
			tail -1 | "$awk" '{print$2}'`
	else
		addr="$1"
		revaddr=`echo "$addr" | "$awk" -F. '{printf("%s\\.%s\\.%s\\.%s",$4,$3,$2,$1)}' 2>&1 | grep -vi "awk: warning"`
		host=`"$rbin" "$1" 2>/dev/null | \
			"$awk" '{if(NR>2)print}' | \
			"$egrep" -i "($revaddr\.in-addr.arpa[ 	][ 	]*name[ 	][ 	]*=[ 	][ 	]*.*\.\$|^Name:)" | \
			"$awk" '{print$NF}' | \
			sed 's/\.[ 	]*$//' `
	fi
	host=`echo "$host" | "$awk" '{print$1}'`
	addr=`echo "$addr" | "$awk" '{print$1}'`
	if [ -z "$host" -o -z "$addr" ] ; then
		echo "$1 does not exist, try again" 1>&2
	else
		echo "$host	A	$addr"
	fi
}

#
# oorder()	Order output based on -r flag
#
oorder () {
	if [ 0 = "$rorder" ] ; then
		cat
	else
		"$awk" '{print$2"\t"$1}'
	fi
}

#
# oformat()	Output in plain or sed-substitution format, based on -s flag
#
oformat () {
	if [ 0 = "$sfmt" ] ; then
		cat
	else
		sed 's/\./\\./g' | "$awk" -v ssep="$ssep" '
		{
			if ($2=="<LOOKUP_FAILED>")
				printf("s/%s%s%s/%s%s%s/g\n",ssep,$1,ssep,ssep,toupper($1),ssep)
			else if ($1=="<LOOKUP_FAILED>")
				printf("s/%s%s%s/%s%s%s/g\n",ssep,$2,ssep,ssep,toupper($2),ssep)
			else
				printf("s/%s%s%s/%s%s%s/g\n",ssep,$1,ssep,ssep,$2,ssep)
		}
		'
	fi
}

#
# chkerr()	Look for BRIP_ERROR flags in the primary preprocessor output.
#		These indicate unexpected output from the resolver.  Display
#		them to the user in a reasonable format, then exit with an error.
#
chkerr () {
	"$awk" -v resolver="$resolver" -v prog="$prog" '
	BEGIN {
		berr=0
	}
	{
		if($1=="BRIP_ERROR") {
			berr=1
			printf("%s: %s(): unexpected output:",prog,resolver) >> "/dev/tty"
			for (i=2;i<=NF;++i)
				printf(" %s",$i) >> "/dev/tty"
			print "\r" >> "/dev/tty"
		}
		else
			print
	}
	END {
		if (berr)
			exit 1
	}
	' || die "$resolver: unexpected error(s)"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# SIGNAL HANDLING
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

trap 'echo "Dying on signal[1]: Hangup" ; exit 1' 1
trap 'echo "Dying on signal[2]: Interrupt" ; exit 2' 2
trap 'echo "Dying on signal[3]: Quit" ; exit 3' 3
trap 'echo "Dying on signal[4]: Illegal Instruction" ; exit 4' 4
trap 'echo "Dying on signal[6]: Abort" ; exit 6' 6
trap 'echo "Dying on signal[8]: Arithmetic Exception" ; exit 8' 8
trap 'echo "Dying on signal[9]: Killed" ; exit 9' 9
trap 'echo "Dying on signal[10]: Bus Error" ; exit 10' 10
# Solaris doesn't like this one
[ sunos != "$osname" ] && trap 'echo "Dying on signal[11]: Segmentation Fault" ; exit 11' 11
trap 'echo "Dying on signal[12]: Bad System Call" ; exit 12' 12
trap 'echo "Dying on signal[13]: Broken Pipe" ; exit 13' 13
trap 'echo "Dying on signal[15]: Dying on signal" ; exit 15' 15
trap 'echo "Dying on signal[30]: CPU time limit exceeded" ; exit 30' 30
trap 'echo "Dying on signal[31]: File size limit exceeded" ; exit 31' 31

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# ARG AND SANITY CHECKS
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#
# first get args
#

while getopts srF:R:f:v c ; do
        case $c in
        r)      rorder=1
                ;;
        s)      sfmt=1
                ;;
        F)      ssep="$OPTARG"
                ;;
        R)      fres="$OPTARG"
                ;;
        f)      infiles="$infiles $OPTARG"
                ;;
        v)      verbose=1
                ;;
        *)      usage
                ;;
        esac
done
shift `expr $OPTIND - 1`
otherargs="$@"

#
# some basic sanity checks and settings based partly on args
#

# make sure a decent version of awk is used, particularly on Suns
gawk=`which gawk 2>/dev/null`
if [ $? != 0 -o -z "$gawk" ] ; then
	nawk=`which nawk 2>/dev/null`
	if [ $? != 0 -o -z "$nawk" ] ; then
		awk="awk"
	else
		awk="$nawk"
	fi
else
	awk="$gawk"
fi
notify "awk          = $awk"

# use the correct egrep command for this system
egrep=
for g in /usr/xpg4/bin/egrep /usr/local/bin/egrep /opt/sfw/bin/egrep /bin/egrep /usr/bin/egrep ; do
	notify "checking $g"
	if [ -x "$g" ] ; then
		egrep="$g"
		break
	fi
done
if [ -z "$egrep" ] ; then
	egrep=`which egrep 2>/dev/null`
	[ $? != 0 -o -z "$egrep" ] && die "no egrep command found on this system"
fi
notify "egrep        = $egrep"

if [ ! -z "$ssep" ] ; then
	if [ 0 = "$sfmt" ] ; then
		warn "the -F option can be used only in conjunction with -s"
		usage
	fi
	if [ -z "$ssep" ] ; then
		warn "no separator supplied with -F"
		usage
	fi
fi

for file in $infiles ; do
	[ -r "$file" ] || die "$file: missing or inaccessible"
done

#
# decide which resolver to use
#

if [ -z "$fres" ] ; then
	rbinok=0
	for r in $knownresolvers ; do
		rbin=`which $r 2>/dev/null` || continue
		case $rbin in
		"")	continue
			;;
		/*)	rbinok=1
			break
			;;
		*)	warn "SANITY: 'which $r' returned '$rbin' -- skipping"
			;;
		esac
	done
	[ 0 = "$rbinok" ] && die "none of the following resolver programs were found in your PATH: `echo $knownresolvers`"
	case $rbin in
	*/host)	resolver="use_host"
		;;
	*/dig)	resolver="use_dig"
		;;
	*/nslookup)
		resolver="use_nslookup"
		;;
	*)	die "INTERNAL ERROR: \$rbin=$rbin"
		;;
	esac
else
	fbase=`basename "$fres"`
	kf=0
	for r in $knownresolvers ; do
		if [ "$r" = "$fbase" ] ; then
			kf=1
			break
		fi
	done
	[ 0 = "$kf" ] && die "the -R option must specify one of the following: `echo $knownresolvers`"
	case $fres in
	/*)	rbin="$fres"
		[ -x "$fres" ] && die "$fres: missing or inaccessible"
		;;
	*)	rbin=`which "$fres" 2>/dev/null`
		[ $? != 0 -o -z "$rbin" ] && die "$fres: not in PATH"
		;;
	esac
	resolver="use_$fbase"
fi

[ -z "$resolver" ] && die "INTERNAL ERROR: \$resolver: not set"

#
# chatty startup messages if we're running verbosely
#

if [ -z "$infiles" ] ; then
	if [ $# -gt 0 ] ; then
		notify "data source  = commandline"
	else
		notify "data source  = STDIN"
	fi
else
	notify "data source  = file(s): $infiles"
fi
notify "resolver     = $rbin"
case $rorder in
0)	notify "output order = ipaddr, hostname"
	;;
1)	notify "output order = hostname, ipaddr"
	;;
esac
case $sfmt in
0)	notify "output mode  = text"
	;;
1)	notify "output mode  = sed"
	;;
esac

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# MAIN SECTION
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if [ -z "$infiles" ] ; then
	if [ $# = 0 ] ; then
		cat > "$tmp"
	else
		echo $@ > "$tmp"
	fi
else
	(echo $@ ; cat $infiles) > "$tmp"
fi

for i in `cat < "$tmp"` ; do
	$resolver "$i" 2>&1
done | "$awk" -v verbose="$verbose" -v resolver="$resolver" '
{
	if (verbose)
		printf("+ %s()\t%s\r\n",resolver,$0) >> "/dev/tty"
	if ($1=="Name:")
		name=$2
	else if ($1=="Address:")
		printf("%s\t%s\n",$2,name)
	else if ($2=="A")
		printf("%s\t%s\n",$3,$1)
	else if (($2=="does"&&$3=="not")||$NF=="again") {
		c1=substr($1,1,1)
		if ((c1>=1)&&(c1<=9))
			printf("%s\t%s\n",$1,"<LOOKUP_FAILED>")
		else
			printf("%s\t%s\n","<LOOKUP_FAILED>",$1)
	}
	else if (NF)
		print "BRIP_ERROR\t"$0
}
' | chkerr | oorder | oformat

#
# clean up and quit
#

rm -f "$tmp"

exit 0

# =============================================================================
# END of brip
# =============================================================================
