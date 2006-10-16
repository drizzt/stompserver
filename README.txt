stompserver
    by Patrick Hurley
    http://

== DESCRIPTION:

Don't want to install a JVM, but still want to use messaging? Me too,
so I threw together this little server. All the hard work was done
by Francis Cianfrocca (big thank you) in his event machine gem (which
is required by this server).

== FEATURES/PROBLEMS:

Handles basic message queue processing
Does not support any server to server messaging
  (although you could write a client to do this)
Server Id is not being well initialized   

== SYNOPSYS:

Handles basic message queue processing  

== REQUIREMENTS:

+ EventMachine

== INSTALL:

+ Grab the gem

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
