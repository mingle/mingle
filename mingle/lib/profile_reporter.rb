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

class ProfileReporter
  class << self
    def profile(interval, &block)
      data = nil
      report_output = nil

      prof = SamplingProf.new(interval) do |d|
        data = d
      end

      begin
        prof.profile do
          yield
        end
      ensure
        prof.terminate
      end

      if data
        report_output = StringIO.new
        profile_report(data, report_output)
      end
      report_output
    end

    private

    def profile_report(data, output)
      runtime, nodes, counts, call_graph = data.split("\n\n")
      nodes = nodes.split("\n").inject({}) do |ret, l|
        n, i = l.split(',')
        ret[i.to_i] = n
        ret
      end

      counts = counts.split("\n").map do |l|
        l.split(',').map(&:to_i)
      end
      total_samples, report = flat_profile_report(nodes, counts)

      output.puts "runtime: #{runtime.to_f/1000} secs"
      output.puts "total samples: #{total_samples}"
      output.puts "self\t%\ttotal\t%\tname"
      report.each do |v|
        output.puts v.join("\t")
      end
    end

    def flat_profile_report(nodes, counts)
      total = counts.map{|_,sc,tc| sc}.reduce(:+)
      reports = counts.sort_by{|_,sc,tc| -tc}.map do |id, sc, tc|
        [sc, '%.2f%' % (100 * sc.to_f/total),
         tc, '%.2f%' % (100 * tc.to_f/total),
         nodes[id]]
      end
      [total, reports]
    end
  end

end
