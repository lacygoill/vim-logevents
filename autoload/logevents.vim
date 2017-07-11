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

fu! logevents#complete(lead, line, _pos) abort
    return filter(copy(s:events), 'v:val[:strlen(a:lead)-1] ==? a:lead')
endfu

fu! s:close() abort
    try
        au! log_events | aug! log_events
        call s:write('Stopped logging events')

        " NOTE:
        " Here's a bit of code showing how to build a pane descriptor from a pane ID.
        "
        " A pane ID begins with a `%` sign; ex:
        "         %456
        " A pane descriptor follows the format `session_name:window_index.pane_index`; ex:
        "         study:1.2

        "         let descriptor_list = systemlist(
        "                     \ "tmux list-panes -a -F '#D #S #I #P'"
        "                     \ ."| awk 'substr($1, 2) == ".s:pane_id." { print $2, $3, $4 }'"
        "                     \ )
        "
        "         let [ session, window, pane ] = split(descriptor_list[0], ' ')
        "         let pane_descriptor = session.':'.window .'.'.pane

        " I got this code by reading the plugin `vim-tmuxify`:
        "         https://github.com/jebaum/vim-tmuxify/blob/master/autoload/tmuxify.vim
        "
        " In particular the function `s:get_pane_descriptor_from_id()`.
        " The functions `pane_create()` and `pane_kill()` are also interesting.
        "
        " Explanation:
        " Example of command executed by `systemlist()`:
        "
        "                          ┌─ list all the panes, not just the ones in the current window
        "                          │  ┌─ format the output of the command; here according to the string:
        "                          │  │          '#D #S #I #P'
        "                          │  │            │  │  │  │
        "                          │  │            │  │  │  └─ index of pane
        "                          │  │            │  │  └─ index of window
        "                          │  │            │  └─ name of session
        "                          │  │            └─ unique pane ID (ex: %42)
        "                          │  │
        "         tmux list-panes -a -F '#D #S #I #P' | awk 'substr($1, 2) == 456 { print $2, $3, $4 }'
        "                                                    │                            │
        "                                                    │                            └─ print:
        "                                                    │                                 session name
        "                                                    │                                 window index
        "                                                    │                                 pane index
        "                                                    │
        "                                                    └─ remove the `%` prefix from the 1st field
        "                                                       and compare the pane ID with `456`;
        "                                                       `456` is the unique pane ID of the pane
        "                                                       we're interested in
        "
        " Example of output for the command `tmux list-panes -a -F '#D #S #I #P'`:
        "
        "         %0 fun 1 1
        "         %123 study 1 2
        "         %456 study 1 2

        sil call system('tmux kill-pane -t %'.s:pane_id)
        unlet! s:file s:pane_id
    catch
    endtry
endfu

fu! logevents#main(...) abort
    if !a:0
        call s:close()
        return
    endif

    let events = filter(copy(a:000), 'count(s:events, v:val, 1)')
    if !empty(events)
        let s:file = tempname()
        call s:write('Started logging events')

        " Example of command executed by `systemlist()`:
        "
        "                        ┌─ make `/tmp` the working directory of the new window
        "                        │
        "                        │       ┌─ don't give the focus to the new window
        "                        │       │
        "                        │       │          ┌─ execute a `tail -f` command to let us read the log;
        "                        │       │          │  since `tail` will never finish,
        "                        │       │          │  tmux won't close the pane automatically
        "                        │       │          │
        "     tmux split-window -c /tmp -d -PF "#D" tail -f /tmp/logfile
        "                                   │└────┤
        "                                   │     └ -F "#D":  unique pane ID (ex: %42)
        "                                   │
        "                                   └─ print information about the new session
        "                                      after it has been created:
        "
        "                                          let myvar = system('tmux split-window -P tail -f ~/.bashrc')
        "                                          echo myvar  →  study:1.2\n
        "
        "                                      when using `-P`, by default, it seems that tmux uses the format:
        "                                          ‘#{session_name}:#{window_index}.#{pane_index}’
        "
        "                                      but a different format may be specified with -F


        " -h:       splits vertically (by default, tmux splits horizontally)
        " -p 25:    the width of the split should take 25% of the terminal
        let s:pane_id = systemlist(
                      \            'tmux split-window -c /tmp -d -h -p 25 -PF "#D" tail -f '.s:file
                      \            )[0][1:]
        "                            │  │
        "                            │  └─ remove the `%` prefix, we just want the ID number;
        "                            │
        "                            │     we could probably keep the `%`, but in the future,
        "                            │     it could lead to errors if we used it in a complex
        "                            │     command with `awk` (hard to escape/protect
        "                            │     inside an imbrication of strings);
        "                            │
        "                            │     for an example of complex command using
        "                            │     `awk`, read our NOTE explaining how to build
        "                            │     a pane descriptor from a pane ID
        "                            │
        "                            └─ get the first line of the output, the second one is empty

        augroup log_events
            au!
            for event in events
                sil exe 'autocmd '.event.' * call s:write('.string(event).')'
            endfor
        augroup END
    endif
endfu

fu! s:write(message) abort
    let text_to_append  = strftime('%T').' - '.a:message
    call writefile([text_to_append], s:file, 'a')
endfu
