if exists('g:loaded_logevents')
    finish
endif
let g:loaded_logevents = 1

" Usage:
"         :LogEvents BufRead BufEnter WinEnter
"         :LogEvents
"
" The 1st command logs the 3 events `BufRead`, `BufEnter` and `WinEnter`.
" The 2nd command stops the logging.

"                                  ┌─ We could simply use `-complete=events` instead.
"                                  │  But it wouldn't filter out dangerous events (SourceCmd, …).
"                                  │
com! -nargs=* -bang -bar -complete=customlist,logevents#complete LogEvents exe logevents#main(<bang>0, <f-args>)
"              │
"              └─ in addition to events, log the matches (expand('<amatch>'))
