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

RedCloth
class RedCloth

  def block_textile_lists( text ) 
      text.gsub!( LISTS_RE ) do |match|
          lines = match.split( /\n/ )
          last_line = -1
          depth = []
          lines.each_with_index do |line, line_id|
              if line =~ LISTS_CONTENT_RE 
                  tl,atts,content = $~[1..3]
                  if depth.last
                      if depth.last.length > tl.length
                          (depth.length - 1).downto(0) do |i|
                              break if depth[i].length == tl.length
                              lines[line_id - 1] << "</li>\n\t</#{ lT( depth[i] ) }l>\n\t"
                              depth.pop
                          end
                      end
                      if depth.last and depth.last.length == tl.length
                          lines[line_id - 1] << '</li>'
                      end
                  end
                  #----------- added code
                  if depth.last && depth.last.length == tl.length && depth.last != tl && depth.last[0..-2] == tl[0..-2]
                    lines[line_id - 1] << "</#{lT(depth.last)}l>"
                    depth.delete(depth.last)
                  end
                  #------------ end
                  unless depth.last == tl
                      depth << tl
                      atts = pba( atts )
                      atts = shelve( atts ) if atts
                      lines[line_id] = "\t<#{ lT(tl) }l#{ atts }>\n\t<li>#{ content }"
                  else
                      lines[line_id] = "\t\t<li>#{ content }"
                  end
                  last_line = line_id

              else
                  last_line = line_id
              end
              if line_id - last_line > 1 or line_id == lines.length - 1
                  depth.delete_if do |v|
                      lines[last_line] << "</li>\n\t</#{ lT( v ) }l>"
                  end
              end
          end
          lines.join( "\n" )
      end
  end
  
  def inline_textile_image( text ) 
      text.gsub!( IMAGE_RE )  do |m|
          stln,algn,atts,url,title,href,href_a1,href_a2 = $~[1..8]
          match_text = "!#{$~.captures[3]}!"
          atts = pba( atts )
          atts = " src=\"#{ url }\"#{ atts }"
          atts << " title=\"#{ title }\"" if title
          atts << " alt=\"#{ title.blank? ? ERB::Util::h(match_text) : title }\""

          href, alt_title = check_refs( href ) if href
          url, url_title = check_refs( url )

          out = ''
          out << "<a#{ shelve( " href=\"#{ href }\"" ) }>" if href
          out << "<img#{ shelve( atts ) } />"
          out << "</a>#{ href_a1 }#{ href_a2 }" if href
          
          if algn 
              algn = h_align( algn )
              if stln == "<p>"
                  out = "<p style=\"float:#{ algn }\">#{ out }"
              else
                  out = "#{ stln }<div style=\"float:#{ algn }\">#{ out }</div>"
              end
          else
              out = stln + out
          end

          out
      end
  end
end
