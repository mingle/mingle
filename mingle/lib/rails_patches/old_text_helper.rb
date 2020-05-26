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

# This is the auto_link functionality from Rails 2.1.  We are using it, at least temporarily, to make renderable/base_test.rb pass.
# Unlike the Rails 2.3 version, this code does not escape & characters.  Also, this code strips the <p></p> tags that our redcloth
# substitution puts around the link.
#
# The following code is changed from the Rails 2.1 code as follows:
#  - auto_link method is renamed to original_auto_link
#  - definition of AUTO_LINK_RE is removed (we already have a def'n of this)


module ActionView
  module Helpers
    module TextHelper
      
      def original_auto_link(text, link = :all, href_options = {}, &block)
        return '' if text.blank?
        case link
          when :all             then original_auto_link_email_addresses(original_auto_link_urls(text, href_options, &block), &block)
          when :email_addresses then original_auto_link_email_addresses(text, &block)
          when :urls            then original_auto_link_urls(text, href_options, &block)
        end
      end
      
      private
      
      def original_auto_link_urls(text, href_options = {})        
        extra_options = tag_options(href_options.stringify_keys) || ""
        text.gsub(AUTO_LINK_RE) do
          all, a, b, c, d = $&, $1, $2, $3, $4
          if a =~ /<[^>]+$/ && d =~ /^[^>]*>/ # don't replace URL's that are already linked, copied from rails 2.3.5 test_helper.rb auto_link_urls
            all
          else
            text = b + c
            text = yield(text) if block_given?
            c = c.gsub("&amp;", "&")
            %(#{a}<a href="#{b=="www."?"http://www.":b}#{c}"#{extra_options}>#{text}</a>#{d})
          end
        end
      end

      # Turns all email addresses into clickable links.  If a block is given,
      # each email is yielded and the result is used as the link text.
      def original_auto_link_email_addresses(text)
        body = text.dup
        #bug 9486 this improved regex generally works unless you put tags inside the anchor but that is hightly unusual
        text.gsub(/(<a[^<]+)?([\w\.!#\$%\-+.]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)+)/) do |match|
          inside_an_anchor = $1
          email = $2
          unless inside_an_anchor
            display_text = (block_given?) ? yield(email) : email
            %{<a href="mailto:#{email}">#{email}</a>}
          else
            match
          end
        end
      end
      
    end
  end
end
