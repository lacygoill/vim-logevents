if exists('g:loaded_logevents')
    finish
endif
let g:loaded_logevents = 1

"                            ┌ We could simply use `-complete=events` instead.
"                            │ But it wouldn't filter out dangerous events (SourceCmd, …).
"                            │
com! -nargs=* -bar -complete=custom,logevents#complete LogEvents call logevents#main(<f-args>)

