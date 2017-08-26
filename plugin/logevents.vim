" Usage:
"         :LogEvents BufRead BufEnter WinEnter
"         :LogEvents
"
" The 1st command logs the 3 events `BufRead`, `BufEnter` and `WinEnter`.
" The 2nd command stops the logging.

" TODO:
" We could simply use `-complete=events` instead.
" But when we would execute `:Logevents *`, would it filter out the events
" which may cause an issue (like `SourceCmd`)?
com! -nargs=* -bar -complete=customlist,logevents#complete LogEvents exe logevents#main(<f-args>)
