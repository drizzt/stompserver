
module StompServer
class FileQueue < Queue

  def _close_queue(dest)
    Dir.delete(@queues[dest][:queue_dir]) if File.directory?(@queues[dest][:queue_dir])
  end

  def _open_queue(dest)
    queue_name = dest.gsub('/','_')
    queue_dir = @directory + '/' + queue_name
    @queues[dest][:queue_dir] = queue_dir
    Dir.mkdir(queue_dir) unless File.directory?(queue_dir)
  end

  def _writeframe(dest,frame,msgid)
    filename = "#{@queues[dest][:queue_dir]}/#{msgid}"
    frame_body = frame.body
    frame.body = ''
    frame_image = Marshal.dump(frame)
    file = File.open(filename,'w+')
    file.binmode
    file.sysseek 0, IO::SEEK_SET
    file.syswrite sprintf("%08x", frame_image.length)
    file.syswrite sprintf("%08x", frame_body.length)
    file.syswrite(frame_image)
    file.syswrite(frame_body)
    file.close
    return true
  end
  
  def _readframe(dest,msgid)
    filename = "#{@queues[dest][:queue_dir]}/#{msgid}"
    file = File.open(filename,'r+')
    file.binmode
    file.sysseek 0, IO::SEEK_SET
    frame_len = file.sysread(8).hex
    body_len = file.sysread(8).hex
    frame = Marshal::load file.sysread(frame_len)
    frame_body = file.sysread(body_len)
    file.close
    frame.body = frame_body
    if File.delete(filename)
      return frame
    else
      return false
    end
  end
end
end

