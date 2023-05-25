import std/[re, strformat, unittest]
import jacket

suite "test version":
    test "getVersion":
        var major, minor, micro, proto: cint
        getVersion(major.addr, minor.addr, micro.addr, proto.addr)
        #echo fmt"{major}.{minor}.{micro} proto {proto}"
        check:
            # yes, the function simply returns 0 for all vars :-D
            major == 0
            minor == 0
            micro == 0
            proto == 0
    test "getVersionString":
        let version = getVersionString()
        #echo $version
        check:
            $typeof(version) == "cstring"
            match($version, re(r"\d+\.\d+\.\d+"))
