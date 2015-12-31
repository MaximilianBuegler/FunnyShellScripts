#!/bin/bash

outputpath="conv/"

function getStreamLine()
{
codetype=$1
codecname=$2
channels=$3
language=$4
audiocounter=$5
subtitlecounter=$6
                                case $codectype in
                                        "audio")
                                                case $codecname in
                                                        "mp3")
                                                                echo copying $codecname audio track with $channels channels >&2
                                                                echo -map 0:a:$audiocounter -metadata:s:a:$audiocounter language=$language -c:a:$audiocounter copy
                                                                ;;
                                                        "ac3")
                                                                if [ $channels != "6" ]
                                                                then
                                                                        echo encoding $codecname audio track with $channels channels to 192k mp3 >&2
                                                                        echo -map 0:a:$audiocounter -metadata:s:a:$audiocounter language=$language -c:a:$audiocounter libmp3lame -b:a:$audiocounter 192k
                                                                else
                                                                        echo copying $codecname audio track with $channels channels >&2
                                                                        echo -map 0:a:$audiocounter -metadata:s:a:$audiocounter language=$language -c:a:$audiocounter copy
                                                                fi
                                                                ;;
                                                        *)
                                                                if [ $channels != "6" ]
                                                                then
                                                                        echo encoding $codecname audio track with $channels channels to 192k mp3 >&2
                                                                        echo -map 0:a:$audiocounter -metadata:s:a:$audiocounter language=$language -c:a:$audiocounter libmp3lame -b:a:$audiocounter 192k
                                                                else
                                                                        echo encoding $codecname audio track with $channels channels to 640k ac3 >&2
                                                                        echo -map 0:a:$audiocounter -metadata:s:a:$audiocounter language=$language -c:a:$audiocounter ac3 -b:a:$audiocounter 640k
                                                                fi
                                                                ;;


                                                esac
                                        ;;
					"subtitle")
						echo copying $codecname subtitle >&2
						echo -map 0:s:$subtitlecounter -c:s:$subtitlecounter copy
						;;
                                esac

}

for path in "$@"
do
    echo
    echo PROCESSING $path
    filename=$(echo "$path" | grep -oP "[^/]*$")
    ffmpegcommand=""

    audiocounter=0
    subtitlecounter=0

    codecname=-2
    codectype=""
    channels=""
    language="und"
    state=0
    width=1280
    ffprobe -v error -of default=noprint_wrappers=1 -show_entries "stream=index,channels,codec_type,codec_name,width : stream_tags=language" "$path" < /dev/null | ( while read a;
	do
	 	if [ $state -eq 0 ]
			then
				case $(echo $a | cut -d"=" -f1) in
					"codec_name")
						codecname=$(echo $a | cut -d"=" -f2)
						;;
					"codec_type")
						codectype=$(echo $a | cut -d"=" -f2)
						;;
					"channels")
						channels=$(echo $a | cut -d"=" -f2)
                                                ;;
					"width")
						width=$(echo $a | cut -d"=" -f2)
						;;
					"TAG:language")
						language=$(echo $a | cut -d"=" -f2)
						;;
					"index")
						if [ $codecname != "-2" ]
						then
							state=1
						fi
						;;
				esac
		fi
		if [ $state -eq 1 ]
			then
				ffmpegcommand="$ffmpegcommand $(getStreamLine $codectype $codecname $channels $language $audiocounter $subtitlecounter)"
				case $codectype in
					"audio")
						audiocounter=$(($audiocounter + 1))
						;;
                                       	"subtitle")
                                                subtitlecounter=$(($subtitlecounter + 1))
                                                ;;
				esac
				state=0
			fi
	done
	ffmpegcommand="$ffmpegcommand $(getStreamLine $codectype $codecname $channels $language $audiocounter $subtitlecounter)"
	metadatamodifier="-map_metadata -1 -map_chapters 0"
	echo $metadatamodifier
	if [ $width -gt 1280 ]
		then
		        echo ffmpeg -i "$path" $metadatamodifier -metadata title="${filename%.*}" -map 0:v:0 -vf "scale='min(iw,1280)':'trunc(ow/a/2)*2'" -c:v:0 libx264 -preset medium -crf 22 $ffmpegcommand "${outputhpath}$filename" 
		        ffmpeg -i "$path" $metadatamodifier -metadata title="${filename%.*}" -map 0:v:0 -vf "scale='min(iw,1280)':'trunc(ow/a/2)*2'" -c:v:0 libx264 -preset medium -crf 22 $ffmpegcommand "${outputpath}$filename" </dev/null 
		else
                        echo ffmpeg -i "$path" $metadatamodifier -metadata title="${filename%.*}" -map 0:v:0 -c:v:0 libx264 -preset medium -crf 22 $ffmpegcommand "${outputhpath}$filename" 
                        ffmpeg -i "$path" $metadatamodifier -metadata title="${filename%.*}" -map 0:v:0 -c:v:0 libx264 -preset medium -crf 22 $ffmpegcommand "${outputpath}$filename" </dev/null 
		fi )

done

