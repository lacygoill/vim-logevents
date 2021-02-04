vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

import Catch from 'lg.vim'

# Variables {{{1

const DIR: string = getenv('XDG_RUNTIME_VIM') ?? '/tmp'

var EVENTS: list<string> = getcompletion('', 'event')

# These events are deliberately left out due to side effects:
#
#    - BufReadCmd
#    - BufWriteCmd
#    - FileAppendCmd
#    - FileReadCmd
#    - FileWriteCmd
#    - FuncUndefined
#    - SourceCmd

const DANGEROUS: list<string> =<< trim END
    BufReadCmd
    BufWriteCmd
    FileAppendCmd
    FileReadCmd
    FileWriteCmd
    FuncUndefined
    SourceCmd
END

const SYNONYMS: list<string> =<< trim END
    BufCreate
    BufRead
    BufWrite
END

# Some events are fired too frequently.{{{
#
# It's fine if we want to log them specifically.
# It's not if we're logging everything with `:LogEvents *`.
#}}}
const TOO_FREQUENT: list<string> =<< trim END
    CmdlineChanged
    CmdlineEnter
    CmdlineLeave
    SafeState
    SafeStateAgain
END

filter(EVENTS, (_, v) => index(DANGEROUS + SYNONYMS, v, 0, true) == -1)
lockvar! EVENTS

def InfoCompletedone(): string
    return printf(
             'v:completed_item.word: %s'
        .. "\nv:completed_item.menu: %s"
        .. "\nv:completed_item.user_data: %s"
        .. "\nv:completed_item.info: %s"
        .. "\nv:completed_item.kind: %s"
        .. "\nv:completed_item.abbr: %s",
          get(v:completed_item, 'word', ''),
          get(v:completed_item, 'menu', ''),
          get(v:completed_item, 'user_data', ''),
          get(v:completed_item, 'info', ''),
          get(v:completed_item, 'kind', ''),
          get(v:completed_item, 'abbr', ''),
        )
enddef

# Why `get()`?{{{
#
# When you press `C-n`  while your cursor is on the last entry  of the menu, you
# leave the menu; in that case, `v:event.completed_item` is empty.
#}}}
def InfoCompletechanged(): string
    return printf(
             'v:event.completed_item.word: %s'
        .. "\nv:event.completed_item.menu: %s"
        .. "\nv:event.completed_item.user_data: %s"
        .. "\nv:event.completed_item.info: %s"
        .. "\nv:event.completed_item.kind: %s"
        .. "\nv:event.completed_item.abbr: %s"
        .. "\nv:event.height: %s"
        .. "\nv:event.width: %s"
        .. "\nv:event.row: %s"
        .. "\nv:event.col: %s"
        .. "\nv:event.size: %s"
        .. "\nv:event.scrollbar: %s\n",
          get(v:event.completed_item, 'word', ''),
          get(v:event.completed_item, 'menu', ''),
          get(v:event.completed_item, 'user_data', ''),
          get(v:event.completed_item, 'info', ''),
          get(v:event.completed_item, 'kind', ''),
          get(v:event.completed_item, 'abbr', ''),
              v:event.height,
              v:event.width,
              v:event.row,
              v:event.col,
              v:event.size,
              v:event.scrollbar,
        )
enddef

def InfoFilechangedshell(): string
    return printf(
             'reason: %s'
        .. "\nchoice: %s",
              v:fcs_reason,
              v:fcs_choice,
        )
enddef

def InfoInsertcharpre(): string
    return v:char
enddef

def InfoInsertmode(): string
    return 'v:insertmode: ' .. v:insertmode
enddef

def InfoOptionset(): string
    return printf(
             '    old: %s'
        .. "\n    new: %s"
        .. "\n    type: %s"
        .. "\n    command: %s"
        .. "\n    oldlocal: %s"
        .. "\n    oldglobal: %s",
              v:option_old,
              v:option_new,
              v:option_type,
              v:option_command,
              v:option_oldlocal,
              v:option_oldglobal,
        )
enddef

def InfoSwapexists(): string
    return printf(
             'v:swapchoice: %s'
        .. "\nv:swapcommand: %s"
        .. "\nv:swapname: %s",
              v:swapchoice,
              v:swapcommand,
              v:swapname,
        )
enddef

def InfoTermresponse(): string
    return printf('v:termresponse: %s', v:termresponse)
enddef

