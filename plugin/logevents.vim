vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

#                           ┌ We could simply use `-complete=events` instead.
#                           │ But it wouldn't filter out dangerous events (SourceCmd, ...).
#                           │
com -nargs=* -bar -complete=custom,logevents#complete LogEvents logevents#main([<f-args>])

nno dg<c-l> <cmd>call logevents#ClearNoise()<cr>

