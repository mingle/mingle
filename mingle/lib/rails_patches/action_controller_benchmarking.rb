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

# several lines patched
# we need load this file before Rails load the original ActionController::Benchmarking class, because if Rails load the original one, we can't overwrite it due to alias_method_chain behaviour
# This class is copied from rails-2.3.18/action_pack/lib/action_controller/benchmarking.rb
# and then changed some lines (please check out comments for what's the line we changed)

module ActionController #:nodoc:
  # The benchmarking module times the performance of actions and reports to the logger. If the Active Record
  # package has been included, a separate timing section for database calls will be added as well.
  module Benchmarking #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)

      base.class_eval do
        alias_method_chain :perform_action, :benchmark
        alias_method_chain :render, :benchmark
      end
    end

    module ClassMethods
      # Log and benchmark the workings of a single block and silence whatever logging that may have happened inside it
      # (unless <tt>use_silence</tt> is set to false).
      #
      # The benchmark is only recorded if the current level of the logger matches the <tt>log_level</tt>, which makes it
      # easy to include benchmarking statements in production software that will remain inexpensive because the benchmark
      # will only be conducted if the log level is low enough.
      def benchmark(title, log_level = Logger::DEBUG, use_silence = true)
        if logger && logger.level == log_level
          result = nil
          ms = Benchmark.ms { result = use_silence ? silence { yield } : yield }
          logger.add(log_level, "#{title} (#{('%.1f' % ms)}ms)")
          result
        else
          yield
        end
      end

      # Silences the logger for the duration of the block.
      def silence
        old_logger_level, logger.level = logger.level, Logger::ERROR if logger
        yield
      ensure
        logger.level = old_logger_level if logger
      end
    end

    protected
      # patched method
      def active_connection?
        Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connection_handler.active_connections?
      rescue ActiveRecordPartitioning::NoActiveConnectionPoolError => e
        if MingleConfiguration.multitenancy_migrator?
          Rails.logger.debug { "Ignored ActiveRecordPartitioning::NoActiveConnectionPoolError: #{e.message}" }
          false
        else
          raise e
        end
      end

      def render_with_benchmark(options = nil, extra_options = {}, &block)
        if logger
          # patched the following line
          if active_connection?
            db_runtime = ActiveRecord::Base.connection.reset_runtime
          end

          render_output = nil
          @view_runtime = Benchmark.ms { render_output = render_without_benchmark(options, extra_options, &block) }

          # patched the following line
          if active_connection?
            @db_rt_before_render = db_runtime
            @db_rt_after_render = ActiveRecord::Base.connection.reset_runtime
            @view_runtime -= @db_rt_after_render
          end

          render_output
        else
          render_without_benchmark(options, extra_options, &block)
        end
      end

    private
      def perform_action_with_benchmark
        if logger
          ms = [Benchmark.ms { perform_action_without_benchmark }, 0.01].max
          logging_view          = defined?(@view_runtime)
          # patched the following line
          logging_active_record = active_connection?

          log_message  = 'Completed in %.0fms' % ms

          if logging_view || logging_active_record
            log_message << " ("
            log_message << view_runtime if logging_view

            if logging_active_record
              log_message << ", " if logging_view
              log_message << active_record_runtime + ")"
            else
              ")"
            end
          end

          log_message << " | #{response.status}"
          log_message << " [#{complete_request_uri rescue "unknown"}]"

          logger.info(log_message)
          response.headers["X-Runtime"] = "%.0f" % ms
        else
          perform_action_without_benchmark
        end
      end

      def view_runtime
        "View: %.0f" % @view_runtime
      end

      def active_record_runtime
        db_runtime = ActiveRecord::Base.connection.reset_runtime
        db_runtime += @db_rt_before_render if @db_rt_before_render
        db_runtime += @db_rt_after_render if @db_rt_after_render
        "DB: %.0f" % db_runtime
      end
  end
end
