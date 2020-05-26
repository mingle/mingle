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

module JavascriptBuffer
  def javascript_with_rescue(body=nil, buffer_js=javascript_bufferable?, &block)
    body = capture(&block) if block_given?

    catch_statment =  if ActionView::Base.debug_rjs
      %{ if( typeof(console) != 'undefined') {
            console.log(e);
            throw(e);
         } else {
            alert(e.description);
            throw(e)
         }
      }
    else
      ""
    end

    body = body.gsub(/^\s*<script.*$/){""}
    body = body.gsub(/^\s*<\/script.*$/){""}
    body = body.gsub(/^\s*\/\/<!\[CDATA\[\s*$/){""}
    body = body.gsub(/^\s*\/\/\]\]>\s*$/){""}

    if buffer_js
      buffer_javascript body
      nil
    else
      result = javascript_tag(%{
        MingleJavascript.register(function() {
          try{
            #{body}
          }catch(e){
            #{catch_statment}
          }
        }.bind(window));
      })
      block_given? ? concat(result) : result
    end
  end

  def javascript_bufferable?
    request ||= controller.request
    !request.xhr? && request.format == Mime::HTML
    false
  end

  def buffer_javascript(js)
    @buffer_javascript_tags ||= ''
    @buffer_javascript_tags << js
    @buffer_javascript_tags << "\n"
  end

  def render_buffered_javascript
    if @buffer_javascript_tags
      javascript_with_rescue(@buffer_javascript_tags, false)
    end
  end

end
