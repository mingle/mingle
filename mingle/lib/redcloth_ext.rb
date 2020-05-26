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

require 'redcloth'

class RedCloth

  # Re-define MARKDOWN_REFLINK_RE to not hijack Mingle href syntax of "list?filters[]=[Type][is][Story]" in <a href='...'>link</a>.
  remove_const(:MARKDOWN_REFLINK_RE) if defined?(MARKDOWN_REFLINK_RE)
  MARKDOWN_REFLINK_RE = /
          [^=^\]]             # ***** do not match it if char before [foo][bar] is either '=' or ']'
          \[([^\[\]]+)\]      # $text
          [ ]?                # opt. space
          (?:\n[ ]*)?         # one optional newline followed by spaces
          \[(.*?)\]           # $id
      /x 

  private

  # Parses a Textile table block, building HTML from the result.
  def block_textile_table( text ) 
      text.gsub!( TABLE_RE ) do |matches|

          tatts, fullrow = $~[1..2]
          tatts = pba( tatts, 'table' )
          tatts = shelve( tatts ) if tatts
          rows = []

          fullrow.
          split( /\|$/m ).
          delete_if { |x| x.empty? }.
          each do |row|

              ratts, row = pba( $1, 'tr' ), $2 if row =~ /^(#{A}#{C}\. )(.*)/m
              
              cells = []
              row.split( '|' ).each do |cell|
                  ctyp = 'd'
                  ctyp = 'h' if cell =~ /^_/

                  catts = ''
                  catts, cell = pba( $1, 'td' ), $2 if cell =~ /^(_?#{S}#{A}#{C}\. ?)(.*)/

                  if cell.strip.present?
                      catts = shelve( catts ) if catts
                      cells << "\t\t\t<t#{ ctyp }#{ catts }>#{ cell }</t#{ ctyp }>" 
                  end
              end
              ratts = shelve( ratts ) if ratts
              #################################################################changed the following 3 lines
              if cells.any?
                rows << "\t\t<tr#{ ratts }>\n#{ cells.join( "\n" ) }\n\t\t</tr>"
              end
          end
          "\t<table#{ tatts }>\n#{ rows.join( "\n" ) }\n\t</table>\n\n"
      end
  end
  
  # Should be able to re-indent tab characters
  def flush_left( text )
      indt = 0
      if text =~ /^ /
          #### patch: replaced the space character with \s
          while text !~ /^\s{#{indt}}\S/
          #### end patch
              indt += 1
          end unless text.empty?
          if indt.nonzero?
              text.gsub!( /^ {#{indt}}/, '' )
          end
      end
  end
end

