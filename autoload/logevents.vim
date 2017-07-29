" close {{{1

fu! s:close() abort
    try
        au! log_events
        aug! log_events
        call s:write('Stopped logging events')

        sil call system('tmux kill-pane -t %'.s:pane_id)
        unlet! s:file s:pane_id
    catch
    endtry
endfu

" complete {{{1

" These events are deliberately left out due to side effects:
"
"         - SourceCmd
"         - FileAppendCmd
"         - FileWriteCmd
"         - BufWriteCmd
"         - FileReadCmd
"         - BufReadCmd
"         - FuncUndefined

let s:events = [
               \ '*',
               \ 'BufAdd',
               \ 'BufCreate',
               \ 'BufDelete',
               \ 'BufEnter',
               \ 'BufFilePost',
               \ 'BufFilePre',
               \ 'BufHidden',
               \ 'BufLeave',
               \ 'BufNew',
               \ 'BufNewFile',
               \ 'BufRead',
               \ 'BufReadPost',
               \ 'BufReadPre',
               \ 'BufUnload',
               \ 'BufWinEnter',
               \ 'BufWinLeave',
               \ 'BufWipeout',
               \ 'BufWrite',
               \ 'BufWritePost',
               \ 'BufWritePre',
               \ 'CmdUndefined',
               \ 'CmdwinEnter',
               \ 'CmdwinLeave',
               \ 'ColorScheme',
               \ 'CompleteDone',
               \ 'CursorHold',
               \ 'CursorHoldI',
               \ 'CursorMoved',
               \ 'CursorMovedI',
               \ 'EncodingChanged',
               \ 'FileAppendPost',
               \ 'FileAppendPre',
               \ 'FileChangedRO',
               \ 'FileChangedShell',
               \ 'FileChangedShellPost',
               \ 'FileReadPost',
               \ 'FileReadPre',
               \ 'FileType',
               \ 'FileWritePost',
               \ 'FileWritePre',
               \ 'FilterReadPost',
               \ 'FilterReadPre',
               \ 'FilterWritePost',
               \ 'FilterWritePre',
               \ 'FocusGained',
               \ 'FocusLost',
               \ 'GUIEnter',
               \ 'GUIFailed',
               \ 'InsertChange',
               \ 'InsertCharPre',
               \ 'InsertEnter',
               \ 'InsertLeave',
               \ 'MenuPopup',
               \ 'QuickFixCmdPost',
               \ 'QuickFixCmdPre',
               \ 'QuitPre',
               \ 'RemoteReply',
               \ 'SessionLoadPost',
               \ 'ShellCmdPost',
               \ 'ShellFilterPost',
               \ 'SourcePre',
               \ 'SpellFileMissing',
               \ 'StdinReadPost',
               \ 'StdinReadPre',
               \ 'SwapExists',
               \ 'Syntax',
               \ 'TabClosed',
               \ 'TabEnter',
               \ 'TabLeave',
               \ 'TermChanged',
               \ 'TermResponse',
               \ 'TextChanged',
               \ 'TextChangedI',
               \ 'User',
               \ 'VimEnter',
               \ 'VimLeave',
               \ 'VimLeavePre',
               \ 'VimResized',
               \ 'WinEnter',
               \ 'WinLeave',
               \ ]

if has('nvim')
    let s:events += [ 'TermClose', 'TermOpen' ]
endif

fu! logevents#complete(lead, line, _pos) abort
    return empty(a:lead)
                \ ? s:events
                \ : filter(copy(s:events), 'v:val[:strlen(a:lead)-1] ==? a:lead')
endfu

" main {{{1

fu! logevents#main(...) abort
    " if no argument was provided to `:LogEvents`, close the pane and quit
    if !a:0
        call s:close()
        return
    endif

    " if a pane already exists, just close it
    if exists('s:pane_id')
        call s:close()
    endif

    let regular_args = filter(copy(a:000), 'v:val !~# "*"')
    let events       = filter(regular_args, "count(s:events, v:val, 1)")
    "                                                               │
    "                                                   ignore case ┘

    let glob_args    = filter(copy(a:000), 'v:val =~# "*"')
    call map(glob_args, "substitute(v:val, '*', '.*', 'g')")
    for glob in glob_args
        let events += filter(copy(s:events), 'v:val =~? glob')
    endfor

    if !empty(events)
        let s:file = tempname()
        call s:write('Started logging events')

        "                     execute a `tail -f` command to let us read the log; ─┐
        "                     since `tail` will never finish,                      │
        "                     tmux won't close the pane automatically              │
        "                                                                          │
        "   the width of the split should take 25% of the terminal ─┐              │
        "                                                           │              │
        "              splits vertically instead of horizontally ─┐ │              │
        "                                                         │ │              │
        "              don't give the focus to the new window ─┐  │ │              │
        "                                                      │  │ │              │
        "            make `/tmp` the working directory ┐       │  │ │              │
        "            of the new window                 │       │  │ │              │
        "                                              ├────┐  │  │ ├───┐          │
        let s:pane_id = systemlist('tmux split-window -c /tmp -d -h -p 25 -PF "#D" tail -f '.s:file)[0][1:]
        "                                                                  │└────┤                   │  │
        "                                                                  │     │                   │  │
        "                                                                  │     │                   │  │
        " print information about the new session ─────────────────────────┘     │                   │  │
        " after it has been created:                                             │                   │  │
        "                                                                        │                   │  │
        "     let myvar = system('tmux split-window -P tail -f ~/.bashrc')       │                   │  │
        "     echo myvar  →  study:1.2\n                                         │                   │  │
        "                                                                        │                   │  │
        " when using `-P`, by default, it seems that tmux uses the format:       │                   │  │
        "     ‘#{session_name}:#{window_index}.#{pane_index}’                    │                   │  │
        "                                                                        │                   │  │
        " but a different format may be specified with -F                        │                   │  │
        "                                                                        │                   │  │
        "                                             unique pane ID (ex: %42)  ─┘                   │  │
        "                                                                                            │  │
        "                                         remove the `%` prefix, we just want the ID number ─┘  │
        "                                                                                               │
        "                                    get the first line of the output, the second one is empty ─┘
        "
        "                                           we could probably keep the `%`, but in the future,
        "                                           it could lead to errors if we used it in a complex
        "                                           command with `awk` (hard to escape/protect
        "                                           inside an imbrication of strings);

        augroup log_events
            au!
            for event in events
                sil exe 'au '.event.' * call s:write('.string(event).')'
            endfor
            " close the tmux pane when we quit Vim, if we didn't close it already
            au VimLeave * call s:close()
        augroup END
    endif
endfu

" write {{{1

fu! s:write(message) abort
    let text_to_append  = strftime('%T').' - '.a:message
    call writefile([text_to_append], s:file, 'a')
endfu
