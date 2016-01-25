#!/bin/bash

#converts a video or a list of videos to the specified outputpath
#videos supplied by parameters
#
#Tested with:
#   ffmpeg version N-75480-ge859a3c
#   ffmpeg version 2.6.2
#   ffmpeg version 2.8.3
#
#Example: ./converter.sh *.mkv
#
#Input files should already have proper naming for correct metadata of output
#
#drops all but the first video stream
#forces first video stream to be stream 0
#converts all videos to mkv
#converts all videos to a maximum resoltion of 720p
#converts all videos to libx264 with constant rate factor CRF 22 at Preset Medium
#converts all stereo (or anything that is != 6 channels) audio tracks to mp3 192k unless already mp3 or ac3
#converts all 6 channel audio tracks to ac3 640k unless already ac3
#copies all subtitle streams
#drops dvb_teletext subtitles because of incompatibility
#strips all metadata, except chapters
#sets metadata title to filename without extension
#copies over all language tags for audio and subtitle streams

#Path where converted files are stored
outputpath="conv/"


#get the ffmpeg codec line for a given stream
#parameters codectype, codecname, channels, language, audio stream counter, video stream counter
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
	                                echo copying $codecname audio track with $channels channels >&2
	                                echo -map 0:a:$audiocounter -metadata:s:a:$audiocounter language=$language -c:a:$audiocounter copy
		                ;;
			        *)
		                        if [ $channels != "6" ]
		                        then
		                                echo encoding $codecname audio track with $channels channels to 320k mp3 >&2
		                                echo -map 0:a:$audiocounter -metadata:s:a:$audiocounter language=$language -c:a:$audiocounter libmp3lame -b:a:$audiocounter 320k
		                        else
		                                echo encoding $codecname audio track with $channels channels to 640k ac3 >&2
		                                echo -map 0:a:$audiocounter -metadata:s:a:$audiocounter language=$language -c:a:$audiocounter ac3 -b:a:$audiocounter 640k
		                        fi
		                ;;
		        esac
		        ;;
		"subtitle")
			if [ $codecname == "dvb_teletext" ]
			then
				echo dropping $codecname subtitle because it is incompatible >&2
			else
				echo copying $codecname subtitle >&2
				echo -map 0:s:$subtitlecounter -metadata:s:s:$subtitlecounter language=$language -c:s:$subtitlecounter copy
			fi
		;;
	esac
}

#For all arguments
for path in "$@"
do
    echo
    echo PROCESSING $path

    #Strip away path
    filename=$(echo "$path" | grep -oP "[^/]*$")

    #Strip away extension
    videoname=${filename%.*}

    #Intialize string for stream commands
    ffmpegcommand=""

    #Initialize Stream counters
    audiocounter=0
    subtitlecounter=0

    #Initialize Stream data
    codecname=-2
    codectype=""
    channels=""

    #Default language is undefined
    language="und"

    #Width of videostream
    width=1280

    #State to tell whether the first stream data is in
    state=0

    #Output of following ffprobe command looks something like this:
	#index=0
	#codec_name=h264
	#codec_type=video
	#width=1920
	#index=1
	#codec_name=ac3
	#codec_type=audio
	#channels=6
	#TAG:language=deu
	#index=2
	#codec_name=ac3
	#codec_type=audio
	#channels=2
	#TAG:language=eng

    #Probe file and process output line wise
    ffprobe -v error -of default=noprint_wrappers=1 -show_entries "stream=index,channels,codec_type,codec_name,width : stream_tags=language" "$path" < /dev/null | ( while read a;
	do
		#If first stream was not yet read we are in state 0
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
                                        if [ $codectype == "video" ] #Only the width of the video stream is of interest
                                        then
                                                if [ $width -lt 0 ] #Only the first video stream's width is taken into account
                                                then
                                                        width=$(echo $a | cut -d"=" -f2)
                                                fi
                                        fi
				;;
				"TAG:language"|"TAG:LANGUAGE")
					language=$(echo $a | cut -d"=" -f2)
				;;
				"index")

					# Sometimes ffprobe outputs the list of streams twice, while only the second one has full metadata
					# This means index=0 appears twice. We only care about the second bunch of output, so reset when index=0 occurs
					if [ $(echo $a | cut -d"=" -f2) -eq 0 ]
					then
						ffmpegcommand=""
						audiocounter=0
						subtitlecounter=0
						codecname=-2
					fi

					if [ $codecname != "-2" ] #If the index keyword appears the second time, we have read the data of a stream
					then
						state=1
					fi
				;;
				esac
		fi

		#If data for a stream has been read we add the stream line to the command line
		if [ $state -eq 1 ]
		then
			ffmpegcommand="$ffmpegcommand $(getStreamLine $codectype $codecname $channels $language $audiocounter $subtitlecounter)"

			#We increment the stream counter, as unfortunately ffprobe does only tell us the total index, not the stream type index
			case $codectype in
				"audio")
					audiocounter=$(($audiocounter + 1))
				;;
                               	"subtitle")
                                        subtitlecounter=$(($subtitlecounter + 1))
                                ;;
			esac

			#We default to undefined language and go back to state 0
			language="und"
			state=0
		fi
	done

	#We add the data of the last stream
	ffmpegcommand="$ffmpegcommand $(getStreamLine $codectype $codecname $channels $language $audiocounter $subtitlecounter)"

	#We add modifiers to drop all metadata except chapters
	metadatamodifier="-map_metadata -1 -map_chapters 0"

	#Does the video have higher resolution thatn 720p?
	if [ $width -gt 1280 ]
	then
		echo scaling video from width $width to width 1280
	        echo ffmpeg -i \"$path\" $metadatamodifier -metadata title=\"$videoname\" -map 0:v:0 -vf "scale='min(iw,1280)':'trunc(ow/a/2)*2'" -c:v:0 libx264 -preset medium -crf 22 $ffmpegcommand \"${outputpath}$videoname.mkv\" 
	        ffmpeg -i "$path" $metadatamodifier -metadata title="$videoname" -map 0:v:0 -vf "scale='min(iw,1280)':'trunc(ow/a/2)*2'" -c:v:0 libx264 -preset medium -crf 22 $ffmpegcommand "${outputpath}$videoname.mkv" </dev/null 
	else
                echo ffmpeg -i \"$path\" $metadatamodifier -metadata title=\"$videoname\" -map 0:v:0 -c:v:0 libx264 -preset medium -crf 22 $ffmpegcommand \"${outputpath}$videoname.mkv\" 
                ffmpeg -i "$path" $metadatamodifier -metadata title="$videoname" -map 0:v:0 -c:v:0 libx264 -preset medium -crf 22 $ffmpegcommand "${outputpath}$videoname.mkv" </dev/null 
	fi )

done

