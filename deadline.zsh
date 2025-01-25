# DEADLINE REMINDERS

# $ chmod +x deadline.zsh to make script executable then zsh deadline.zsh

# TODO:
# - How to store long-term memory i.e., store deadlines in a file?
# - Account for 30, 31 days in a month and leap years.

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

is_leap_year() {
    local year=$1
    # discovered in 1582 but irrelevant because we can't add deadline before today

    # The leap year paradox: If divisible by 4 leap year (but divisible by 100 and not divisible by 400 then not leap year)
    # 0 == success, 1 == failure
    ((year % 400 == 0 || (year % 4 == 0 && year % 100 != 0))) && return 0 || return 1
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

# Command-line interface for adding deadlines
# global $1 (i.e., not $1 in functions) are direct inputs in cli :)
if [[ $1 == "" ]]; then
    display_deadlines
elif [[ $1 == "add-deadline" ]]; then
    echo "<< ADD DEADLINE >>"
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
    display_deadlines
elif [[ $1 == "remove-deadline" ]]; then
    echo "<< REMOVE DEADLINE >>"
    echo "Input the project name to remove:"
    read project_name
    unset "deadlines[$project_name]"
    display_deadlines
else
    echo "Usage:"
    echo "Display deadlines: \$ zsh ~/.zshrc"
    echo "Add deadlines: \$ zsh ~/.zshrc add-deadline"
    echo "Remove deadlines: \$ zsh ~/.zshrc remove-deadline"
    exit 1
fi # finish after if/else branch

# Since in config of .zshrc file, need to add ~/.zshrc after zsh
echo -e "Display deadlines: \$ zsh ~/.zshrc"
echo -e "Add more deadlines with: \$ zsh ~/.zshrc add-deadline" # Syntax: -e to interpret escape sequences such as \n or \t but not \" for some reason
echo -e "Remove deadlines with: \$ zsh ~/.zshrc remove-deadline"
