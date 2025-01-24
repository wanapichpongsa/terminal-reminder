# DEADLINE REMINDERS

# $ chmod +x deadline.zsh to make script executable then zsh deadline.zsh

# TODO:
# - How to store long-term memory i.e., store deadlines in a file?
# - 

# Get today's date
today=$(date +%d/%m/%Y)

# Declare deadlines associative array
typeset -A deadlines # fun fact: an array is a subshell e.g., deadlines=() where $() executes commands! (I wonder why that's why we can access values by index)

# Helper: Validate and parse date
get_date() {
    local date="$1"
    if [[ ! "$date" =~ ^[0-9]{2}/[0-9]{2}/[0-9]{4}$ ]]; then
        echo "DATE_FORMAT_ERROR: '$date' must be in DD/MM/YYYY format" >&2 #&2 is error typesetting
        return 1
    fi
    echo "$date" | tr '/' ' '  # Convert date to space-separated for processing
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

    # Adjust for negative values
    if ((day_diff < 0)); then
        ((month_diff--))
        day_diff=$((day_diff + 30))  # Approximation for days in a month
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
}

# Command-line interface for adding deadlines
# global $1 (i.e., not $1 in functions) are direct inputs in cli :)
interact="$1"
if [[ $interact == "add-deadline" ]]; then
    echo "<< DEADLINE REMINDER CONFIG >>"
    # For some reason, read flags -p && -a don't work
    echo "Input your project and deadline in the format \"Project_Name DD/MM/YYYY\" (--finish to exit):"
    # store input as array seperated by " " (cool that -a automatically s(: :))
    read item_input 
    # Syntax: Could split(" ") using parameter expansion '#' == removeBefore || '%' == removeAfter but using shorthand is better
    [[ "${item_input[0]//[[:space:]]/}" == "--finish" ]] && break # need ;;?

    # Validate input
    echo "$item_input"
    
    split_input=(${(s: :)item_input})

    # bash && zsh index starts with 1 btw
    project_name="${split_input[1]}"
    deadline_date="${split_input[2]}"

    # Append deadline
    append_deadline_to_deadlines "$project_name" "$deadline_date"
else
    echo "Usage: zsh deadline.zsh add-deadline"
    exit 1
fi # finish after if/else branch

# Display deadlines on terminal startup.
if [[ ${#deadlines[@]} -gt 0 ]]; then
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
fi

# Since in config of .zshrc file, need to add ~/.zshrc after zsh
echo -e "Add more deadlines with:\n\$ zsh ~/.zshrc add-deadline" # Syntax: -e to interpret escape sequences such as \n or \t but not \" for some reason