def InfoTextyankpost(): string
    return printf(
            'v:event.operator: %s'
        .. "\nv:event.regcontents: %s"
        .. "\nv:event.regname: %s"
        .. "\nv:event.regtype: %s\n",
             v:event.operator,
             map(v:event.regcontents, (i, v) => i != 0 ? repeat(' ', 21) .. v : v)->join("\n"),
             v:event.regname,
             v:event.regtype =~ '\d' ? 'C-v ' .. v:event.regtype[1 :] : v:event.regtype,
        )
enddef

const EVENT2EXTRA_INFO: dict<func> = {
    CompleteChanged: InfoCompletechanged,
    CompleteDone: InfoCompletedone,
    FileChangedShell: InfoFilechangedshell,
    InsertCharPre: InfoInsertcharpre,
    InsertChange: InfoInsertmode,
    InsertEnter: InfoInsertmode,
    OptionSet: InfoOptionset,
    SwapExists: InfoSwapexists,
    TermResponse: InfoTermresponse,
    TextYankPost: InfoTextyankpost,
    }

# Functions {{{1
def logevents#main(args: list<string>) #{{{2
    # Do *not* try to remove tmux dependency, and use jobs instead.{{{
    #
    # The logging must be external to the current Vim's instance, otherwwise
    # it would pollute what we're trying to study.
    #}}}
    if !exists('$TMUX')
        Error('only works inside tmux')
        return
    endif
    if empty(args)
        PrintUsage()
        return
    endif
    var idx_unknown_option: number = match(args,
        '-\%(\%(clear\|stop\|v\|vv\|vvv\)\%(\s\|$\)\)\@!\S*')
    if idx_unknown_option >= 0
        Error('unknown OPTION: ' .. args[idx_unknown_option])
        return
    endif

    if index(args, '-clear') >= 0
        Clear(args)
        return
    elseif index(args, '-stop') >= 0
        Stop(args)
        return
    endif

    var events: list<string> = copy(args)->GetEventsToLog()
    if empty(events)
        Error('missing EVENT operand')
        return
    endif

    last_args = args
    # if a pane already exists, just close it
    if pane_id != ''
        Close()
    endif

    var verbosity: number = VerbosityLevel(args)
    OpenTmuxPane(verbosity)
    Log(events, verbosity)
enddef
var pane_id: string
var last_args: list<string>

def Error(msg: string) #{{{2
    echohl ErrorMsg
    echom 'LogEvents: ' .. msg
    echohl NONE
enddef

def PrintUsage() #{{{2
    var usage: list<string> =<< trim END
        Usage: LogEvents [OPTION] EVENT...
          or:  LogEvents OPTION
        EVENT can contain a wildcard (e.g. Buf*, Buf[EL], ???New).

              -clear                   clear log
              -stop                    stop logging
              -v                       increase verbosity
              -vv                      increase verbosity even more (<amatch>, <afile>, v:char, v:event, ...)
              -vvv                     max verbosity (necessary to get <abuf>)
    END
    echo join(usage, "\n")
enddef

def Clear(args: list<string>) #{{{2
    if join(args) != '-clear'
        Error('-clear must be used alone')
        return
    endif
    if pane_id != ''
        Close()
    else
        Error('nothing to clear')
        return
    endif
    call('logevents#main', [last_args])
enddef

def Stop(args: list<string>) #{{{2
    if join(args) != '-stop'
        Error('-stop must be used alone')
        return
    endif
    if pane_id != ''
        Close()
    else
        Error('nothing to stop')
    endif
enddef

def Close() #{{{2
    try
        if !exists('#LogEvents')
            return
        endif

        au! LogEvents
        aug! LogEvents

        sil system('tmux kill-pane -t ' .. pane_id)
        pane_id = ''
    catch
        Catch()
        return
    endtry
enddef

def VerbosityLevel(args: list<string>): number #{{{2
    var lvl: number = 0
    if index(args, '-v') >= 0
        lvl = 1
    elseif index(args, '-vv') >= 0
        lvl = 2
    elseif index(args, '-vvv') >= 0
        lvl = 3
    endif
    return lvl
enddef

