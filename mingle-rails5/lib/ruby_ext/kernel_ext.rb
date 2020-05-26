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

module Kernel

  @@logger = nil

  def self.logger=(new_logger)
    @@logger = new_logger
  end

  def self.logger
    @@logger
  end

  def log_error(error, message, options = {})
    raise "Kernel logger has not been set." if @@logger.nil?

    error = [error] unless error.respond_to?(:size)
    error.compact!
    message = error.first.message if message.nil? && !error.empty?
    message += '.' unless message.blank? || message.ends_with?('.')

    if (Kernel.logger.debug? || options[:force_full_trace])
      root_causes = []
      error.each do |e|
        trace_parts = e.backtrace || []
        root_causes << "#{e.class.name}:#{e.message}:\n#{trace_parts.join("\n")}"
      end
      root_cause = root_causes.join("\n\n")
      root_cause = error.empty? ? " " : "\n\nRoot cause:\n\n#{root_cause}\n\n"

      message = "ERROR #{message}#{root_cause}"
    else
      root_causes = []
      error.each{|e| root_causes << "#{e.message}"}
      root_cause = root_causes.join("\n\n")
      root_cause = error.empty? ? " " : "\n\nRoot cause:\n\n#{root_cause}\n\n"

      message = "ERROR #{message}#{root_cause}If you suspect a serious problem, please run Mingle with log level set to DEBUG to see the full detail of this error."
    end


    Kernel.logger.add(options[:severity] || Logger::ERROR, message)
  end

  # Taken from http://chrisroos.co.uk/blog/2006-10-20-boolean-method-in-ruby-sibling-of-array-float-integer-and-string
  def Boolean(string)
    return true if string == true || string =~ /^true$/i
    return false if string == false || string.blank? || string =~ /^false$/i
    raise ArgumentError.new("invalid value for Boolean: \"#{string}\"")
  end

end
