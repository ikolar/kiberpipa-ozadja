#! /usr/bin/env bash
#
# This script generates a PNG file of upcoming events in kiberpipa
# Modeled after rd666's original script, changelog:
#  - migrated from mysql to postgres
#  - minor cleanup
#  - this header with documentation
#
# How it works is:
# 1. it connects to the i3 database and retrieves all future public (!= 11) events
# 2. takes the top 6 (head -6) of those
# 3. checks the dates, and marks tuesdays' events as POTS, and wednesdays' as SUs
# 4. writes that to a file named "text" (why, almir, why"
# 5. loops through that file, and uses imagemagics's convert and composite to generate the png
# 6. the png is left at a standard location, and is retrieved from there by the terminals
# 7. run everything from cron
#
# Updates:


WEBROOT="$HOME/public_html/ozadja/"
PATH="/usr/bin:/bin"
cd $WEBROOT
# cleanup from previous runs
rm -f images/program.png tmp.png program.png

# 1. dobi ven vse evente za ta teden iz intranetove baze
#'SELECT start_date, title FROM intranet2.org_event WHERE project_id != 11 AND start_date > CURDATE() AND start_date < CURDATE() + INTERVAL 7 DAY and project_id != 11 order by start_date asc;' | 
/usr/lib/postgresql/8.3/bin/psql -p 5433 -U i3 i3 -c "SELECT start_date, title from org_event where start_date > NOW() order by start_date asc;" |
# cleanup (remove the first 2, last 2 line -- both junk, and trim lines)
sed -e '1,2d; $d' | sed -e '$d' | sed -re 's/^\s+//; s/\s+$//' | tee events_orig.txt | 

# 2. take the top X events
head -6 |

# 3. ugly code that pre-fixes pot's and su's with SU: or POT:
while read -a date; do 
	if [[ $(date +%a -d "${date[0]}") == 'Wed' && "${date[1]}" == "19:00:00" ]]; then 
		prefix=" SU:  " 
	elif [[ $(date +%a -d "${date[0]}") == 'Tue' && "${date[1]}" == "19:00:00" ]]; then 
		prefix=" POT: "
#	else 
#		prefix=$'\b' ##a failed attempt to do an ugly ugly ugly hack (remove extra space infront of events not pre-fixed with POT or SU), now has historical value :)
	fi


	days=(Ned Pon Tor Sre Čet Pet Sob)
	line="${days[`date '+%w' -d ${date[0]}`]}."$'\a'"$prefix"$'\a'"${date[@]}"
	
	echo "$line"
	unset prefix	
	done |

# 4. write "text" file
sed -r -e 's/^(.*)\a(.*)\a[0-9]*-([0-9]*)-([0-9]*) *([0-9]*:[0-9]*):[0-9]*(\+[0-9]{2})/\1 \4.\3 \5/' > text #(POT: |SU: )?2007-02-06 15:00:00 -- 06.02.2007 15:00 (POT: |SU: )? ###update me
#sort -k 2 > text

# convert settings
font="$WEBROOT/FreeSansBold.ttf"
x=55
y=250
i=0
convert -pointsize 25 -fill '#FFC73B' -draw "text $x,$((y-25)) 'PRIHAJAJOČI DOGODKI'" -font "$font" template.png tmp.png 

# 5. write the events names unto the image (tmp.png)
while read event;  do #ne odpre sub shella
	((y+=45))
	if ((i%2)); then
		color='#FFFFFF'
	else
		color='#F5FF97'
	fi

	event="$(echo -n "$event" | sed -r 's/(.{70,})[,:](.*)/\1\n                           \2/')" 
	
	
	if [[ $event == *$'\n'* ]]; then
		convert -font "$font" -fill "$color" -pointsize 20 -draw "text $x, $y '${event%%$'\n'*}'" tmp.png tmp1.png
		mv tmp1.png tmp.png
		convert -font "$font" -fill "$color" -pointsize 20 -draw "text $x, $((y+=25)) '${event##*$'\n'}'" tmp.png tmp1.png
		
	else
		convert -font "$font" -fill "$color" -pointsize 20 -draw "text $x, $y '$event'" tmp.png tmp1.png
	fi
	
	
	mv tmp1.png tmp.png
	((i++))
done < text


((x+=45))

# 6. put "program.png" in a std. location
#rabis -font ker ce ne dogbert pizdi, na jonu dela.
convert -fill '#FFFFFF' -pointsize 22 -draw "text $x,$((y+80)) 'Vstop na vse dogodke iz programa je prost,'" \
	-fill '#FFFFFF' -pointsize 22 -draw "text $((x+93)), $((y+104)) 'več na '" \
	-fill '#FFC73B' -draw "text $((x+168)), $((y+104)) 'www.kiberpipa.org'" \
	-font "$font"  tmp.png images/program.png


# cleanup 
rm -f tmp.png program.png text events_orig.txt
