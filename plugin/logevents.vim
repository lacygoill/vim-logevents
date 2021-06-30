vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

#                               ┌ We could simply use `-complete=events` instead.
#                               │ But it wouldn't filter out dangerous events (SourceCmd, ...).
#                               │
command -nargs=* -bar -complete=custom,logevents#complete LogEvents logevents#main([<f-args>])

