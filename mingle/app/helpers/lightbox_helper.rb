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

module LightboxHelper
  def render_in_lightbox(partial_name, options={})
    lightbox_opts = options.delete(:lightbox_opts) || {}

    lightbox_content = render_to_string(options.merge(:partial => partial_name))
    render(:update) do |page|
      unless options[:replace]
        init_options = if (after_update = lightbox_opts.delete(:after_update))
          # after_update is a function, so insert without to_json; called after content is set
          "jQuery.extend({afterUpdate: #{after_update}}, #{js_options(lightbox_opts)})"
        else
          js_options(lightbox_opts)
        end

        if (prepend_script = lightbox_opts.delete(:prepend_script))
          page << prepend_script
        end
        page << "InputingContexts.push(new LightboxInputingContext(null, #{init_options}));"
      end
      page.inputing_contexts.update lightbox_content
    end
  end

  def link_to_close_lightbox(link_name="Close", html_options={})
    link_to_function link_name, "InputingContexts.pop(); #{html_options.delete(:onclick)}", {:class => 'popup-close'}.merge(html_options)
  end

  def lightbox_fix_height_js(target, height_offset, width)
    "if($('lightbox')){$('lightbox').setStyle({height: ($('#{target}').getHeight() + #{height_offset}) + 'px', width: #{width}})};"
  end

  def lightbox_loading_message
    render :partial => "shared/lightbox_loading_message"
  end

  def asynch_request_progress_lightbox_fix_height_js
    lightbox_fix_height_js('asynch-request-progress-div', 100, "'50em'")
  end

  def lightbox_close_button(html_options={})
    skip_default_click_handler = html_options.delete(:skip_default_click_handler)
    extra_classes = html_options.delete(:class) || ''
    html_options[:onclick] = "InputingContexts.pop();#{html_options[:onclick]}" unless skip_default_click_handler
    content_tag(:div, html_options.merge(:class => "#{extra_classes} close-button")) do
      content_tag(:span, '', :class => 'x fa fa-times')
    end
  end
end
