(pwd() != @__DIR__) && cd(@__DIR__) # allow starting app from bin/ dir

using SheetGantt
const UserApp = SheetGantt
SheetGantt.main()
