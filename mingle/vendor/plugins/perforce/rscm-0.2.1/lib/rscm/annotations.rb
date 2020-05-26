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

class Class
  @@anns = {}

  # Defines annotation(s) for the next defined +attr_reader+ or
  # +attr_accessor+. The +anns+ argument should be a Hash defining annotations
  # for the associated attr. Example:
  #
  #   require 'rscm/annotations'
  #
  #   class EmailSender
  #     ann :description => "IP address of the mail server", :tip => "Use 'localhost' if you have a good box, sister!"
  #     attr_accessor :server
  #   end
  #
  # The EmailSender class' annotations can then be accessed like this:
  #
  #   EmailSender.server[:description] # => "IP address of the mail server"
  #
  # Yeah right, cool, whatever. What's this good for? It's useful for example if you want to
  # build some sort of user interface (for example in on Ruby on Rails) that allows editing of
  # fields, and you want to provide an explanatory text and a tooltip in the UI.
  #
  # You may also use annotations to specify more programmatically meaningful metadata. More power to you.
  # 
  def ann(anns)
    $attr_anns ||= {}
    $attr_anns.merge!(anns)
  end

  def method_missing(sym, *args) #:nodoc:
    anns = @@anns[self]
    return superclass.method_missing(sym, *args) if(anns.nil?)
    anns[sym]
  end

  alias old_attr_reader attr_reader #:nodoc:
  def attr_reader(*syms) #:nodoc:
    @@anns[self] ||= {}
    syms.each do |sym|
      @@anns[self][sym] = $attr_anns.dup if $attr_anns
    end
    $attr_anns = nil
    old_attr_reader(*syms)
  end

  def attr_accessor(*syms) #:nodoc:
    attr_reader(*syms)
    attr_writer(*syms)
  end
end
