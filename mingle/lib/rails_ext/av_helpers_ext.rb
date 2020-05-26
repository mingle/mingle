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

module ActionView
  module Helpers
    module TextHelper
      #overwrite link re, see #1790, #1792
      silence_warnings do
        AUTO_LINK_RE = %r{
                        (                          # leading text
                          <\w+.*?>|                # leading HTML tag, or
                          [^=!:'"/]|               # leading punctuation, or
                          ^                        # beginning of line
                        )
                        (
                          (?:https?://)|           # protocol spec, or
                          (?:www\.)                # www.*
                        )
                        (
                          [-\w]+                   # subdomain or domain
                          (?:\.[-\w]+)*            # remaining subdomains or domain
                          (?::\d+)?                # port
                          (?:/(?:(?:[~\w\+%-]|(?:[,.;:][^\s$]))+)?)* # path
                          (?:\?[^<,#\s]+)?           # query string, origin: (?:\?[\w\+%&=.;-]+)?
                          (?:\#[^<,\s]*)?            # origin: (?:\#[\w\-]*)?
                        )
                        ([[:punct:]]|\s|<|$)       # trailing text
                       }x
      end

      def humanize_join(nouns, conjunction='and')
        nouns.reject!(&:blank?)
        return nouns.first if nouns.size < 2
        [nouns[0..-2].join(", "), nouns[-1]].join(' ' + conjunction + ' ')
      end

      def pluralize_exists(count, unit)
        return unless count > 0
        pluralize(count, unit)
      end
    end

    module FormTagHelper
      def form_tag_with_user_access(url_for_options = {}, options = {}, *parameters_for_url, &block)
        if url_for_options.is_a?(String) || url_for_options.delete(:validate) != true || authorized?(url_for_options)
          form_tag_without_user_access(url_for_options, options, *parameters_for_url, &block)
        end
      end
      alias_method_chain :form_tag, :user_access

      # Rails 2.3.2 IE7 Bug: https://rails.lighthouseapp.com/projects/8994/tickets/633-patch-formtaghelper-submit_tag-with-disable_with-option-doesn-t-submit-the-button-s-value-when-clicked
      #   (see comments that says break IE)
      def submit_tag(value = "Save changes", options = {})
        options.stringify_keys!

        if disable_with = options.delete("disable_with")
          disable_with = "this.value='#{disable_with}'"
          disable_with << ";#{options.delete('onclick')}" if options['onclick']

          options["onclick"]  = "if (window.hiddenCommit) { window.hiddenCommit.setAttribute('value', this.value); }"
          # --- BEGIN PATCH ---
          # options["onclick"] << "else { hiddenCommit = this.cloneNode(false);hiddenCommit.setAttribute('type', 'hidden');this.form.appendChild(hiddenCommit); }"
          options["onclick"] << "else { hiddenCommit = document.createElement('input');hiddenCommit.type = 'hidden';"
          options["onclick"] << "hiddenCommit.value = this.value;hiddenCommit.name = this.name;this.form.appendChild(hiddenCommit); }"
          # --- END PATCH ---
          options["onclick"] << "this.setAttribute('originalValue', this.value);this.disabled = true;#{disable_with};"
          options["onclick"] << "result = (this.form.onsubmit ? (this.form.onsubmit() ? this.form.submit() : false) : this.form.submit());"
          options["onclick"] << "if (result == false) { this.value = this.getAttribute('originalValue');this.disabled = false; }return result;"
        end

        if confirm = options.delete("confirm")
          options["onclick"] ||= 'return true;'
          options["onclick"] = "if (!#{confirm_javascript_function(confirm)}) return false; #{options['onclick']}"
        end

        tag :input, { "type" => "submit", "name" => "commit", "value" => value }.update(options.stringify_keys)
      end
    end

    module FormHelper
      def form_for_with_user_access(record_or_name_or_array, *args, &proc)
        options = args.dup.extract_options!
        if options[:validate]
          form_for_without_user_access(record_or_name_or_array, *args, &proc) if authorized?(options[:url])
        else
          form_for_without_user_access(record_or_name_or_array, *args, &proc)
        end
      end
      alias_method_chain :form_for, :user_access
    end

    module JavaScriptHelper
      # modified to remove the anoying anchor generated to the link
      def link_to_function(name, *args, &block)
        html_options = args.last.is_a?(Hash) ? args.pop : {}
        function = args[0] || ''
        html_options.symbolize_keys!

        href = html_options[:href] || "javascript:void(0)"
        href = nil if html_options.delete(:without_href)

        function = update_page(&block) if block_given?
        content_tag(
          "a", name,
          html_options.merge({
            :href => href,
            :onclick => (html_options[:onclick] ? "#{html_options[:onclick]}; " : "") + "#{function}; return false;"
          })
        )
      end

      def link_to_function_with_user_access(name, *args, &block)
        options = args.last.is_a?(Hash) ? args.last : {}
        calling_action = options.delete(:accessing) || {}
        if authorized?(calling_action)
          link_to_function_without_user_access(name, *args, &block)
        end
      end
      alias_method_chain :link_to_function, :user_access

      def button_to_function_with_user_access(name, *args, &block)
        options = args.last.is_a?(Hash) ? args.last : {}
        calling_action = options.delete(:accessing) || {}
        if authorized?(calling_action)
          button_to_function_without_user_access(name, *args, &block)
        end
      end
      alias_method_chain :button_to_function, :user_access
    end

    module UrlHelper
      def link_to_with_user_access(name, options = {}, html_options = nil, *parameters_for_method_reference)
        if Thread.current[:controller_name].nil? || options.is_a?(String) || authorized?(options)
          link_to_without_user_access(name, options, html_options, *parameters_for_method_reference)
        end
      end

      def button_to_with_user_access(name, options = {}, html_options = {})
        if Thread.current[:controller_name].nil? || options.is_a?(String) || authorized?(options)
          button_to_without_user_access(name, options, html_options)
        end
      end

      alias_method_chain :link_to, :user_access
      alias_method_chain :button_to, :user_access

      private
      # extend original method with different auth token generation
      #   submit_function << "AuthenticityToken.appendToForm(f);"
      def method_javascript_function(method, url = '', href = nil)
        action = (href && url.size > 0) ? "'#{url}'" : 'this.href'
        submit_function =
          "var f = document.createElement('form'); f.style.display = 'none'; " +
          "this.parentNode.appendChild(f); f.method = 'POST'; f.action = #{action};"

        unless method == :post
          submit_function << "var m = document.createElement('input'); m.setAttribute('type', 'hidden'); "
          submit_function << "m.setAttribute('name', '_method'); m.setAttribute('value', '#{method}'); f.appendChild(m);"
        end

        if protect_against_forgery?
          submit_function << "AuthenticityToken.appendToForm(f);"
        end
        submit_function << "f.submit();"
      end
    end

    module PrototypeHelper
      class JavaScriptGenerator #:nodoc:
        module GeneratorMethods
          def replace_if_exists(id, *options_for_render)
            call "if($('#{id}')) Element.replace", id, render(*options_for_render)
          end
        end
      end

      def link_to_remote_with_user_access(name, options = {}, html_options = {})
        accessing = html_options.delete(:accessing)
        link_to_remote_without_user_access(name, options, html_options.merge(:accessing => accessing || options[:url]))
      end
      alias_method_chain :link_to_remote, :user_access

      def form_remote_tag_with_user_access(options = {}, &block)
        return if options.kind_of?(Hash) && options[:url].kind_of?(Hash) && options[:url].delete(:validate) == true && !authorized?(options[:url])
        form_remote_tag_without_user_access(options, &block)
      end
      alias_method_chain :form_remote_tag, :user_access
    end

    module TagAuthorizationExtension
      def content_tag_with_user_access(*args, &block)
        options = block_given? ? args[1] : args[2]
        authorizor = self.respond_to?(:on_options_authorized) ? self : (@controller || @template_object)
        authorizor.on_options_authorized(options) { content_tag_without_user_access(*args, &block) }
      end

      def tag_with_user_access(*args, &block)
        authorizor = self.respond_to?(:on_options_authorized) ? self : (@controller || @template_object)
        authorizor.on_options_authorized(args[1]) { tag_without_user_access(*args, &block) }
      end
    end

    module TagHelper
      include TagAuthorizationExtension
      alias_method_chain :tag, :user_access
      alias_method_chain :content_tag, :user_access
    end

    class InstanceTag
      include TagAuthorizationExtension
      alias_method_chain :tag, :user_access
      alias_method_chain :content_tag, :user_access
    end

    module DateHelper
      def time_ago_in_words(from_time, include_seconds = false)
        distance_of_time_in_words(from_time, Clock.now, include_seconds)
      end
    end

  end
end
