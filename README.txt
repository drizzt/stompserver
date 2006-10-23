stompserver
    by Patrick Hurley
    http://stompserver.rubyforge.org/

== DESCRIPTION:

Don't want to install a JVM, but still want to use messaging? Me too,
so I threw together this little server. All the hard work was done
by Francis Cianfrocca (big thank you) in his event machine gem (which
is required by this server).

== FEATURES/PROBLEMS:

Handles basic message queue processing using memory, file, or berkeleydb based queues.  Messages are sent and consumed in FIFO order.
Right now topics are memory only storage.  You can select file or bdb storage and the queues will use that, but topics will only be
stored in memory.

Does not support any server to server messaging
  (although you could write a client to do this)
Quite a bit of polish is still required to make into a daemon/service 

Queues can be monitored via the monitor queue. If you subscribe to /queue/monitor, you will receive a status message every 5 seconds that
displays each queue, it's size, frames enqueued, and frames dequeued.  Stats are sent in the same format of stomp headers, so they are
easy to parse. Following is an example of a status message containing stats for 2 queues:

Queue: /queue/client2
size: 0
dequeued: 400
enqueued: 400

Queue: /queue/test
size: 50
dequeued: 250
enqueued: 300

Basic client authorization is also supported.  If the -a flag is passed to stompserver on startup, and a .passwd file exists in the
run directory, then clients will be required to provide a valid login and passcode.  See passwd.example for the password file format.

Whenever you stop the server, any queues with no messages will be removed, and the stats for that queue will be reset.  If the queue has
any messages remaining then the stats will be saved and available on the next restart.


== SYNOPSYS:

Handles basic message queue processing  

== REQUIREMENTS:

+ EventMachine

== INSTALL:

+ gem install stompserver
  
  To use the memory queue run as follows:
    stompserver -p 61613 -b 0.0.0.0 

  To use the file or berkeleydb queue storage, use the -q switch and specificy either file or bdb.  The file and bdb queues also need
  a storage directory specified with -s.  .stompserver is the default directory.
    stompserver -p 61613 -b 0.0.0.0 -q file -s .stompfile
  Or
    stompserver -p 61613 -b 0.0.0.0 -q bdb -s .stompbdb
    
  To specify where the queue is stored on disk, use the -s flag followed by a storage directory.  To enable client authorization 
  use -a, for debugging use -d.
    stompserver -p 61613 -b 0.0.0.0 -q file -s .stompserver -a -d

  You cannot use the same storage directory for a file and bdb queue, they must be kept separate.

== LICENSE:

(The MIT License)

Copyright (c) 2006 Patrick Hurley

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
