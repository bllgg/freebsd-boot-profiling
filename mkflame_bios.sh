#!/bin/sh

# Default values
SCALE=20
EXCLUDE_BIOS=0
BIOS_THRESHOLD=0

# Parse command-line options
while [ "$1" != "" ]; do
    case $1 in
        --scale)
            SCALE=$2
            shift 2
            ;;
        --exclude-bios)
            EXCLUDE_BIOS=1
            shift
            ;;
        *)
            echo "Usage: $0 [--scale <value>] [--exclude-bios]"
            exit 1
            ;;
    esac
done

# Get the last timestamp recorded before switching to user-space
TSCEND=$(sysctl -n debug.tslog_user | grep sh | head -1 | cut -f 4 -d ' ')

# Detect platform and get TSC frequency
case `uname -p` in
    amd64|x86_64)
        TSCFREQ=$(sysctl -n machdep.tsc_freq)
        ;;
    aarch64)
        TSCFREQ=$(sysctl -n "kern.timecounter.tc.ARM MPCore Timecounter.frequency")
        ;;
    *)
        echo "Unsupported platform"
        exit 1
        ;;
esac

# Convert TSC timestamp to milliseconds
MS=$((TSCEND * 1000 / TSCFREQ))

# Determine BIOS threshold if excluding BIOS
if [ "$EXCLUDE_BIOS" -eq 1 ]; then
    BIOS_THRESHOLD=$(sysctl -n debug.tslog_user | awk 'NR==2 {print $4}')
fi

# Process TSLOG data, filtering out BIOS events if necessary
sh tslog.sh | awk -v bios_threshold=$BIOS_THRESHOLD -v exclude_bios=$EXCLUDE_BIOS '
    exclude_bios && $4 < bios_threshold { next }
    { print $0 }
' | 
perl stackcollapse-tslog.pl | 
perl flamechart.pl -flamechart -colors tslog --hash \
    --title "`uname -r | cut -f 1-2 -d -` boot" \
    --subtitle "$MS ms" \
    --width $(echo "$MS / $SCALE" | bc)
