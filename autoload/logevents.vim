if exists('g:autoloaded_logevents')
    finish
endif
let g:autoloaded_logevents = 1

" Forked from:
" https://github.com/lervag/dotvim/blob/master/personal/plugin/log-autocmds.vim

" Variables {{{1

let s:EVENTS = getcompletion('', 'event')
" TODO: Since 8.1.1542, there are new variables tied to the `OptionSet` event.{{{
" https://github.com/vim/vim/releases/tag/v8.1.1542
"
"     v:option_command
"     v:option_oldlocal
"     v:option_oldglobal
"
" Log their values; but wait for Nvim to merge the patch.
"}}}
let s:event2extra_info = {
\ 'CompleteDone'     : 'string(v:completed_item)',
\ 'FileChangedShell' : 'printf("reason: %s\nchoice: %s", v:fcs_reason, v:fcs_choice)',
\ 'InsertCharPre'    : 'v:char',
\ 'InsertChange'     : '"v:insertmode: ".v:insertmode',
\ 'InsertEnter'      : '"v:insertmode: ".v:insertmode',
\ 'OptionSet'        : 'printf("[%s] old: %s\nnew: %s\ntype: %s",
\                               expand("<amatch>"),
\                               v:option_old, v:option_new, v:option_type)',
\ 'SwapExists'       : 'printf("v:swapchoice: %s\nv:swapcommand: %s\nv:swapname: %s",
\                               v:swapchoice, v:swapcommand, v:swapname)',
\ 'TextYankPost'     : 'printf("v:event.operator: %s\nv:event.regcontents: %s\nv:event.regname: %s\nv:event.regtype: %s\n",
\  v:event.operator, join(map(v:event.regcontents, {i,v -> i !=# 0 ? "                     ".v : v}), "\n"), v:event.regname,
\  v:event.regtype =~ "\\d" ? "C-v ".v:event.regtype[1:] : v:event.regtype)',
\ }

" These events are deliberately left out due to side effects:
"
"    - BufReadCmd
"    - BufWriteCmd
"    - FileAppendCmd
"    - FileReadCmd
"    - FileWriteCmd
"    - FuncUndefined
"    - SourceCmd

let s:DANGEROUS = [
    \ 'BufReadCmd',
    \ 'BufWriteCmd',
    \ 'FileAppendCmd',
    \ 'FileReadCmd',
    \ 'FileWriteCmd',
    \ 'FuncUndefined',
    \ 'SourceCmd',
    \ ]

let s:SYNONYMS = [
    \ 'BufCreate',
    \ 'BufRead',
    \ 'BufWrite',
    \ ]

call filter(s:EVENTS, {i,v -> index(s:DANGEROUS + s:SYNONYMS, v, 0, 1) ==# -1})
unlet! s:DANGEROUS s:NOISY s:SYNONYMS

" Functions {{{1
fu! s:close() abort "{{{2
    try
        if !exists('#log_events')
            return
        endif

        au! log_events
        aug! log_events

        sil call system('tmux kill-pane -t '.s:pane_id)
        unlet! s:pane_id
    catch
        return lg#catch_error()
    endtry
endfu

fu! logevents#complete(arglead, _cmdline, _pos) abort "{{{2
    return join(copy(s:EVENTS), "\n")
endfu

fu! s:get_events_to_log(events) abort "{{{2
    call map(a:events, {i,v -> getcompletion(v, 'event')})
    if empty(a:events)
        return ''
    endif
    let events = eval(join(a:events, '+'))
    " Make sure that all events are present inside `s:EVENTS`.
    " Otherwise,  if we  try to  log  a dangerous  event, which  is absent  from
    " `s:EVENTS`, `s:normalize_names()`  will wrongly replace its  name with the
    " last (-1) event in `s:EVENTS`:
    "
    "           index(events_lowercase, tolower(v)) ==# -1
    "         → s:EVENTS[…] = s:EVENTS[-1] = 'WinNew'       ✘
    call filter(events, {i,v -> index(s:EVENTS, v) >= 0})
    return s:normalize_names(events)
endfu

fu! s:get_extra_info(event) abort "{{{2
    return has_key(s:event2extra_info, a:event)
       \ ?     eval(s:event2extra_info[a:event])
       \ :     matchstr(expand('<amatch>'), '^\C\V\('.escape(getcwd(), '\').'/\)\?\v\zs.*')
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

    " Some events are fired too frequently.{{{
    "
    " It's fine if we want to log them specifically.
    " It's not if we're logging everything.
    "}}}
    if a:000 ==# ['*']
        call filter(events, {i,v -> v !=# 'CmdlineChanged' && v !=# 'CmdlineEnter' && v !=# 'CmdlineLeave'})
    endif

    if !empty(events)
        let percent = a:bang ? 50     : 25
        let dir     = a:bang ? ' -v ' : ' -h '

        let cmd  = 'tmux splitw -c $XDG_RUNTIME_VIM -dI '
        let cmd .= dir.' -p '.percent
        let cmd .= ' -PF "#D"'
        sil let s:pane_id = system(cmd)[:-2]

        call system('tmux display -I -t ' . s:pane_id, "Started logging\n")

        let biggest_width = max(map(copy(events), {i,v -> strlen(v)}))
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
    let events_lowercase = map(copy(s:EVENTS), {i,v -> tolower(v)})
    return map(a:my_events, {i,v -> s:EVENTS[index(events_lowercase, tolower(v))]})
endfu

fu! s:write(bang, event, msg) abort "{{{2
    let to_append = strftime('%M:%S').'  '.a:msg
    if a:bang
        let to_append .= '  '.s:get_extra_info(a:event)
    endif
    let to_append = split(to_append, '\n')
    if len(to_append) >= 2
        let indent = repeat(' ', strlen(matchstr(to_append[0], '^\d\+:\d\+\s\+\a\+\s\+')))
        let to_append = to_append[0:0]  + map(to_append[1:], {i,v -> indent.v})
    endif
    call system('tmux display -I -t ' . s:pane_id, join(to_append, "\n") . "\n")
endfu

