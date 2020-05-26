#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

class ThreadDumper
  # Outputs a full thread dump to an IOStream
  def self.output_thread_backtraces_to(io)
    cur_thread = Thread.current

    io.puts "\nRuby Thread Dump\n================\n"

    thread_service = JRuby.runtime.thread_service
    trace_type = org.jruby.runtime.backtrace.TraceType

    for thread in thread_service.active_ruby_threads
      next if thread == cur_thread

      thread_r = JRuby.reference(thread)

      io.puts "* Thread: #{thread_r.native_thread.name}"
      io.puts "* Stack:"

      thread_r = JRuby.reference(thread)
      thread_context = thread_r.context

      unless thread_context
        io.puts "  [dead]\n"
        next
      end

      ex = RuntimeError.new('thread dump')
      ex_r = JRuby.reference(ex)

      gather = trace_type::Gather::NORMAL
      format = trace_type::Format::JRUBY

      ex_r.backtrace_data = gather.get_backtrace_data(thread_context, thread_r.native_thread.get_stack_trace, true)
      io.puts format.print_backtrace(ex, true)

      io.puts
    end
  end

  def self.dump_to(file)
    File.open(file, "w+") do |f|
      f << "Thread dump requested at: #{Time.now}\n"
      output_thread_backtraces_to(f)
    end
  end
end

begin
  handler = proc do
    ThreadDumper.output_thread_backtraces_to($stderr)
  end

  Signal.__jtrap_kernel(handler, 'USR2')
rescue ArgumentError
  $stderr.puts "failed handling USR2; 'jruby -J-XX:+UseAltSigs ...' to disable JVM's handler"
rescue Exception
  warn $!.message
  warning $!.backtrace
end