def GetEventsToLog(arg_events: list<string>): list<string> #{{{2
    var log_everything: bool = index(arg_events, '*') >= 0
    # Why do you append a `$`?{{{
    #
    # Without, when we run:
    #
    #     :LogEvents safestate
    #
    # `SafeState` *and* `SafeStateAgain` are logged.
    # It's due to `getcompletion()`:
    #
    #     :echo getcompletion('safestate', 'event')
    #     ['SafeState', 'SafeStateAgain']~
    #
    # It's as if `getcompletion()` appends a `*` at the end.
    # To prevent that, we append `$`.
    #}}}
    var events: list<list<string>> = mapnew(arg_events, (_, v) =>
        getcompletion(v[-1 : -1] =~ '\l' ? v .. '$' : v, 'event'))
    if empty(events)
        return []
    endif
    var flattened: list<string> = events->flattennew()
    # Make sure that all events are present inside `EVENTS`.{{{
    #
    # Otherwise,  if we  try to  log  a dangerous  event, which  is absent  from
    # `EVENTS`, the next  `map()` will wrongly replace its name  with the last
    # event in `EVENTS`, which is `WinNew` atm:
    #
    #       index(EVENTS, v, 0, true) == -1
    #     ⇒ EVENTS[-1]
    #     ⇒ 'WinNew'
    #}}}
    filter(flattened, (_, v) => index(EVENTS, v, 0, true) >= 0)
    # normalize names
    map(flattened, (_, v) => EVENTS[index(EVENTS, v, 0, true)])
    if log_everything
        filter(flattened, (_, v) => index(TOO_FREQUENT, v, 0, true) == -1)
    endif
    return flattened
enddef

def GetExtraInfo(event: string, verbosity: number): string #{{{2
    if verbosity == 1
        return expand('<amatch>')
    endif

    var info: string = ''
    var amatch: string = expand('<amatch>')
    if amatch != ''
        info ..= 'amatch: ' .. amatch
    endif

    var afile: string = expand('<afile>')
    if afile != ''
        if afile == amatch
            info ..= "\nafile: \""
        else
            info ..= "\nafile: " .. afile
        endif
    endif

    if verbosity == 3
        var abuf: string = expand('<abuf>')
        if abuf != ''
            info ..= (info == '' ? '' : "\n") .. 'abuf: ' .. abuf
        endif
    endif

    if has_key(EVENT2EXTRA_INFO, event)
        info ..= "\n" .. EVENT2EXTRA_INFO[event]()
    endif
    return info
enddef

def OpenTmuxPane(verbosity: number) #{{{2
    var layout: string = verbosity != 0 ? ' -v ' : ' -h '
    var percent: number = verbosity != 0 ? 50 : 25
    var cmd: string = 'tmux splitw -c ' .. shellescape(DIR) .. ' -dI '
    cmd ..= layout .. ' -p ' .. percent
    cmd ..= ' -PF "#D"'
    sil pane_id = system(cmd)->trim("\n", 2)
enddef

def Log(events: list<string>, verbosity: number) #{{{2
    sil system('tmux display -I -t ' .. pane_id, "Started logging\n")

    var biggest_width: number = mapnew(events, (_, v) => strlen(v))->max()
    augroup LogEvents | au!
        for event in events
            sil exe printf('au %s * Write(%d, "%s", "%s")',
                event, verbosity, event, printf('%-*s', biggest_width, event))
        endfor
        # close the tmux pane when we quit Vim, if we didn't close it already
        au VimLeave * Close()
    augroup END
enddef

def Write(verbosity: number, event: string, msg: string) #{{{2
    var to_append: any = strftime('%M:%S') .. '  ' .. msg
    if verbosity != 0
        to_append ..= '  ' .. GetExtraInfo(event, verbosity)
    endif
    to_append = split(to_append, '\n')
    if len(to_append) >= 2
        var indent: string = repeat(' ',
            matchstr(to_append[0], '^\d\+:\d\+\s\+\a\+\s\+')->strlen())
        to_append = [to_append[0]] + map(to_append[1 :], (_, v) => indent .. v)
    endif
    try
        sil system('tmux display -I -t ' .. pane_id, join(to_append, "\n") .. "\n")
    catch /^Vim\%((\a\+)\)\=:E12:/
        # `E12` is raised if you log `OptionSet`, `'modeline'` is set, and `'modelines'` is greater than 0.{{{
        #
        # You can't run a shell command from an autocmd listening to `OptionSet`
        # if the latter event has been triggered by a modeline.
        #
        # MWE:
        #
        #     $ vim -Nu NONE +'au OptionSet * call system("")'
        #     :h
        #
        # When `:h` is run, the bottom modeline is processed.
        # It sets options, which fires `OptionSet`, which invokes `system()`.
        #
        # However,  when  a  modeline  is  processed,  Vim  temporarily  forbids
        # external shell commands from being run, for security reasons.
        # So, `system()` raises `E12`.
        #}}}
    catch
        Catch()
        return
    endtry
enddef

def logevents#complete(arglead: string, _l: any, _p: any): string #{{{2
    if arglead[0] == '-'
        var options: list<string> =<< trim END
            -clear
            -stop
            -v
            -vv
        END
        return join(options, "\n")
    endif
    return copy(EVENTS)->join("\n")
enddef

