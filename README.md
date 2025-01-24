# Terminal Deadline Reminder

A simple ZSH script that helps you track and manage project deadlines directly from your terminal.

NOTE: This script uses modern ZSH syntax and may not be compatible with BASH.

## Features
- Add deadlines with project names
- Automatically calculate remaining time
- Display deadline reminders on terminal startup
- Date validation and error handling

## Usage
It takes seconds to set up.

1. Copy and paste the code into your .zshrc file. From your $HOME directory (if unsure, run `cd`), run:

`$ vscode ~/.zshrc`

2. Add the following line to the end of the file:

`source ~/path/to/terminal_reminder/deadline.zsh`

3. Save the file and reload your terminal.

4. Run `deadline add-deadline` to add a deadline.