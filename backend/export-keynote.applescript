-- Arguments are passed directly to osascript; file paths never become script code.
-- The worker supplies a private temporary copy, not the user's original file.
on run argv
    set sourceFile to POSIX file (item 1 of argv)
    set targetFile to POSIX file (item 2 of argv)
    set outputKind to item 3 of argv
    with timeout of 180 seconds
        tell application "Keynote"
            set workingDocument to open sourceFile
            try
                if outputKind is "pdf" then
                    export workingDocument to targetFile as PDF
                else if outputKind is "pptx" then
                    export workingDocument to targetFile as Microsoft PowerPoint
                else
                    error "Unsupported output format"
                end if
                close workingDocument saving no
            on error errorMessage number errorNumber
                try
                    close workingDocument saving no
                end try
                error errorMessage number errorNumber
            end try
        end tell
    end timeout
end run
