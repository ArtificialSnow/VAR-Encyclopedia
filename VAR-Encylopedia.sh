#!/bin/bash


#Calls the functions which should run once, at the start of execution
function setUp() {

        createFileDirectory
        displayWelcomeMessage
}


#Creates the files which store creations and other files
function createFileDirectory() {

    if [ ! -d "Creations" ]; then
            mkdir Creations
            mkdir -p Creations/.TextFiles
            mkdir -p Creations/.AudioFiles
    fi
}


function displayWelcomeMessage() {

    echo "=============================================================="
    echo "	   Welcome to the Wiki-Speak Authoring Tool"
    echo "=============================================================="
    echo
}


#Displays the menu and requests user input which will be used to select which function to call
function menu() {

        echo "Please select from one of the following options:"
        echo "		(l)ist existing creations"
        echo "		(p)lay an existing creation"
        echo "		(d)elete an existing creation"
        echo "		(c)reate a new creation"
        echo "		(q)uit authoring tool"
        read -p "Enter a selection [l/p/d/c/q]: " userSelection

        if [[ $userSelection =~ (^([lL]|[pP]|[dD]|[cC]|[qQ])$){1} ]]; then
                return 0
        else
                return 1
        fi
}


#Calls the menu function until the user enters valid input
function getCommandToExecute() {

        menu

        while [ $? -eq 1 ]; do
        
                echo
                echo "Invalid value, please enter one of the specified values"
                echo
                
                menu
        done
        
        echo
}


#Uses the user input to select which function to run
function executeCommand() {

        if [[ $userSelection =~ (^([lL])$){1} ]]; then
                listCreations
                
                if [ $? -eq 0 ]; then
                    read -p "Enter any value to continue: "
                fi

        elif [[ $userSelection =~ (^([pP])$){1} ]]; then
                playCreation

        elif [[ $userSelection =~ (^([dD])$){1} ]]; then
                deleteCreation

        elif [[ $userSelection =~ (^([cC])$){1} ]]; then
                createNewCreation

        elif [[ $userSelection =~ (^([qQ])$){1} ]]; then
                exit 0
        fi
}


#Calls the individual functions necessary for creating a new creation
function createNewCreation() {
        
        getWikipediaSearch
        
        #If the user does not want to quit, continue with the rest of the creation process
        if [ $? -eq 0 ]; then
            	
		#Set path to files which will be used for the creation
		textFile="${pathToTextFiles}/${wikipediaSearch}.txt"
		audioFile="${pathToAudioFiles}/${wikipediaSearch}.${audioExtension}"
	
		displaySearchResult
		getNumberOfLines
		createAudioFile
		getCreationName
		createVideo
        fi
}


#Gets the wikipedia search term from the user, and checks if content for it exists on wikipedia
function getWikipediaSearch() {
                
        read -p "Please enter a term to search on wikipedia, or q to quit: " wikipediaSearch
        echo
        
        #If the user has requested to quit, return from the function with error status 1
        if [[ $wikipediaSearch =~ (^([qQ])$){1} ]]; then
        
		return 1
        fi
        
        
        searchResult=`wikit  $wikipediaSearch`
    
        #While the users input is not on wikipedia, request another search term
        while  grep -q "$search not found :^(" <<< $searchResult ; do
                
                echo "No wikipedia page found for $wikipediaSearch"
                read -p "Please enter a term to search on wikipedia, or q to quit: " wikipediaSearch
                echo
                
                
                #If the user has entered q or Q, return from the function with error status 1
                if [[ $wikipediaSearch =~ (^([qQ])$){1} ]]; then
                
                    return 1
                fi
                
                searchResult=`wikit  $wikipediaSearch`
        done
}


#Displays the search result from wikipedia, and saves it into a text file for future use
function displaySearchResult() {

        local tempWord
        local wikipediaLines
        
        #Resets the text file (by writing over it), and writes the search term to it
        echo -e "$wikipediaSearch." > "${textFile}"
        
        #Splits the search result onto new lines
        wikipediaLines=`sed 's/\([.?!]\)/\1\n/g' <<< $searchResult`

        
        echo -n "$((lineCount = 1))."
        
        for word in $wikipediaLines; do

		#remove spaces surrounding the word
                word=`tr -d '*([[:space:]])' <<< $word`	

                if [[ $tempWord =~ ^.*\.$ ]]; then

                        echo $tempWord | tee -a "${textFile}"

                        echo -n "$((++lineCount)). "

                else

                        echo -n "$tempWord " | tee -a "${textFile}"
                fi

                tempWord="$word"
        done
        
        echo "$word" | tee -a "${textFile}"
        echo
}


#Gets the user to input the number of lines to be read out in the creation and checks if valid
function getNumberOfLines() {

        read -p "Select the number of lines to be read [1-$((lineCount))]: " numberOfLines

        while (( numberOfLines < 1  ||  numberOfLines > lineCount )); do

                echo "Invalid number of lines"
                read -p "Select the number of lines to be read: " numberOfLines
        done 
}


#Uses the text file containing the wikipedia output, create the audio for the creation
function createAudioFile() {

	#Overwrite the text file with only the number of lines to be read
	#Take one more than the number of lines, as the first line is the search term
        echo `cat "${textFile}" | head -$((numberOfLines + 1))` > "${textFile}"

	#create the audio file
        espeak -f "${textFile}" -w "${audioFile}"
}


