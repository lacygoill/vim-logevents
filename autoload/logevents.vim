if exists('g:autoloaded_logevents')
    finish
endif
let g:autoloaded_logevents = 1

" Forked from:
" https://github.com/lervag/dotvim/blob/master/personal/plugin/log-autocmds.vim

" Variables {{{1

let s:events = getcompletion('', 'event')

" These events are deliberately left out due to side effects:
"
"         • BufReadCmd
"         • BufWriteCmd
"         • FileAppendCmd
"         • FileReadCmd
"         • FileWriteCmd
"         • FuncUndefined
"         • SourceCmd

let s:leave_alone = [
                  \   'BufReadCmd',
                  \   'BufWriteCmd',
                  \   'FileAppendCmd',
                  \   'FileReadCmd',
                  \   'FileWriteCmd',
                  \   'FuncUndefined',
                  \   'SourceCmd',
                  \ ]

call filter(s:events, '!count(s:leave_alone, v:val, 1)')
unlet! s:leave_alone

fu! s:close() abort "{{{1
    try
        au! log_events
        aug! log_events
        call s:write(0, 'Stopped logging events')

        sil call system('tmux kill-pane -t %'.s:pane_id)
        unlet! s:file s:pane_id
    catch
    endtry
endfu

fu! logevents#complete(lead, line, _pos) abort "{{{1
    return empty(a:lead)
        \?     s:events
        \:     filter(copy(s:events), 'v:val[:strlen(a:lead)-1] ==? a:lead')
endfu

fu! logevents#main(bang, ...) abort "{{{1
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

    let regular_args = filter(copy(a:000), 'v:val !~# "*"')
    let events       = filter(regular_args, "count(s:events, v:val, 1)")
    "                                                               │
    "                                                   ignore case ┘

    let glob_args = filter(copy(a:000), 'v:val =~# "*"')
    call map(glob_args, "substitute(v:val, '*', '.*', 'g')")
    for glob in glob_args
        let events += filter(copy(s:events), 'v:val =~? glob')
    endfor

    if !empty(events)
        let s:file = tempname()
        call s:write(0, 'Started logging')

        let percent = a:bang ? 50     : 25
        let dir     = a:bang ? ' -v ' : ' -h '

        "                don't give the focus ─┐
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

        "             ┌─ print information about the new session after it has been created
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

        augroup log_events
            au!
            for event in events
                sil exe printf('au %s * call s:write('.a:bang.', "%s")', event, event)
            endfor
            " close the tmux pane when we quit Vim, if we didn't close it already
            au VimLeave * call s:close()
        augroup END
    endif
    return ''
endfu

fu! s:write(bang, message) abort "{{{1
    let text_to_append  = strftime('%M:%S').'  '.a:message
    if a:bang
        " append a possible match to the message
        " but if the cwd is at the beginning of the match, remove it
        let text_to_append .= ' '.matchstr(expand('<amatch>'), '^\V\('.escape(getcwd(), '\').'/\)\?\v\zs.*')
    endif
    call writefile([text_to_append], s:file, 'a')
endfu
