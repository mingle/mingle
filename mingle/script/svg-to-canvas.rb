#!/usr/bin/env ruby
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


require "optparse"

require "rubygems"
require "nokogiri"

options = {}

parser = OptionParser.new do |opts|

  opts.banner = "Usage: #{File.basename $0} [options] file.svg [file-2.svg .. file-n.svg]"

  opts.separator ""
  opts.separator "OPTIONS:"

  opts.on("-s", "--scale N", Float, "Scale image. Takes an integer or floating point value") do |n|
    options[:scale] = n
  end

  opts.on("-h", "--help", "Show this message") do
    puts opts
    exit
  end

  opts.separator ""

end

parser.parse!

if ARGV.size == 0
  $stderr << parser.help
  exit 1
end

ARGV.each do |file|
  next unless file.end_with?(".svg")

  name = File.basename(file, ".svg").gsub(/\W/, "_").gsub(/^snake_/, "").split("_").map(&:capitalize).join("").sub(/^[A-Z]/) {|c| c.downcase}

  doc = Nokogiri::XML(File.read(file))

  main = doc.css("g g g")

  current_fill = nil

  fills = []

  scale = options[:scale] || 1

  puts "function #{name}(p) {"
  doc.traverse do |node|
    next unless node.element? && node.name == "rect"

    if (fill = node.attr("fill")) && current_fill != fill
      current_fill = fill

      unless fills.include?(fill)
        fills << fill
        puts %Q{  var color#{fills.find_index(current_fill)} = "#{fill}";}
      end

      puts %Q{  context.fillStyle = color#{fills.find_index(current_fill)};}
    end

    x, y = node.attr("x").to_i || 0, node.attr("y").to_i || 0
    w, h = node.attr("width").to_i || 0, node.attr("height").to_i || 0

    x *= scale
    y *= scale
    w *= scale
    h *= scale

    puts %Q{  context.fillRect(p.x * dot_width + #{x}, p.y * dot_width + #{y}, #{w}, #{h});}
  end
  puts "}"
  puts "\n\n"

end
