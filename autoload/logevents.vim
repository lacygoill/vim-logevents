" Forked from:
" https://github.com/lervag/dotvim/blob/master/personal/plugin/log-autocmds.vim

" Variables {{{1

let s:events = getcompletion('', 'event')
let s:event2extra_info = {
\                          'CompleteDone'     : 'string(v:completed_item)',
\                          'FileChangedShell' : 'printf("reason: %s | choice: %s", v:fcs_reason, v:fcs_choice)',
\                          'InsertCharPre'    : 'v:char',
\                          'InsertChange'     : '"v:insertmode: ".v:insertmode',
\                          'InsertEnter'      : '"v:insertmode: ".v:insertmode',
\                          'OptionSet'        : 'printf("[ %s ] old: %s | new: %s | type: %s",
\                                                        expand("<amatch>"),
\                                                        v:option_old, v:option_new, v:option_type)',
\                          'SwapExists'       : 'printf("choice: %s | command: %s | name: %s",
\                                                        v:swap_choice, v:swapcommand, v:swapname)',
\                        }

" These events are deliberately left out due to side effects:
"
"         • BufReadCmd
"         • BufWriteCmd
"         • FileAppendCmd
"         • FileReadCmd
"         • FileWriteCmd
"         • FuncUndefined
"         • SourceCmd

let s:dangerous = [
\                   'BufReadCmd',
\                   'BufWriteCmd',
\                   'FileAppendCmd',
\                   'FileReadCmd',
\                   'FileWriteCmd',
\                   'FuncUndefined',
\                   'SourceCmd',
\                 ]

let s:synonyms = [
\                  'BufCreate',
\                  'BufRead',
\                  'BufWrite',
\                ]

call filter(s:events, { i,v -> index(s:dangerous + s:synonyms, v, 0, 1) == -1 })
unlet! s:dangerous s:synonyms

" Functions {{{1
fu! s:close() abort "{{{2
    try
        au! log_events
        aug! log_events
        call s:write(0, '', 'Stopped logging events')

        sil call system('tmux kill-pane -t %'.s:pane_id)
        unlet! s:file s:pane_id
    catch
        return my_lib#catch_error()
    endtry
endfu

fu! logevents#complete(arglead, _c, _p) abort "{{{2
    return empty(a:arglead)
    \?         s:events
    \:         filter(copy(s:events), { i,v -> v[:strlen(a:arglead)-1] ==? a:arglead })
endfu

fu! s:get_events_to_log(events) abort "{{{2
    call map(a:events, { i,v -> getcompletion(v, 'event') })
    if empty(a:events)
        return ''
    endif
    let events = eval(join(a:events, '+'))
    " Make sure that all events are present inside `s:events`.
    " Otherwise,  if we  try to  log  a dangerous  event, which  is absent  from
    " `s:events`, `s:normalize_names()`  will wrongly replace its  name with the
    " last (-1) event in `s:events`:
    "
    "           index(events_lowercase, tolower(v)) == -1
    "         → s:events[…] = s:events[-1] = 'WinNew'       ✘
    call filter(events, { i,v -> index(s:events, v) >= 0 })
    return s:normalize_names(events)
endfu

fu! s:get_extra_info(event) abort "{{{2
    return has_key(s:event2extra_info, a:event)
    \?         eval(s:event2extra_info[a:event])
    \:         matchstr(expand('<amatch>'), '^\V\('.escape(getcwd(), '\').'/\)\?\v\zs.*')
    "          append a possible match to the message
    "          but if the cwd is at the beginning of the match, remove it
endfu

fu! logevents#main(bang, ...) abort "{{{2
    " NOTE:
    " Do NOT try to remove tmux dependency, and use jobs instead.
    " The logging must be external to the current Vim's instance, otherwwise
    " it would pollute what we're trying to study.
    if !exists('$TMUX')
        return 'echoerr "Only works inside Tmux."'
    endif

    " if no argument was provided to `:LogEvents`, close the pane and quit
    if !a:0
        call s:close()
        return ''
    endif

    " if a pane already exists, just close it
    if exists('s:pane_id')
        call s:close()
    endif

    let events = s:get_events_to_log(copy(a:000))

    if !empty(events)
        let s:file = tempname()
        call s:write(0, '', 'Started logging')

        let percent = a:bang ? 50     : 25
        let dir     = a:bang ? ' -v ' : ' -h '

        "                don't give the focus ─┐
        "                to the new window     │
        "                                      │
        "       make `/tmp` the cwd   ┐        │
        "       of the new window     │        │
        "                             ├─────┐  │
        let cmd  = 'tmux split-window -c /tmp -d '

        "          ┌─ how to split: horizontally vs vertically
        "          │
        "          │                ┌ how big should be the split (25% in width or 50% in height)
        "          │   ┌────────────┤
        let cmd .= dir.' -p '.percent

        "             ┌─ print information about the new window after it has been created
        "             │
        "             │    ┌ unique pane ID (ex: %42)
        "             │   ┌┤
        let cmd .= ' -PF "#D"'
        "              └────┤
        "                   └ let myvar = system('tmux split-window -P tail -f ~/.bashrc')
        "                     echo myvar  →  study:1.2\n
        "
        "                     when using `-P`, by default, it seems that tmux uses the format:
        "                         ‘#{session_name}:#{window_index}.#{pane_index}’
        "
        "                     but a different format may be specified with -F

        " execute a `tail -f` command to let  us read the log
        " since `tail` will never finish, tmux won't close the pane automatically
        let cmd .= ' tail -f '.s:file

        let s:pane_id = systemlist(cmd)[0][1:]
        "                               │  │
        "                               │  └─ remove the `%` prefix, we just want the ID number
        "                               └─ get the first line of the output, the second one is empty
        "
        "                                  we could probably keep the `%`, but in the future,
        "                                  it could lead to errors if we used it in a complex
        "                                  command with `awk` (hard to escape/protect
        "                                  inside an imbrication of strings);

        let biggest_width = max(map(copy(events), { i,v -> strlen(v) }))
        augroup log_events
            au!
            for event in events
                sil exe printf('au %s * call s:write(%d, "%s", "%s")',
                             \ event, a:bang, event, printf('%-*s', biggest_width, event))
            endfor
            " close the tmux pane when we quit Vim, if we didn't close it already
            au VimLeave * call s:close()
        augroup END
    endif
    return ''
endfu

fu! s:normalize_names(my_events) abort "{{{2
    let events_lowercase = map(copy(s:events), { i,v -> tolower(v) })
    return map(a:my_events, { i,v -> s:events[index(events_lowercase, tolower(v))] })
endfu

fu! s:write(bang, event, msg) abort "{{{2
    let to_append = strftime('%M:%S').'  '.a:msg
    if a:bang
        let to_append .= '  '.s:get_extra_info(a:event)
    endif
    call writefile([ to_append ], s:file, 'a')
endfu
