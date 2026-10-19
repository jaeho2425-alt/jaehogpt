-- Creates only a new disposable presentation for integration testing.
on run argv
    set keyFile to POSIX file (item 1 of argv)
    set pptxFile to POSIX file (item 2 of argv)
    with timeout of 180 seconds
        tell application "Keynote"
            set testDocument to make new document
            try
                set firstSlide to slide 1 of testDocument
                set object text of default title item of firstSlide to "NotchConvert Test 1"
                set secondSlide to duplicate firstSlide to end of slides of testDocument
                set object text of default title item of secondSlide to "NotchConvert Test 2"
                save testDocument in keyFile
                export testDocument to pptxFile as Microsoft PowerPoint
                close testDocument saving no
            on error errorMessage number errorNumber
                try
                    close testDocument saving no
                end try
                error errorMessage number errorNumber
            end try
        end tell
    end timeout
end run
