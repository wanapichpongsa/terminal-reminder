#!/bin/zsh

# DEADLINE REMINDERS

### DEVELOPMENT AND TESTING:
# $ chmod u+x deadline.zsh so that user (you) has permission to execute the file.
# Then, run $ zsh deadline.zsh || ./deadline.zsh

# TODO: 
# Deprecation feature for pre-existing deadlines (run each day)
# Add time calculation for exact time and time zone changes

# Json file to store deadlines (exportable for data analysis!)
# NOTE: You want $HOME path if you've inputted in .zshrc file (UNCOMMENT LINE BELOW)
# DEADLINE_FILE="$HOME/.deadline_reminders.json" # '.' file to hide it :)

# Otherwise, for testing and development, init file in current directory (make sure file is gitignored to protect your data!)
DEADLINE_FILE="./.deadline_reminders.json"

# Declare deadlines associative array
typeset -A deadlines # fun fact: an array is a subshell e.g., deadlines=() where $() executes commands! (I wonder why that's why we can access values by index)

# Load deadlines from json file to deadlines dictionary-like array
load_deadlines() {
    # Create file if it doesn't exist
    if [[ ! -f "$DEADLINE_FILE" ]]; then
        echo "Couldn't find file $DEADLINE_FILE"
        echo "Creating file..."
        echo "{}" > "$DEADLINE_FILE" # write empty json object to file
        return
    fi
    # Read JSON file and parse into associative array
    echo "Loading deadlines from $DEADLINE_FILE..."
    local json_content=$(cat "$DEADLINE_FILE")

    # Skip if file is empty
    if [[ -z "$json_content" ]]; then
        echo "No content found."
        return
    fi

    # JSON data format: "project_name": [days, months, years]
    while IFS='"' read -r line; do
        # IFS will not work properly if there is leading && trailing whitespace.
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # thus we trim :)

        # Parse the line using awk
        project=$(echo $line | awk -F'"' '{print $2}')
        value=$(echo $line | awk -F'[][]' '{print $2}' | tr -d ' ') # tr -d ' ' is to remove whitespace from extracted values
        
        # if project and value are not empty, then...
        if [[ -n "$project" && -n $value ]]; then
            IFS=',' read -r -A values <<< "$value" # <<< to input string
            deadlines[$project]="${values[@]}"
        fi
    done < "$DEADLINE_FILE" # < to input file in via terminal.
}

load_deadlines

### OFFICIAL START OF SCRIPT
# Get today's date
today=$(date +%d/%m/%Y)

# Helper: Validate and parse date
get_date() {
    local date="$1"
    if [[ ! "$date" =~ ^[0-9]{2}/[0-9]{2}/[0-9]{4}$ ]]; then
        echo "DATE_FORMAT_ERROR: '$date' must be in DD/MM/YYYY format" >&2 #&2 is error typesetting
        return 1
    fi
    echo "$date" | tr '/' ' '  # Convert date to space-separated for processing
}

is_leap_year() {
    local year=$1
    # discovered in 1582 but irrelevant because we can't add deadline before today

    # The leap year paradox: If divisible by 4 leap year (but divisible by 100 and not divisible by 400 then not leap year)
    # 0 == success, 1 == failure
    ((year % 400 == 0 || (year % 4 == 0 && year % 100 != 0))) && return 0 || return 1
}

# Helper: Save deadlines to file
save_deadlines() {
    # Create JSON structure
    local json="{"
    local first=true
    
    for project in "${(@k)deadlines}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            json+=","
        fi
        # Split the deadline value into an array
        local values=(${=deadlines[$project]})
        # Add proper newline and indentation
        json+="\n\t$project: [${values[1]}, ${values[2]}, ${values[3]}]"
    done
    
    json+="\n}"
    
    # Save to file with proper newlines
    echo $json > "$DEADLINE_FILE"
}

get_days_in_month() {
    local month=$1
    local year=$2

    # Note: shell scripting uses return as exit status, so use echo to return functional values instead.
    case $month in
        4|6|9|11) echo 30;;
        2) is_leap_year $year && echo 29 || echo 28;;
        *) echo 31;; # * == else
    esac # escape
}

