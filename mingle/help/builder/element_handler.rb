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

class ElementHandler

	def initialize output, root
		@html = output  #an instance of HtmlRenderer
		@root = root  #root of this document
		@copy_set = [] #these elements will just be copied to the output
		@apply_set = [] #these elements will get the recursive apply
		if defined?(REXML::Formatters)
		  @formatter = REXML::Formatters::Default.new
		end
	end

	def render
		handle @root
	end

	def handle aNode
		if aNode.kind_of? REXML::CData
			handleCdataNode(aNode)
		elsif aNode.kind_of? REXML::Text
			handleTextNode(aNode)
		elsif aNode.kind_of? REXML::Element
			handle_element aNode  
		else
			return #ignore comments and processing instructions
		end
	end
	
	def handle_element anElement	  
		handler_method = "handle_" + anElement.name.tr("-","_")
		if self.respond_to? handler_method
			self.send(handler_method, anElement)
		else
			if @copy_set.include? anElement.name
				copy anElement
			elsif @apply_set.include? anElement.name
				apply anElement
			else
				default_handler anElement
			end
		end
	end

	def default_handler anElement
		apply anElement
	end

	def copy anElement
		attr = nil
		if anElement.has_attributes?
			attr = {}
			anElement.attributes.each {|name, value| attr[name] = value}
		end
		@html.element(anElement.name, attr) {apply anElement}
	end

	def apply anElement
		# Handles all children. Equivalent to xslt apply-templates
		anElement.each {|e| handle(e)} if anElement
	end
	
	def handleTextNode aNode
		#HACKTAG this is an ugly hack to replace &apos; with ' since
		#IE cannot handle &apos. I haven't yet looked for a clean
		#way to do this nicely
		if aNode.to_s =~ /\S/
			output = ""
			if @formatter
			  @formatter.write(aNode, output)
			else
			  aNode.write(output)
			end
			output.gsub!("&apos;", "'")
			@html << output
		end
	end
	
	def handleCdataNode aNode
		# This did have a problem compressing whitespace, but seems to work now.
		output = ""
		output = aNode.to_s
		@html.cdata(output)
	end

end
