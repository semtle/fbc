' TEST_MODE : COMPILE_ONLY_FAIL

function badtest() as integer
    print "."
end function

Dim t1 As Any Ptr
t1 = threadcall badtest()
