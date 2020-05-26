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

class TopicHandler < ElementHandler

  def initialize(html, root, topics)
    @topics = topics
    super(html, root)
  end

  def handle_chapter(element)
    handle_text_section(element, 3)
  end

  def handle_topic(element)
    handle_text_section(element, 4)
  end

  def handle_section(element)
    handle_text_section(element, 5)
  end

  def handle_subsection(element)
    handle_text_section(element, 6)
  end

  def handle_fragment(element)
    topic_root, filename = file_root(element, 'fragments/')
    topic_handler = TopicHandler.new(@html, topic_root, File.dirname(filename))
    topic_handler.render
  end

  def handle_text_section(element, heading_level, collapsed = false)
    if (element.attributes['file'])
      handle_included_text_section(element, heading_level)
    else
      handle_inline_text_section(element, heading_level, collapsed)
    end
  end

  def handle_included_text_section(element, heading_level)
    topic_root, filename = file_root(element)
    topic_handler = TopicHandler.new(@html, topic_root, File.dirname(filename))
    topic_handler.handle_text_section(topic_root, heading_level, element.attributes['collapsed'] == 'true')
  end

  def handle_inline_text_section(element, heading_level, collapsed)
    section_is_collapsed = element.attributes['collapsed'] == 'true' || collapsed
    id = element.attributes['id']
    collapse = heading_level > 3
    @html.div(element.name) do
      heading_attributes = id ? {'id' => id} : {}
      if collapse
        heading_attributes.merge!({'onclick' => 'toggleCollapse($(this));'})
        if section_is_collapsed
          heading_attributes.merge!({'class' => 'collapsed-heading'})
        else
          heading_attributes.merge!({'class' => 'collapsible-heading'})
        end
      end

      @html.element("h#{heading_level}", heading_attributes) do
        @html.text(element.attributes['title'])
      end
      collapsible_div_attributes = {'class' => 'content-container'}
      collapsible_div_attributes.merge!({'class' => 'content-container collapsed'}) if section_is_collapsed
      @html.element('div', collapsible_div_attributes) do
        apply(element)
      end
    end
  end

  def handle_p(element)
    @html.p do
      apply(element)
    end
  end

  def handle_note(element)
    handle_box("note", element)
  end

  def handle_warning(element)
    handle_box("warning", element)
  end

  def handle_hint(element)
    handle_box("hint", element)
    # @html.div('box hint') do
    #       @html.element('strong'){@html.text('Hint: ')}
    #       apply(element)
    #     end
  end

  def handle_code(element)
    @html.pre('code') do
      apply(element)
    end
  end

  def handle_strong(element)
    @html.element('strong') do
      apply(element)
    end
  end
  alias_method :handle_mql_grammar, :handle_strong
  alias_method :handle_mql_snippet, :handle_strong

  def handle_bullets(element)
    css_class = nil

    title = element.attributes['title']
    if title
      @html.h(5, 'bullets-title') do
        @html.text(title)
      end
      css_class = 'titled-bullets'
    end

    @html.ul(css_class) do
      apply(element)
    end
  end
  alias_method :handle_api_attributes, :handle_bullets

  def handle_steps(element)
    css_class = nil

    title = element.attributes['title']
    if title
      @html.h(5, 'steps-title') do
        @html.text(title)
      end
      css_class = 'titled-steps'
    end

    @html.ol(css_class) do
      apply(element)
    end
  end

  def handle_api_attribute(element)
    @html.li do
      @html.element('strong') do
        @html.text(element.attributes['name'])
      end
      @html.text ': '
      @html.text "#{element.attributes['type']}" if element.attributes['type']
      if element.attributes['readonly'] || element.text
        @html.text '; ' if element.attributes['type']
        if element.attributes['readonly'] || element.attributes['writeonly']
          @html.text(element.attributes['readonly'] ? 'read only' : 'update only')
          @html.text(element.text ? ', ' : '.')
        end
        apply(element)
      else
        @html.text '.'
      end
    end
  end

  def handle_item(element)
    @html.li do
      apply(element)
    end
  end

  def handle_cref(element)
    topic, section = element.attributes['topic'].split("#")
    if File.exist?(File.join(File.dirname(__FILE__), "../topics/#{topic}.xml"))
      if(@mode && @mode == 'book') then
        href = "##{section || topic}"
      else
        href = "#{topic}.html"
        href << "##{section}" if section
      end
    else
      href = "under_construction.html"
    end
    @html.a_ref(href) do
      apply(element)
    end
  end

  def handle_exref(element)
    href = element.attributes['url']
    if element.children.empty?
      @html.a_ref(href){@html.text href}
    else
      @html.a_ref(href) do
        apply(element)
      end
    end
  end

  def handle_video(element)
    handle_exref(element)
  end

  def handle_img(element, isIcon = false)
    image_path = element.attributes['src']
    absolute_file_path = File.join(File.dirname(__FILE__), '..', image_path)
    placeholder = !File.exist?(absolute_file_path)
    image_path = image_path.gsub(/\/images\//, '/placeholder_images/') if placeholder
    unless File.exist?(File.join(File.dirname(__FILE__), '..', image_path))
      puts "[WARNING] missing image #{image_path}"
      image_path = 'resources/images/placeholder_image.png'
    end
    attributes = {:src => image_path}
    attributes.merge!(:alt => element.attributes['alttext']) if element.attributes['alttext']
    attributes.merge!(:class => 'placeholder') if placeholder
    attributes.merge!(:class => placeholder ? 'placeholder icon' : 'icon') if isIcon
    @html.element('img', attributes){}
  end

  def handle_screenshot(element)
    handle_img(element)
  end

  def handle_todo(element)
    # @html.span('todo') do
    #   @html.text 'TODO: '
    #   apply(element)
    # end
  end

  def handle_br(element)
    @html.element('br'){apply(element)}
  end

  def handle_example(element)
    @html.element('div', 'class' => 'example'){apply(element)}
  end

  def handle_markup(element)
    @html.pre('markup'){apply(element)}
  end
  alias_method :handle_mql_example, :handle_markup

  def handle_formula(element)
    @html.pre('formula'){apply(element)}
  end

  def handle_markup_reference(element)
    @html.element('div', 'class'  => 'markup-reference') do
      @html.p('title'){@html.text(element.attributes['title'])} if element.attributes['title']
      apply(element)
    end
  end

  def handle_icon(element)
    handle_img(element, true)
  end

  def handle_preview(element)
    @html.p('preview') do
      @html.element('h4', 'class' => 'preview'){
        @html.text 'Preview'
      }
      apply(element)
    end
  end

  def handle_subst(element)
    @html.span('subst'){apply(element)}
  end

  def handle_table(element)
    init_row_cycle
    @html.element('table') do
        @html.element('caption') {@html.text(element.attributes['caption'])} if element.attributes['caption']
        apply(element)
    end
  end

  def handle_header_row(element)
    has_group = false
    element.parent.elements.each do |child|
      if(child.name == 'group') then
        has_group = true
        break
      end
    end
    render_header_row(element) if !has_group
  end

  def render_header_row(element)
    @html.element('tr', 'class' => 'table-header' ) { apply element }
  end

  def find_header_row(table)
    table.elements.each do |child|
      return child if(child.name == 'header-row')
    end
  end

  def handle_row(element)
    @html.element('tr', 'class' => row_cycle ) { apply element }
  end

  def handle_col_header(element)
    @html.element('th'){ apply element }
  end

  def handle_label(element)
    @html.element('th'){ apply element }
  end

  def handle_col(element)
    @html.element('td'){ apply element }
  end

  def handle_youtube(element)
    @html.element('object', 'width' => '480', 'height' => '385') do
      @html.element('param', 'name' => 'movie', 'value' => "https://www.youtube.com/p/#{element.attributes['playlist']}&#038;hl=en_US&#038;fs=1"){ apply element }
      @html.element('param', 'name' => 'allowFullScreen', 'value' => 'true'){ apply element }
      @html.element('param', 'name' => 'allowscriptaccess', 'value' => 'always'){ apply element }
      @html.element('embed', 'src' => "https://www.youtube.com/p/#{element.attributes['playlist']}&#038;hl=en_US&#038;fs=1",
        'type' => 'application/x-shockwave-flash', 'width' => '480', 'height' => '385', 'allowscriptaccess' => 'always',
        'allowfullscreen' => 'true'){ apply element }
    end
  end

  def handle_group(element)
    @html.element('tr', 'class' => 'group-head') do
      colspan = 1
      element.parent.elements.each do |child|
        if(child.name == 'header-row') then
          colspan = child.elements.size()
          break
        end
      end
      @html.element('th', {'colspan' => colspan, 'class' => 'group-header'}) { @html.text element.attributes['title'] }
      render_header_row(find_header_row(element.parent)) if element.attributes['col-headers'] && element.attributes['col-headers'] == 'true'
    end
    apply(element)
  end

  def setMode(mode)
    @mode = mode
    self
  end

  private

  def row_cycle
    if @row_cycle == 'odd' then
      @row_cycle = 'even'
    else
      @row_cycle = 'odd'
    end

    @row_cycle
  end

  def init_row_cycle
    @row_cycle = 'odd'
  end

  def handle_box(box_type, element)
    @html.text(%{
      <div class="#{box_type}-box" style="padding: 0px 0pt 0pt">
    	  <div class="ab-bg">
      		<span class="ab-corner lvl1"></span>
      		<span class="ab-corner lvl2"></span>
      		<span class="ab-corner lvl3"></span>
      		<span class="ab-corner lvl4"></span>
      	</div>
      	<div class="box-content">
    })

    @html.p('box'){apply(element)}

    @html.text(%{
        </div>
    	  <div class="ab-bg">
      		<span class="ab-corner lvl4"></span>
      		<span class="ab-corner lvl3"></span>
      		<span class="ab-corner lvl2"></span>
      		<span class="ab-corner lvl1"></span>
      	</div>
      </div>
    })
  end

  def file_root(element, path='')
    filename = "#{@topics}/#{path}#{element.attributes['file']}.xml"
    raise "#{filename} does not exist" unless File.exist?(filename)
    root = REXML::Document.new(File.new(filename)).root
    [root, filename]
  end

end
