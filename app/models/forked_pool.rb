class ForkedPool
  
  # The PID of the Forkr master
  # @return [Fixnum]
  attr_reader :master_pid

  # The number of children I should maintain
  # This can be adjusted up or down with the TTIN and TTOU signals.
  # @return [Integer]
  attr_reader :child_count
 
  # Child process pids.
  # @return [Array<Fixnum>]
  attr_reader :children

  # @param forklet [Object] the worker object
  # @param num_kids [Integer] how many children to spawn 
  def initialize(forklet, num_kids = 1)
    @worker_client = forklet 
    @master_pid = $$
    @children = []
    @child_count = num_kids
    @in_shutdown = false
  end

  # Start the master, and spawn workers
  # @return [nil]
  def run
    @inbound, @outbound = IO.pipe
    Signal.trap('CHLD') { dead_child }
    Signal.trap('INT') { interrupt }
    Signal.trap('TERM') { shutdown }
    Signal.trap('QUIT') { core_dump_quit }
    Signal.trap('TTIN') { add_worker }
    Signal.trap('TTOU') { remove_worker }
    master_loop
  end

  protected

  attr_reader :inbound, :outbound

  def send_wake_notice(notice)
    return(nil) if $$ != master_pid
    return(nil) if @in_shutdown
    @outbound.write(notice)
  end

  def core_dump_quit
    send_wake_notice("Q")
  end

  def add_worker
    send_wake_notice("+")
  end

  def remove_worker
    send_wake_notice("-")
  end

  def interrupt
    send_wake_notice("I")
  end

  def shutdown
    send_wake_notice("T")
  end

  def dead_child
    send_wake_notice("D")
  end

  def spawn_worker
    if new_pid = fork
      @children << new_pid
    else
      worker_loop
    end
  end

  def increment_workers
    @child_count = @child_count + 1
  end

  def decrement_workers
    if @child_count > 0
      @child_count = @child_count - 1
    end
  end

  def shutdown_using(sig)
    @in_shutdown = true
    signal_all_workers(sig)
    raise StopIteration.new
  end

  def master_loop
    catch(:im_a_worker_so_bail) do
    ensure_right_worker_count
    loop do
      fds = IO.select([@inbound],nil,nil,2)
      unless fds.nil?
        data_read = fds.first.first.read(1)
        if data_read == "I"
          shutdown_using(:INT)
        elsif data_read == "T"
          shutdown_using(:TERM)
        elsif data_read == "Q"
          shutdown_using(:QUIT)
        elsif data_read == "+"
          increment_workers
        elsif data_read == "-"
          decrement_workers
        end
        if @child_count < 1
          shutdown_using(:TERM)
        end
      end
      prune_workers
      ensure_right_worker_count
    end
    reap_all_workers
    @outbound.close
    @inbound.close
    end
  end

  def reap_all_workers
    begin
      wpid, status = Process.waitpid2(-1, Process::WNOHANG)
    rescue Errno::ECHILD
      break
    end while true
  end

  def ensure_right_worker_count
    existing_workers = @children.length
    off_by = @child_count - @children.length
    if off_by > 0
      off_by.times do
        spawn_worker
      end
    elsif off_by < 0
      @children.take(off_by.abs).each do |kid|
        signal_worker(kid, :TERM)
      end
    end
  end

  def signal_all_workers(sig)
    @children.each { |c| signal_worker(c, sig) }
  end

  def signal_worker(wpid, signal)
    begin
      Process.kill(signal, wpid)
    rescue Errno::ESRCH
    end
  end

  def prune_workers
    @children = @children.reject { |pid| child_dead?(pid) }
  end

  def worker_loop
    @worker_client.after_fork if @worker_client.respond_to?(:after_fork)
    @inbound.close
    @outbound.close
    $stderr.puts "Worker spawned as #{$$}!"
    @worker_client.run
    throw(:im_a_worker_so_bail)
  end

  def child_dead?(pid)
    status = Process.waitpid(pid, Process::WNOHANG)
    unless status.nil?
      if $? == 0
        remove_worker
      end
      $stderr.puts "Process #{pid} dead: #{status}"
    end
    !status.nil?
  end
end
