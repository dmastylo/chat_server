Chat Server Project 3
=====================

Chris Celi
Damian Mastylo

Network Programming Spring '14

Programmed in Ruby

How to Run:
Uses Ruby 2.1.0
```
ruby run_server.rb 8000 8001 -v -d
```
-v and -d flags are optional. Requires at least one port.

-v logs the server actions.

-d is development mode and will allow Threads to abort the process on errors.

Why the code is messy
---------------------
It's pretty messy on this branch because I misread the specifications of the
assignment and didn't realize until a couple days before the deadline. To make
matters worse I had another programming project due for another class due that
week. Thus, unstructured and ungeneric code. I recommend looking at the master
branch for something that is less of an eyesore.