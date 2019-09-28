if exists('g:autoloaded_logevents')
    finish
endif
let g:autoloaded_logevents = 1

" Forked from:
" https://github.com/lervag/dotvim/blob/master/personal/plugin/log-autocmds.vim

" Variables {{{1

let s:DIR = getenv('XDG_RUNTIME_VIM') == v:null ? '/tmp' : $XDG_RUNTIME_VIM

let s:EVENTS = getcompletion('', 'event')

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

" Some events are fired too frequently.{{{
"
" It's fine if we want to log them specifically.
" It's not if we're logging everything with `:LogEvents *`.
"}}}
let s:TOO_FREQUENT = [
    \ 'CmdlineChanged',
    \ 'CmdlineEnter',
    \ 'CmdlineLeave',
    \ 'SafeState',
    \ 'SafeStateAgain',
    \ ]

call filter(s:EVENTS, {_,v -> index(s:DANGEROUS + s:SYNONYMS, v, 0, 1) ==# -1})
unlet! s:DANGEROUS s:SYNONYMS

fu! s:info_completedone() abort
    return printf(
    \     'v:completed_item.word: %s'
    \ .."\nv:completed_item.menu: %s"
    \ .."\nv:completed_item.user_data: %s"
    \ .."\nv:completed_item.info: %s"
    \ .."\nv:completed_item.kind: %s"
    \ .."\nv:completed_item.abbr: %s",
    \      v:completed_item.word,
    \      v:completed_item.menu,
    \      v:completed_item.user_data,
    \      v:completed_item.info,
    \      v:completed_item.kind,
    \      v:completed_item.abbr,
    \ )
endfu

" Why `get()`?{{{
"
" When you press `C-n`  while your cursor is on the last entry  of the menu, you
" leave the menu; in that case, `v:event.completed_item` is empty.
"}}}
fu! s:info_completechanged() abort
    return printf(
    \     'v:event.completed_item.word: %s'
    \ .."\nv:event.completed_item.menu: %s"
    \ .."\nv:event.completed_item.user_data: %s"
    \ .."\nv:event.completed_item.info: %s"
    \ .."\nv:event.completed_item.kind: %s"
    \ .."\nv:event.completed_item.abbr: %s"
    \ .."\nv:event.height: %s"
    \ .."\nv:event.width: %s"
    \ .."\nv:event.row: %s"
    \ .."\nv:event.col: %s"
    \ .."\nv:event.size: %s"
    \ .."\nv:event.scrollbar: %s\n",
    \      get(v:event.completed_item, 'word', ''),
    \      get(v:event.completed_item, 'menu', ''),
    \      get(v:event.completed_item, 'user_data', ''),
    \      get(v:event.completed_item, 'info', ''),
    \      get(v:event.completed_item, 'kind', ''),
    \      get(v:event.completed_item, 'abbr', ''),
    \      v:event.height,
    \      v:event.width,
    \      v:event.row,
    \      v:event.col,
    \      v:event.size,
    \      v:event.scrollbar,
    \ )
endfu

fu! s:info_filechangedshell() abort
    return printf(
    \     'reason: %s'
    \ .."\nchoice: %s",
    \      v:fcs_reason,
    \      v:fcs_choice,
    \ )
endfu

fu! s:info_insertcharpre() abort
    return v:char
endfu

fu! s:info_insertmode() abort
    return 'v:insertmode: '..v:insertmode
endfu

fu! s:info_optionset() abort
    " Nvim hasn't  merged 8.1.1542  yet (even though  `v:command`, `v:oldlocal`,
    " `v:oldglobal` are documented).
    if has('nvim')
        return printf(
        \     '[%s]'
        \ .."\n    old: %s"
        \ .."\n    new: %s"
        \ .."\n    type: %s",
        \      expand('<amatch>'),
        \      v:option_old,
        \      v:option_new,
        \      v:option_type,
        \ )
    else
        return printf(
        \     '[%s]'
        \ .."\n    old: %s"
        \ .."\n    new: %s"
        \ .."\n    type: %s"
        \ .."\n    command: %s"
        \ .."\n    oldlocal: %s"
        \ .."\n    oldglobal: %s",
        \      expand('<amatch>'),
        \      v:option_old,
        \      v:option_new,
        \      v:option_type,
        \      v:option_command,
        \      v:option_oldlocal,
        \      v:option_oldglobal,
        \ )
    endif
endfu

fu! s:info_swapexists() abort
    return printf(
    \     'v:swapchoice: %s'
    \ .."\nv:swapcommand: %s"
    \ .."\nv:swapname: %s",
    \      v:swapchoice,
    \      v:swapcommand,
    \      v:swapname,
    \ )
endfu

fu! s:info_termresponse() abort
    return printf('v:termresponse: %s', v:termresponse)
endfu

fu! s:info_textyankpost() abort
    return printf(
    \     'v:event.operator: %s'
    \ .."\nv:event.regcontents: %s"
    \ .."\nv:event.regname: %s"
    \ .."\nv:event.regtype: %s\n",
    \      v:event.operator,
    \      join(map(v:event.regcontents, {i,v -> i !=# 0 ? repeat(' ', 21)..v : v}), "\n"),
    \      v:event.regname,
    \      v:event.regtype =~ '\d' ? 'C-v '..v:event.regtype[1:] : v:event.regtype,
    \ )
endfu

let s:event2extra_info = {
\ 'CompleteChanged'  : function('s:info_completechanged'),
\ 'CompleteDone'     : function('s:info_completedone'),
\ 'FileChangedShell' : function('s:info_filechangedshell'),
\ 'InsertCharPre'    : function('s:info_insertcharpre'),
\ 'InsertChange'     : function('s:info_insertmode'),
\ 'InsertEnter'      : function('s:info_insertmode'),
\ 'OptionSet'        : function('s:info_optionset'),
\ 'SwapExists'       : function('s:info_swapexists'),
\ 'TermResponse'     : function('s:info_termresponse'),
\ 'TextYankPost'     : function('s:info_textyankpost'),
\ }

" Functions {{{1
fu! logevents#main(...) abort "{{{2
    " Do *not* try to remove tmux dependency, and use jobs instead.{{{
    "
    " The logging must be external to the current Vim's instance, otherwwise
    " it would pollute what we're trying to study.
    "}}}
    if !exists('$TMUX') | return s:error('only works inside Tmux') | endif
    if !a:0 | call s:print_usage() | return | endif
    let idx_unknown_option = match(a:000, '-\%(\%(clear\|stop\|v\|vv\)\%(\s\|$\)\)\@!\S*')
    if idx_unknown_option != -1
        return s:error('unknown OPTION: '..a:000[idx_unknown_option])
    endif

    if index(a:000, '-clear') >= 0
        return s:clear(a:000)
    elseif index(a:000, '-stop') >= 0
        return s:stop(a:000)
    endif

    let events = s:get_events_to_log(copy(a:000))
    if empty(events) | return s:error('missing EVENT operand') | endif

    let s:last_args = a:000
    " if a pane already exists, just close it
    if exists('s:pane_id') | call s:close() | endif

    let verbose = s:get_verbose(a:000)
    call s:open_tmux_pane(verbose)
    call s:log(events, verbose)
endfu

fu! s:error(msg) abort "{{{2
    echohl ErrorMsg
    echom 'LogEvents: '..a:msg
    echohl NONE
endfu

fu! s:print_usage() abort "{{{2
    let usage =<< trim END
    Usage: LogEvents [OPTION] EVENT...
      or:  LogEvents OPTION
    EVENT can contain a wildcard (e.g. Buf*, Buf[EL], ???New).

          -clear                   clear log
          -stop                    stop logging
          -v                       increase verbosity
          -vv                      increase verbosity even more
    END
    echo join(usage, "\n")
endfu

fu! s:clear(args) abort "{{{2
    if join(a:args) isnot# '-clear'
        return s:error('-clear must be used alone')
    endif
    if exists('s:pane_id')
        call s:close()
    else
        return s:error('nothing to clear')
    endif
    call call('logevents#main', s:last_args)
endfu

fu! s:stop(args) abort "{{{2
    if join(a:args) isnot# '-stop'
        return s:error('-stop must be used alone')
    endif
    if exists('s:pane_id')
        call s:close()
    else
        call s:error('nothing to stop')
    endif
endfu

fu! s:close() abort "{{{2
    try
        if !exists('#log_events') | return | endif

        au! log_events
        aug! log_events

        sil call system('tmux kill-pane -t '..s:pane_id)
        unlet! s:pane_id
    catch
        return lg#catch_error()
    endtry
endfu

fu! s:get_verbose(args) abort "{{{2
    let verbose = 0
    if index(a:args, '-v') >= 0
        let verbose = 1
    elseif index(a:args, '-vv') >= 0
        let verbose = 2
    endif
    return verbose
endfu

fu! s:get_events_to_log(events) abort "{{{2
    let log_everything = index(a:events, '*') >= 0
    call map(a:events, {_,v -> getcompletion(v, 'event')})
    if empty(a:events) | return '' | endif
    let events = eval(join(a:events, '+'))
    " Make sure that all events are present inside `s:EVENTS`.
    " Otherwise,  if we  try to  log  a dangerous  event, which  is absent  from
    " `s:EVENTS`, `s:normalize_names()`  will wrongly replace its  name with the
    " last (-1) event in `s:EVENTS`:
    "
    "       index(events_lowercase, tolower(v)) ==# -1
    "     → s:EVENTS[...] = s:EVENTS[-1] = 'WinNew'       ✘
    call filter(events, {_,v -> index(s:EVENTS, v) >= 0})
    let events = s:normalize_names(events)
    if log_everything
        call filter(events, {_,v -> index(s:TOO_FREQUENT, v) == -1})
    endif
    return events
endfu

fu! s:get_extra_info(event, verbose) abort "{{{2
    if a:verbose == 1
        return s:get_amatch()
    elseif a:verbose == 2
        return has_key(s:event2extra_info, a:event)
           \ ?     s:event2extra_info[a:event]()
           \ :     s:get_amatch()
    endif
endfu

fu! s:get_amatch() abort "{{{2
    " get a possible match, but if the cwd is at the beginning of the match, remove it
    return matchstr(expand('<amatch>'), '^\C\V\('..escape(getcwd(), '\')..'/\)\=\m\zs.*')
endfu

fu! s:open_tmux_pane(verbose) abort "{{{2
    let layout = a:verbose ? ' -v ' : ' -h '
    let percent = a:verbose ? 50 : 25
    let cmd = 'tmux splitw -c '..s:DIR..' -dI '
    let cmd .= layout..' -p '..percent
    let cmd .= ' -PF "#D"'
    sil let s:pane_id = system(cmd)[:-2]
endfu

fu! s:normalize_names(my_events) abort "{{{2
    let events_lowercase = map(copy(s:EVENTS), {_,v -> tolower(v)})
    return map(a:my_events, {_,v -> s:EVENTS[index(events_lowercase, tolower(v))]})
endfu

fu! s:log(events, verbose) abort "{{{2
    sil call system('tmux display -I -t '..s:pane_id, "Started logging\n")

    let biggest_width = max(map(copy(a:events), {_,v -> strlen(v)}))
    augroup log_events
        au!
        for event in a:events
            sil exe printf('au %s * call s:write(%d, "%s", "%s")',
                         \ event, a:verbose, event, printf('%-*s', biggest_width, event))
        endfor
        " close the tmux pane when we quit Vim, if we didn't close it already
        au VimLeave * call s:close()
    augroup END
endfu

fu! s:write(verbose, event, msg) abort "{{{2
    let to_append = strftime('%M:%S')..'  '..a:msg
    if a:verbose
        let to_append .= '  '..s:get_extra_info(a:event, a:verbose)
    endif
    let to_append = split(to_append, '\n')
    if len(to_append) >= 2
        let indent = repeat(' ', strlen(matchstr(to_append[0], '^\d\+:\d\+\s\+\a\+\s\+')))
        let to_append = to_append[0:0]  + map(to_append[1:], {_,v -> indent..v})
    endif
    sil call system('tmux display -I -t '..s:pane_id, join(to_append, "\n").."\n")
endfu

fu! logevents#complete(arglead, _cmdline, _pos) abort "{{{2
    if a:arglead[0] is# '-'
        let options = ['-clear', '-stop', '-v', '-vv']
        return join(options, "\n")
    endif
    return join(copy(s:EVENTS), "\n")
endfu

