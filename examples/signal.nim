import system/ansi_c

export SIG_DFL, SIGABRT, SIGFPE, SIGILL, SIGINT, SIGSEGV, SIGTERM

when not defined(windows):
  export SIGPIPE
  var
    SIG_IGN* {.importc: "SIG_IGN", header: "<signal.h>".}: cint
    SIGHUP* {.importc: "SIGHUP", header: "<signal.h>".}: cint
    SIGQUIT* {.importc: "SIGQUIT", header: "<signal.h>".}: cint

type CSighandlerT = proc (a: cint) {.noconv.}

proc setSignalProc* (`proc`: CSighandlerT, signals: varargs[cint]) =
  for sig in signals:
    discard c_signal(sig, `proc`)