#Gets the user to input a name for the creation, if the name is the same as an existing creation it asks whether or not they want to override it
function getCreationName() {
	
	local overrideDecision
	
        read -p "Please enter a name for your creation: " creationName
        echo

        while [ -e "./Creations/$creationName.avi" ]; do

                echo "Creation already exists with that name"

                read -p "Would you like to override the existing creation? [y / any other key]: " overrideDecision
                echo
                

		if [[ $overrideDecision =~ (^([yY])$){1} ]] || [[ $overrideDecision =~ (^([yY][eE][sS])$){1} ]]; then
                
                    return 1
                fi


                read -p "Please enter a name for your creation: " creationName
        	echo
        done
}


#Makes the visual part of the video, then combines both visual and aural parts into the final creation
function createVideo() {

	local visualOnlyVideo="./Creations/$wikipediaSearch.mp4"
	local finalCreation="./Creations/$creationName.avi"
	
	local length=`soxi -D "${audioFile}"`
	
	#Makes the visual part of the video
        ffmpeg -y -f lavfi -i color=c=blue:s=320x240:d=$length -vf "drawtext=fontsize=30:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2:text='$wikipediaSearch'" "${visualOnlyVideo}" &> /dev/null
        
	#Combines the video and audio into a new video	
	ffmpeg -y -i "${visualOnlyVideo}" -i "${audioFile}" -map 0:v -map 1:a "${finalCreation}" &> /dev/null

	#Removes the temporary visual only video
        rm "${visualOnlyVideo}"
        
}


#Displays creations to the user
function listCreations() {
        
	numberOfCreations=0

	#Splits then sorts only the names of the creations into an array 
        creationsArray=(`ls -1 ./Creations | sort | grep ".*\.avi" | sed 's/\..*$//'`)
        
        if [[ -z ${creationsArray[0]} ]]; then

        	echo "There are currently no creations $1"
		echo 

        	return 1

        else

		for creation in ${creationsArray[@]}; do

			echo "$((++numberOfCreations)). $creation"
		done

        fi
        
        echo
}


#Plays the creations with ffplay
function playCreation() {

        listCreations "to play"
        
	#If there are creations
        if [[ $? -ne 1 ]]; then
        
		getCreationOperand "play"
        

		#If the user has not asked to quit
		if [[ $? -eq 0 ]]; then
                
			#Play the creation
		        ffplay -i -autoexit "./Creations/${creationsArray[$creationIndex-1]}.avi" &> /dev/null
		fi
        fi

}


#Deletes a creation specified by the user
function deleteCreation() {
        
        local deletionConfirmation
        
        
        listCreations "to delete"
        
	#If there are creations
        if [[ $? -ne 1 ]]; then  
        
		getCreationOperand "delete"
		

		#If the user has not asked to quit
		if [[ $? -eq 0 ]]; then
                        
                        read -p "Are you sure you want to delete ${creationsArray[$creationIndex-1]}.avi? [y / any other key]: " deletionConfirmation
                        echo
                        
                        if [[ $deletionConfirmation =~ (^([yY])$){1} ]] || [[ $deletionConfirmation =~ (^([yY][eE][sS])$){1} ]]; then
                            #Delete the creation
                            rm -f "./Creations/${creationsArray[$creationIndex-1]}.avi" &> /dev/null
                        fi
		fi
        fi
}


#Prompts the user to select which creation they want to perform the specified command on
function getCreationOperand() {
	
	read -p "Please enter the number of the creation you would like to $1, or q to quit back to the main menu [1-$((numberOfCreations))]: " creationIndex
        echo
	
	if [[ $creationIndex =~ (^([qQ])$){1} ]]; then
                
                    return 1
        fi

	while ((creationIndex < 1 || creationIndex > numberOfCreations)); do
                echo "Invalid Selection, please try again or enter q to quit back to the main menu"
                echo

                listCreations "to $1"

                read -p "Please enter the number of the creation you would like to $1, or q to quit back to the main menu [1-$((numberOfCreations))]: " creationIndex
        
                if [[ $creationIndex =~ (^([qQ])$){1} ]]; then
                
                    return 1
        	fi
	done
}


#Function which is called when the program is run. Makes critical function calls
function main() {
	#paths (updated during execution)
	pathToTextFiles="./Creations/.TextFiles"
	textFile="${pathToTextFiles}/${wikipediaSearch}"

	pathToAudioFiles="./Creations/.AudioFiles"
	audioFile="${pathToAudioFiles}/${wikipediaSearch}"


	#extensions
	audioExtension="wav"
	videoExtension="avi"


        #global variables 
        $userSelection 		#which command the user selects
        $wikipediaSearch 	#the term which the user searches on wikipedia
        $SearchResult 		#the result of the search term from wikipedia
	$lineCount 		#the number of lines in that search result
	$numberOfLines 		#the number of lines the user asks to be read
	$creationName 		#the name the user specifies for the creation
	$numberOfCreations	#the number of existing creations
	$creationIndex 		#the index of the creation which the user asks to operate on (i.e delete or play)
        
        
	#Do the setup process
        setUp
	
	
	#Continually execute these commands until the user quits
        while [ 0 ]; do
        
            getCommandToExecute 
            executeCommand
        done
}

#Call to the main function, which runs the program
main
