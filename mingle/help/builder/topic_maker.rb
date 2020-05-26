# -*- coding: utf-8 -*-

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

class TopicMaker

  attr_accessor :css_styles, :page_header, :page_footer, :is_xhtml

  def initialize(source_file, toc_source_file, output_directory, google_search_enabled)
    output_file = File.new(File.join(output_directory, (File.basename(source_file, '.xml') + '.html')), 'w')
    @html = HtmlRenderer.new(output_file)
    @root = REXML::Document.new(File.new(source_file)).root
    topics = File.dirname(source_file)
    @body_handler = TopicHandler.new(@html, @root, topics)
    @toc_root = @@toc_root ||= REXML::Document.new(File.new(toc_source_file)).root
    @toc_handler = TocHandler.new(@html, @toc_root)
    @current_page_name = File.basename(source_file, '.xml')
    @google_search_enabled = google_search_enabled
  end

  def title_text
    (@root.elements['//chapter'] || @root.elements['//topic'] || @root.elements['//section'] || @root.elements['//subsection']).attributes['title']
  end

  def run
    render_page
    @html.close
  end

  def render_page
    @html << %{<!DOCTYPE html>\n}
    @html.element('html', html_attrs) do
      render_head
      @html.element('body') do
        if @google_search_enabled
          @html.element('div','id' => "search_form") do
            @html.text("Loading")
          end
        end

        @html.element('div', {'id' => 'hd'}) do
          @html.element('h5') do
            @html.element('a', {'href' => 'index.html'}) do
              @html.text('Help documentation')
            end
          end
        end

        @html.element('div', {'class' => 'container u-full-width u-max-full-width'}) do
          @html.element('div', {'class' => 'row'}) do
            @html.element('div', {'id' => 'nav', 'class' => 'three columns'}) do
              @html.comment "googleoff: all"
              @html.element('div') do
                @toc_handler.setCurrentEntryName(@current_page_name)
                @toc_handler.render
              end
              @html.comment "googleon: all"
            end
            @html.element('div', {'class' => 'nine columns main'}) do
              @html.element('button', 'class' => 'nav-toggle', 'onclick' => 'openNav()
') do
                t = @toc_handler.current_entry_title
                if t && !t.empty?
                  @html << t
                else
                  @html << "Menu"
                end
              end
              render_search_results_container
              @html.element('div', {'id' => 'help_content'}) do
                @body_handler.render
              end
            end
          end

          @html.element('div', {'id' => 'ft', 'class' => 'footer'}) do
            @html.text("Copyright #{Time.now.year} ThoughtWorks, Inc.")
          end
        end

        render_error('Your search <span class="search_term"></span>&nbsp;did not match any help pages.', 'style' => 'margin: 0;display:none; position:absolute; width:100%', 'id' => 'no_result_message')
      end
    end
  end

  def render_error(message, options={})
    @html.element('div', {'class' => 'error-box'}.merge(options)) do
      @html.text(%{
          <div class="ab-bg">
            <span class="ab-corner lvl1"></span>
            <span class="ab-corner lvl2"></span>
            <span class="ab-corner lvl3"></span>
            <span class="ab-corner lvl4"></span>
          </div>
          <div class="box-content">
      })

      @html.div('box'){ @html.text(message) }

      @html.text(%{
          </div>
          <div class="ab-bg">
            <span class="ab-corner lvl4"></span>
            <span class="ab-corner lvl3"></span>
            <span class="ab-corner lvl2"></span>
            <span class="ab-corner lvl1"></span>
          </div>
      })
    end
  end
  def render_round_corner_action_bar(options={})
    @html.element("div", {'class' => "action-bar", "inner_wrapper_class" => "action-bar-inner-wrapper"}.merge(options)) do
      @html.element("div", "class" => 'ab-bg') do
        @html.element("span", "class" => "ab-corner lvl1") {}
        @html.element("span", "class" => "ab-corner lvl2") {}
        @html.element("span", "class" => "ab-corner lvl3") {}
        @html.element("span", "class" => "ab-corner lvl4") {}
      end

      @html.element("div", "class" => "action-bar-inner-wrapper") do
        yield
      end

      @html.element("div", "class" => 'ab-bg') do
        @html.element("span", "class" => "ab-corner lvl4") {}
        @html.element("span", "class" => "ab-corner lvl3") {}
        @html.element("span", "class" => "ab-corner lvl2") {}
        @html.element("span", "class" => "ab-corner lvl1") {}
      end
    end
  end

  def render_search_results_container
    @html.element('div','id' => "search_results_container") do
      render_round_corner_action_bar do
        @html.element("a", 'id' => 'hide_search_results', "href" => "") do
          @html.text 'Back to previous page'
        end
      end

      @html.element('div', 'id' => 'branding') {}
      @html.element('div', 'id' => 'search_results') do
      end
    end
  end

  def render_toc
    @html.element('div', {'class' => 'toc'}) do
      @toc_root = REXML::Document.new(File.new(source_file)).root
    end
  end

  def html_attrs
    if @is_xhtml
      return { 'xmlns' => 'http://www.w3.org/1999/xhtml',
               'xml:lang' => "en",
               'lang' => "en"}
    else return {}
    end
  end

  def render_head
    html_head_title title_text
  end

  def html_head_title title
    @html.element 'head' do
      @html.element('meta', 'http-equiv' => 'Content-Type', 'content' => 'text/html; charset=UTF-8')
      @html.element('meta', 'name' => 'viewport', 'content' => "width=device-width, initial-scale=1")
      @html.element('link', 'href' => "https://www.thoughtworks.com/mingle/docs/#{@current_page_name}.html", 'rel' => 'canonical')
      @html.element('title') { @html.text title }
      @html.element('link', 'rel' => 'shortcut icon', 'href' => "resources/images/favicon_blue.ico")
      @html.element('link', 'href' => '//fonts.googleapis.com/css?family=Raleway:400,300,600', 'rel' => 'stylesheet', 'type' => 'text/css')
      @html.element('link', 'href' => 'resources/stylesheets/normalize.css', 'rel' => 'stylesheet', 'type' => 'text/css')
      @html.element('link', 'href' => 'resources/stylesheets/skeleton.css', 'rel' => 'stylesheet', 'type' => 'text/css')
      @html.element('link', 'href' => 'resources/stylesheets/help.css', 'rel' => 'stylesheet', 'type' => 'text/css')
      @html.element('link', 'href' => 'resources/stylesheets/mingle_search.css', 'rel' => 'stylesheet', 'type' => 'text/css')
      @html.element('script', 'src' => 'resources/javascript/jquery-1.10.1.min.js', 'type' => 'text/javascript')
      @html.element('script', 'type' => 'application/javascript') {
        @html.text "var $j = jQuery.noConflict();\n"
        @html.text "var URL = #{ENV['MINGLE_HELP_SEARCH_URL'].inspect};\n";
        @html.text "var PAGE_SIZE = #{ENV['SEARCH_RESULTS_PAGE_SIZE']}";
      }
      @html.element('script', 'src' => 'resources/javascript/jquery-pagination-1.4.1.min.js', 'type' => 'text/javascript')
      @html.element('script', 'src' => 'resources/javascript/prototype.js', 'type' => 'text/javascript')
      @html.element('script', 'src' => 'https://www.google.com/jsapi', 'type' => 'text/javascript') if @google_search_enabled
      @html.element('script', 'src' => 'resources/javascript/mingle_search.js', 'type' => 'text/javascript') if @google_search_enabled
      @html.element('script', 'src' => 'resources/javascript/mingle_help.js', 'type' => 'text/javascript')
    end
  end

  def up_to_date input, output
    return false if not File.exists? output
    return File.stat(output).mtime > File.stat(input).mtime
  end

  def render_under_construction
    @html.element('div', {'class' => 'under-construction-container'}) do
      @html.element('div', {'class' => 'under-construction-content'}) do
        @html.element('p', {'class' => 'strong'}) do
          @html.text 'We\'re not quite finished yet!'
        end

        @html.element('p') do
          @html.text 'The help text provided for this Early Access release is provisional.'
        end

        @html.element('p') do
          @html.text 'Please bear with us while we work to finalize it for the full release.'
        end
      end
    end
  end

end
