" Usage:
"         :LogEvents BufRead BufEnter WinEnter
"         :LogEvents
"
" The 1st command logs the 3 events `BufRead`, `BufEnter` and `WinEnter`.
" The 2nd command stops the logging.

com! -nargs=* -complete=customlist,logevents#complete LogEvents call logevents#main(<f-args>)
