stompserver
    by Patrick Hurley
    http://stompserver.rubyforge.org/

== DESCRIPTION:

Stomp messaging server with file/dbm/memory/activerecord based FIFO
queues, queue monitoring, and basic authentication.

== SYNOPSYS:

Handles basic message queue processing

== REQUIREMENTS:

* EventMachine

== FEATURES/PROBLEMS:

=== Several queue storage backends

Handles basic message queue processing using memory, file, or dbm
based queues. Messages are sent and consumed in FIFO order (unless a
client error happens, this should be corrected in the future). Topics
are memory-only storage.  You can select activerecord, file or dbm
storage and the queues will use that, but topics will only be stored
in memory.

memory queues are of course the fastest ones but shouldn't be used if
you want to ensure all messages are delivered.

dbm queues will use berkeleydb if available, otherwise dbm or gdbm
depending on the platform. sdbm does not work well with marshalled
data. Note that these queues have not been tested in this release.

For the file based storage, each frame is stored in a single file. The
first 8 bytes contains the header length, the next 8 bytes contains
the body length, then the headers are stored as a marshalled object
followed by the body stored as a string. This storage is currently
inefficient because queues are stored separately from messages, which
forces a double write for data safety reasons on each message stored.

The activerecord based storage expects to find a database.yml file in
the configuration directory. It should be the most robust backend, but
the slowest one. The database must have an ar_messages table which can
be created with the following code (you are responsible to do so):

  ActiveRecord::Schema.define do
    create_table 'ar_messages' do |t|
      t.column 'stomp_id', :string, :null => false
      t.column 'frame', :text, :null => false
    end
  end

You can read the frames with this model:

  class ArMessage < ActiveRecord::Base
    serialize :frame
  end

The ar_message implementation will certainly change in the future.

This is meant to be easily readable by a Rails application (which
could handle the ar_messages table creation with a migration).

=== Limitations

Stompserver not support any server to server messaging (although you could
write a client to do this).

=== Monitoring

Queues can be monitored via the monitor queue (this will probably not
be supported this way in the future to avoid polluting the queue
namespace). If you subscribe to /queue/monitor, you will receive a
status message every 5 seconds that displays each queue, it's size,
frames enqueued, and frames dequeued. Stats are sent in the same
format of stomp headers, so they are easy to parse. Following is an
example of a status message containing stats for 2 queues:

Queue: /queue/client2
size: 0
dequeued: 400
enqueued: 400

Queue: /queue/test
size: 50
dequeued: 250
enqueued: 300

=== Access control

Basic client authorization is also supported.  If the -a flag is
passed to stompserver on startup, and a .passwd file exists in the run
directory, then clients will be required to provide a valid login and
passcode.  See passwd.example for the password file format.

=== Misc

Whenever you stop the server, any queues with no messages will be
removed, and the stats for that queue will be reset.  If the queue has
any messages remaining then the stats will be saved and available on
the next restart.

== INSTALL:

* gem install stompserver

stompserver will create a log, etc, and storage directory on startup
in your current working directory, the value passed to as
--working_dir parameter, or if using a config file it will
use what you specified for working_dir.  The configuration file is a
yaml file and can be specified on the command line with -C
<configfile>. A sample is provided in config/stompserver.conf.

Command line options will override options set in the yaml config
file.

To use the memory queue run as follows:
  stompserver -p 61613 -b 0.0.0.0

To use the file or dbm queue storage, use the -q switch and specificy
either file or dbm.  The file and dbm queues also take a storage
directory specified with -s.  .stompserver is the default directory if
-s is not used.
  stompserver -p 61613 -b 0.0.0.0 -q file -s .stompfile
Or
  stompserver -p 61613 -b 0.0.0.0 -q dbm -s .stompbdb

To specify where the queue is stored on disk, use the -s flag followed
by a storage directory.  To enable client authorization use -a, for
debugging use -d.
  stompserver -p 61613 -b 0.0.0.0 -q file -s .stompserver -a -d

You cannot use the same storage directory for a file and dbm queue,
they must be kept separate.

To use the activerecord queue storage use -q activerecord:
  stompserver -p 61613 -b 0.0.0.0 -q activerecord
It will try to read the etc/database.yml file in the working
directory. Here's an example of a database.yml for a PostgreSQL
database named stompserver on the 'dbserver' host usable by
PostgreSQL's user 'foo' with password 'bar'(see ActiveRecord's
documentation for the parameters needed by your database):

  adapter: postgresql
  database: stompserver
  username: foo
  password: bar
  host: dbserver

== LICENSE:

(The MIT License)

Copyright (c) 2006 Patrick Hurley
Copyright (c) 2007 Lionel Bouton

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
