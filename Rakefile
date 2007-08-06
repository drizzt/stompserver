# -*- ruby -*-

require 'rubygems'
require 'hoe'
$LOAD_PATH << "./lib"
require 'stomp_server'

Hoe.new('stompserver', StompServer::VERSION) do |p|
  p.rubyforge_name = 'stompserver'
  p.summary = 'A very light messaging server'
  p.description = p.paragraphs_of('README.txt', 2..4).join("\n\n")
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/)[1..-1]
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.email = [ "lionel-dev@bouton.name" ]
  p.author = [ "Lionel Bouton" ]
  p.extra_deps = [
    # This depencency is real, but if you are on a Win32 box
    # and don't have VC6, it can be a real problem
    ["daemons", ">= 1.0.2"],
    ["hoe", ">= 1.1.1"],
  ]
end

# vim: syntax=Ruby
