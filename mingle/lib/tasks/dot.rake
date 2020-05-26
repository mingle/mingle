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
# dot.rake
# Creates a DOT format file showing the model objects and their associations
# Authors:
#   Matt Biddulph - http://www.hackdiary.com/archives/000093.html
#   Alex Chaffee - http://www.pivotallabs.com/
# Usage:
#  rake dot
#  To open in OmniGraffle, run
#    open -a 'OmniGraffle' model.dot

desc "Generate a DOT diagram of the ActiveRecord model objects in 'model.dot'"
task :dot => :environment do
  Dir.glob("app/models/*rb") { |f|
    require f
  }
  File.open("model.dot", "w") do |out|
    out.puts "digraph x {"
    out.puts "\tnode [fontname=Helvetica,fontcolor=blue]"
    out.puts "\tedge [fontname=Helvetica,fontsize=10]"
    Dir.glob("app/models/*rb") { |f|
      f.match(/\/([a-z_]+).rb/)
      classname = $1.camelize
      begin
        klass = Kernel.const_get classname
        if (klass.class != Module) && (klass.superclass == ActiveRecord::Base)
          out.puts "\t#{classname}"
          klass.reflect_on_all_associations.each { |a|
            out.puts "\t#{classname} -> #{a.name.to_s.camelize.singularize} [label=#{a.macro.to_s}]"
          }
        end
      rescue Exception => e
        puts "Not including: #{classname}; #{e.message}"
      end
    }
    out.puts "}"
  end
  system "dot -Tpng model.dot -o model.png"
  puts "Could not write model.png. Please install graphviz (http://www.graphviz.org)." unless $?.success?
end