# Helper: Add deadline
append_deadline_to_deadlines() {
    local project_name="$1"
    local deadline_date="$2"

    # Validate and parse dates
    local today_parts=($(get_date "$today")) || return 1
    local deadline_parts=($(get_date "$deadline_date")) || return 1

    # Calculate time left (day, month, year)
    local day_diff=$((deadline_parts[1] - today_parts[1]))
    local month_diff=$((deadline_parts[2] - today_parts[2]))
    local year_diff=$((deadline_parts[3] - today_parts[3]))

    # Adjust for negative values && account for 30, 31 days via modulo and leap years via 
    if ((day_diff < 0)); then
        ((month_diff--))
        # Reference previous month
        local prev_month=$((deadline_parts[2] - 1))
        local year=$deadline_parts[3]
        # if prev_month is less than 1, then it's December of the previous year
        ((prev_month < 1)) && prev_month=12 && ((year--))
        local days_in_month=$(get_days_in_month $prev_month $year)
        day_diff=$((day_diff + days_in_month))
    fi
    if ((month_diff < 0)); then
        ((year_diff--))
        month_diff=$((month_diff + 12))
    fi

    if ((year_diff < 0)); then
        echo "ERROR: Deadline '$project_name' has already passed." >&2
        return 1
    fi

    # Add to deadlines dictionary    
	deadlines["$project_name"]="$day_diff $month_diff $year_diff"
    save_deadlines
}

# Display deadlines on terminal startup.
display_deadlines() {
    # if deadlines size > 0 ([@] access all keys, # sums total number of keys), then display deadlines
    if [[ ${#deadlines[@]} -gt 0 ]]; then
        echo "<< DEADLINE REMINDER >>"
        for project in "${(@k)deadlines}"; do
            local time_left=(${(s: :)deadlines[$project]}) # Syntax: (s: :) where s is split extension in zsh, ':' is string delimiter
            local days=${time_left[1]}
            local months=${time_left[2]}
            local years=${time_left[3]}
            # remove item from dict as soon as deadline passed
            if ((days < 0)); then
            unset "deadlines[$project]"
            fi

            # Construct output messages
            local message="$project: "
            ((years > 0)) && message+="$years Year(s) "
            ((months > 0)) && message+="$months Month(s) "
            ((days > 0)) && message+="$days Day(s) "
            message+="Left"

            echo $message
        done
    else
        echo "No deadlines found."
    fi
}

display_usage() {
    # Show available commands
    echo -e "\nHow to use terminal reminder script:"
    echo "Display deadlines: $ zsh ~/.zshrc"
    echo "Add deadlines: $ zsh ~/.zshrc add-deadline"
    echo "Remove deadlines: $ zsh ~/.zshrc remove-deadline"
}

# Command-line interface for adding deadlines
# global $1 (i.e., not $1 in functions) are direct inputs in cli :)
if [[ $1 == "" ]]; then
    display_deadlines
    display_usage
elif [[ $1 == "add-deadline" ]]; then
    echo "<< ADD DEADLINE >>"
    # For some reason, read flags -p && -a don't work
    echo "Input your project and deadline in the format \"Project_Name DD/MM/YYYY\" (--finish to exit):"
    # store input as array seperated by " " (cool that -a automatically s(: :))
    read item_input 
    # Syntax: Could split(" ") using parameter expansion '#' == removeBefore || '%' == removeAfter but using shorthand is better
    [[ "${item_input[0]//[[:space:]]/}" == "--finish" ]] && break # need ;;?
    
    split_input=(${(s: :)item_input})

    # bash && zsh index starts with 1 btw
    project_name="${split_input[1]}"
    deadline_date="${split_input[2]}"

    # Append deadline
    append_deadline_to_deadlines "$project_name" "$deadline_date"
    display_deadlines
elif [[ $1 == "remove-deadline" ]]; then
    echo "<< REMOVE DEADLINE >>"
    echo "Input the project name to remove:"
    read project_name
    unset "deadlines[$project_name]" || echo "deadline not found"
    display_deadlines
    save_deadlines
else
    display_usage
    exit 1
fi # finish after if/else branch