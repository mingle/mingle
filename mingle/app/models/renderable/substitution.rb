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

module Renderable
  # $trace = true
  TAG_FRAGMENT = /<(\/?\w+[^>]*)>/
  SCRIPT_TAG_FRAGMENT = /<(\/?script[^>]*)>/i
  STYLE_TAG_FRAGMENT = /<(\/?(\s*)style[^>]*)>/i

  PROJECT_GROUP = "project-group"

  class Substitution
    attr_reader :context

    def initialize(context={})
      @context = context
    end

    def apply(content)
      ActiveSupport::GsubSafety.unsafe_substitution_retaining_html_safety(content) do |content|
        return content unless content =~ pattern
        content.gsub(pattern) { |match| substitute($~) }
      end
    end

    def project
      context[:project]
    end

    def content_provider
      context[:content_provider]
    end

    def view_helper
      context[:view_helper]
    end

    def no_textile(content)
      (content_provider && content_provider.redcloth) ? content.no_textile : content
    end

    def no_textile_block(content)
      (content_provider && content_provider.redcloth) ? content.no_textile_block : content
    end

  end

  class SanitizeSubstitution < Substitution
    def apply(content)
      context[:view_helper].sanitize(content)
    end
  end

  class RedClothSubstitution < Substitution

    def textile_rules
      [:refs_textile, :block_textile_table, :block_textile_lists,
       :block_textile_prefix, :inline_textile_image, :inline_textile_link,
       :inline_textile_code, :inline_textile_span, :glyphs_textile]
    end

    # removed rule :block_markdown_atx from defaults for fixing bug 1814
    def markdown_rules
      [:refs_markdown, :block_markdown_setext, :block_markdown_rule,
       :block_markdown_bq, :block_markdown_lists,
       :inline_markdown_reflink, :inline_markdown_link]
    end

    def apply(content)
      rip_macros(content) do |c|
        c.apply_redcloth(:no_span_caps => true, :rules => (self.markdown_rules + self.textile_rules))
      end
    end

    private

    INSIDE_TAG_MACRO_MARK = "MACROSce2wqfwfsadffejllkje59f4f99f1"
    def rip_macros(content)
      inside_tag_macros = []

      content = content.gsub(/(<([^>]*)>)/m) do |match|
        match.gsub!(/#{MacroSubstitution::MATCH}/m) do |inner|
          inside_tag_macros << inner.to_s.escape_html
          INSIDE_TAG_MACRO_MARK
        end
        match
      end

      content.gsub!(/#{MacroSubstitution::MATCH}/m) do |match|
        no_textile(match.to_s.escape_html)
      end

      result = yield(content)

      if context[:conversion_to_html_in_progress]
        result.gsub!(/#{MacroSubstitution::MATCH}/m) do |match|
          CGI::unescapeHTML(match.to_s)
        end
      end

      result.gsub(INSIDE_TAG_MACRO_MARK) do |m|
        inside_tag_macro = inside_tag_macros.shift
        inside_tag_macro = CGI::unescapeHTML(inside_tag_macro) if context[:conversion_to_html_in_progress]
        inside_tag_macro
      end.html_safe
    end
  end

  class EscapeHTMLInsideCodeAndPreTagsSubstitution < Substitution

    def pattern
      /<code[^>]*>(.+?)<\/code>|<pre[^>]*>(.+?)<\/pre>/mi
    end

    def substitute(match)
      if match[1]
        "<code>#{escapify(match[1])}</code>"
      else
        "<pre>#{escapify(match[2])}</pre>"
      end
    end

    private

    def escapify(text)
      CGI.escapeHTML(text)
    end

  end

  class EscapeMingleSpecificMarkupInsideCodeAndPreTagsSubstitution < EscapeHTMLInsideCodeAndPreTagsSubstitution

    private

    def finders_and_replacers
      {
        '!' => '&#33;',
        /(^|[^&])#(\d+)/ => '&#35;\2',
        /\[\[(\w+)\]\]/ => '&#91;&#91;\1&#93;&#93;',
        '{{' => '&#123;' * 2,
        '}}' => '&#125;' * 2
      }
    end

    def escapify(text)
      text.tap do |string|
        finders_and_replacers.each { |finder, replacer| string.gsub!(finder, replacer) }
      end
    end

  end

  class EnsureLastElementAppendableSubstituion

    def initialize(context);   end

    def apply(original)
      doc = Nokogiri::HTML::DocumentFragment.parse(original)
      doc.xpath("//div").remove_class('clear_float').remove_class('clear-both')
      doc.to_xhtml
    end

  end

  module CardLinkSubstitutionHelper
    def apply(content)
      return content if content !~ pattern
      return ActiveSupport::GsubSafety.unsafe_substitution_retaining_html_safety(content) do |content|
        content.gsub(pattern) do
          match = $~
          pre = $`
          post = $'
          original = $&
          next original if html_anchor?(pre)
          escaped?(pre, match[0], post) ? original : substitute(match)
        end
      end
    end

    def html_anchor?(pre)
      pre =~ /(^|\s)([^\s]*)$/
      $2.starts_with?('http://') || $2.starts_with?('https://')
    end

    def seemingly_in_the_context_of_a_src_attribute?(pre)
      pre =~ /src=["'\w:.\/]+$/ #This is a lame ass implementation, but it is only as lame as the previous one, and much faster.
    end

    def is_linked_aleady?(pre)
      pre =~ /<a/ && pre.scan('<a').length != pre.scan('</a').length
    end

    def is_wrapped_in_escape_markup?(pre)
      pre.scan('<escape>').length != pre.scan('</escape>').length
    end

    def is_color?(pre, match)
      pre =~ /color:\s*/ && match =~ /;$/
    end

    def is_in_html_tag?(pre, post)
      pre =~ /<\w+\s[^>]*\z/ && post =~ /\A[^<]*>/
    end

    def escaped?(pre, match, post)
      seemingly_in_the_context_of_a_src_attribute?(pre) ||
      is_linked_aleady?(pre)  ||
      is_in_html_tag?(pre, post) ||
      is_wrapped_in_escape_markup?(pre) ||
      is_color?(pre, match) ||
      pre =~ /&$/  # cancel html code for example: &#8211;
    end
  end

  module CrossProjectSubstitutionHelper
    def project_identifier_regexp
      Caches::CrossProjectCache.with_cache do
        identifiers_string = Project.all(:select => 'identifier').collect(&:identifier).join('|')
        Caches::CrossProjectCache.add(identifiers_string)
        identifiers_string
      end
    end
    module_function :project_identifier_regexp

    def target_project(project_identifier)
      project_identifier.blank? ? project : Project.find_by_identifier(project_identifier)
    end

    def is_cross_project(project_identifier)
      project_identifier.present? && project_identifier.downcase != project.identifier.to_s.downcase
    end

    def record_rendered_project(project_identifier)
      if is_cross_project(project_identifier) && !content_provider.nil?
        content_provider.rendered_projects.push Project.find_by_identifier(project_identifier)
      end
    end
  end

  class CrossProjectCardSubstitution < Substitution
    include CardLinkSubstitutionHelper, CrossProjectSubstitutionHelper

    def pattern
      CardKeywords::CROSS_PROJECT_REGEXP
    end

    def substitute(match)
      project_identifier = match.captures[0]
      card_keyword = match.captures[3]
      card_number = match.captures[5]
      # when project identifier does not exist, we'll just return original match string for later CardSubstitution to rander
      # card link
      # see bug 7678
      return match.to_s unless keyword_belongs_to_project?(project_identifier, card_keyword)

      record_rendered_project(project_identifier)
      link_name = "#{project_identifier}#{match.captures[1]}/#{match.captures[2]}#{card_keyword}#{match.captures[4]}#{card_number}"

      view_helper.link_to(link_name,
                             {:controller => 'cards',
                             :project_id => project_identifier.downcase,
                             :action => 'show',
                             :number => card_number},
                             {:class => "card-link-#{card_number}"}) + match.captures[6].html_safe
    end

    private

    def keyword_belongs_to_project?(project_identifier, card_keyword)
      container_project = is_cross_project(project_identifier) ? Project.find_by_identifier(project_identifier.downcase) : project
      return false unless container_project
      container_project.card_keywords.include?(card_keyword)
    end
  end

  class DependencySubstitution < Substitution
    include CardLinkSubstitutionHelper

    def pattern
      /(?-mx:(#D)(\d+)(\W|$))/
    end

    def substitute(match)
      dep_number = match.captures[1]
      link_text = match.captures[0] + dep_number
      link_to_dep = view_helper.link_to_function link_text, "$j(this).showDependencyPopup()",
      { :class => "dependencies card-tool-tip card-link-#{dep_number}",
        :"data-card-name-url" => view_helper.url_for(:controller => "dependencies", :action => "dependency_name", :project_id => project.identifier, :number => dep_number),
        :"data-dependency-number" => dep_number,
        :"data-dependency-popup-url" => view_helper.url_for(:controller =>"dependencies", :action => "popup_show", :project_id => project.identifier) }

      link_to_dep + match.captures[2].html_safe
    end
  end

  class CardSubstitution < Substitution
    include CardLinkSubstitutionHelper

    def pattern
      project.revision_regexp if project
    end

    def substitute(match)
      card_number = match.captures[2]
      link_name = match.captures[0] + match.captures[1] + card_number
      card_name_url = view_helper.send :url_for, :controller => 'cards', :action => 'card_name', :number => card_number, :project_id => project.identifier.downcase

      link_to_card_show = view_helper.link_to(link_name,
                    { :controller => 'cards',
                      :project_id => project.identifier,
                      :action => 'show',
                      :number => card_number },
                    {
                     :class => "card-tool-tip card-link-#{match.captures[2]}",
                     'data-card-name-url' => card_name_url
                    })

      link_to_card_show + match.captures[3].html_safe
    end
  end

  class AttachmentSubstitution < Substitution
    FILENAME_REGEX = "[A-Za-z0-9_\\-\\.]+"

    include CrossProjectSubstitutionHelper

    def pattern
      raise :subclass_responsibility
    end

    def substitute
      raise :subclass_responsibility
    end

    def card_attachment_named(attachment_name, card_number, project_identifier)
      card = if card_number
        target_project(project_identifier).with_active_project {|project| project.cards.find_by_number(card_number.to_i)}
      else
        content_provider
      end
      attachment = find_attachment(card, attachment_name)
    end

    def page_attachment_named(attachment_name, page_name, project_identifier)
      page = if page_name
        identifier = Page.name2identifier(page_name)
        target_project(project_identifier).pages.find_by_identifier(identifier)
      else
        content_provider
      end
      attachment = find_attachment(page, attachment_name)
    end

    def find_attachment(attachable, attachment_name)
      attachable.attachments.select { |a| a.file_name.ignore_case_equal?(attachment_name) }[0] if attachable.respond_to? :attachments
    end
  end

  class AttachmentLinkSubstitution < AttachmentSubstitution
    def pattern
      /(\[\[\s*((.+?)\s*\|\s*)?([\t ]*(#{project_identifier_regexp})[\t ]*\/[\t ]*)?((#)?(.+?)\/)?(#{AttachmentSubstitution::FILENAME_REGEX}?)\s*\]\])/i
    end

    def substitute(match)
      attachment = detect_attachment(match)
      if attachment
        matched_display_name = match.captures[2]
        matched_name = match.captures[8]
        link_name = "#{match.captures[3]}#{match.captures[5]}#{matched_name}"
        link_name = matched_display_name if matched_display_name
        attachment_link = view_helper.send(:project_attachment_path,
                                           :id => attachment.id,
                                           :project_id => attachment.project.identifier)

        no_textile_block(view_helper.link_to(link_name, view_helper.prepend_protocol_with_host_and_port(attachment_link), :target => 'blank'))
      else
        match.captures[0]
      end
    end

    def detect_attachment(match)
      matched_project_identifier = match.captures[4]
      matched_identifier = match.captures[7]
      matched_name = match.captures[8]
      matched_card = match.captures[6]

      return if (!matched_identifier.blank? && matched_identifier.size > (matched_card ? 40 : 255))
      project_identifier = matched_project_identifier.to_s.downcase
      record_rendered_project(project_identifier)
      if matched_card
        return card_attachment_named(matched_name, matched_identifier, project_identifier)
      else
        return page_attachment_named(matched_name, matched_identifier, project_identifier)
      end
    end
  end

  class InlineImageSubstitution < AttachmentSubstitution

    def self.pattern
      # (?=) is a non-consuming positive lookahead. Checks that image does not start with whitespace.
      # (?!) is a non-consuming negative lookahead. Checks that image does not end with whitespace.
      /(!(?=[^\s])((#{CrossProjectSubstitutionHelper.project_identifier_regexp})\/)?((#)?([^!\/]+?)\/)?(?!([^!\/]+?)\s!)(#{AttachmentSubstitution::FILENAME_REGEX}?)!(\{([^\}]+)\})?)/i
    end

    def pattern
      InlineImageSubstitution.pattern
    end

    def detect_attachment(match)
      matched_project_identifier = match.captures[2]
      matched_identifier = match.captures[5]
      matched_name = match.captures[7]
      matched_card = match.captures[4]


      return if (!matched_identifier.blank? && matched_identifier.size > (matched_card ? 40 : 255))

      project_identifier = matched_project_identifier.to_s.downcase

      record_rendered_project(project_identifier)
      attachment = if matched_card
        card_attachment_named(matched_name, matched_identifier, project_identifier)
      else
        page_attachment_named(matched_name, matched_identifier, project_identifier)
      end
      attachment || nonexistent_attachment(content_provider)
    end

    def substitute(match)
      attachment = detect_attachment(match)
      return match[0] unless attachment
      attachment_url = view_helper.send(:project_attachment_path,
                                        :id => attachment.id,
                                        :project_id => attachment.project.identifier)
      "!(mingle-image)#{view_helper.prepend_protocol_with_host_and_port(attachment_url)}!"
    end

    private

    def nonexistent_attachment(content_provider)
      nil
    end

  end

  class ProtectMingleImageDuringConversionSubstitution < InlineImageSubstitution

    def substitute(match)
      match.to_s.no_textile
    end
  end

  class WYSIWYGInlineImageSubstitution < InlineImageSubstitution
    def substitute(match)
      attachment = detect_attachment(match)
      return match.captures[0] unless attachment
      attachment_url = view_helper.url_for(:controller => "attachments", :action => "show", :project_id => attachment.project.identifier, :id => attachment.id)

      style = match.captures[9] ? "style=\"#{match.captures[9]}\"" : nil
      attrs = ["class=\"mingle-image\"", "alt=\"#{match.captures[0]}\"", "src=\"#{view_helper.prepend_protocol_with_host_and_port(attachment_url)}\"", style].compact

      "<img #{attrs.join(" ")}/>"
    end

    private

    def nonexistent_attachment(content_provider)
      OpenStruct.new(:content_provider => content_provider).tap do |o|
        def o.id
          Attachment::NON_EXISTENT
        end

        def o.project
          content_provider.rendered_projects.last || content_provider.project
        end

      end
    end
  end


  class NullInlineImageSubstitution < InlineImageSubstitution
    def substitute(match)
    end
  end

  class WikiLinkSubstitution < Substitution
    include CrossProjectSubstitutionHelper

    def pattern
      /\[\[([\t ]*([^|\]]+?)[\t ]*\|)?[\t ]*((#{project_identifier_regexp})[\t ]*\/[\t ]*)?([^\]]*?)[\t ]*\]\]/i
    end

    def substitute(match)
      matched_project_identifier = match.captures[3]
      matched_display_name = match.captures[1]

      original = match.string
      page = match.captures[4]
      page = CGI.unescapeHTML(page)
      project_identifier = matched_project_identifier.to_s.downcase
      target_proj = target_project(project_identifier)

      if match.pre_match =~ /\\$/
        original
      else
        error = Page.validate_page_name page
        link_name = "#{match.captures[2]}#{page}"
        link_name = matched_display_name unless matched_display_name.blank?

        record_rendered_project(project_identifier)
        if error.nil?
          identifier = Page.name2identifier(page)

          html_options = target_proj.pages.page_exists?(identifier) ? {} : {:class => 'non-existent-wiki-page-link'}
          no_textile_block(view_helper.link_to(ERB::Util::h(link_name),
            {:controller => 'pages',
            :pagename => identifier,
            :action => 'show',
            :project_id => target_proj.identifier}, html_options))
        else
          error_msg = error + ' You cannot create this page.'
          no_textile_block(view_helper.link_to(ERB::Util::h(link_name), {
              :project_id => target_proj.identifier,
              :controller => 'projects', # can't go to pages controller, because the routes for pages would handle action as page identifier
              :action => 'show_page_name_error',
              :error_msg => ERB::Util::url_encode(error_msg),
              :page_name => page,
              :page_url => view_helper.url_for({}) # web-kit has a bug that when do right click and open in new tab, it doest not set http_referer
            }, {
              :class => 'error_link', :title => error
            }))
        end
      end
    end
  end

  class ProtectWikiLinksDuringConversionSubstitution < WikiLinkSubstitution
    def substitute(match)
      match.to_s.no_textile
    end
  end

  class MacroSubstitution < Substitution
    include HelpDocHelper
    MATCH = /\{\{\s*([^}\s]*):?([^}]*)\}\}/
    def pattern
      MATCH
    end

    def macro_count(content)
      macros = {}
      content.scan(MATCH) do |m|
        macro_name = m.first.strip
        macros[macro_name] = (macros[macro_name] || 0) + 1
      end
      macros
    end

    def macro_name(macro)
      match = macro.match(MATCH)
      return '' unless match && !match.captures.empty?

      name = match.captures[0]
      if name =~ /(.*):$/
        name = $1
      end
      name
    end

    def macro_parameters(macro)
      match = macro.match(MATCH)
      params = {}
      macro_name = macro_name(macro)
      return params if macro_name.empty?
      return {macro_name => Macro.parse_parameters(unescapeHTML(match.captures[1]))}
    rescue
      nil
    end

    def rendered_macros
      @rendered_macros ||= []
    end

    def increment_macro_position_index
      context[:macro_position] ||= 0
      context[:macro_position] += 1
    end

    def inline_macros
      ['project', 'project-variable', 'value']
    end

    def substitute(match)
      # check whether there was a quoting just before the match
      # in that case return $& thereby cancelling the substitution
      original = $&
      if $` =~ /\\$/
        original
      else
        begin
          name = match.captures[0]
          rendered_macros << name
          increment_macro_position_index
          return match if context[:dry_run]
          return placeholder(name) if (context[:edit] && !context[:preview]) && !inline_macros.include?(name.downcase)
          parameters = Macro.parse_parameters(unescapeHTML(match.captures[1]))
          macro = instantiate_macro(context, name, parameters, unescapeHTML(match[0]))
          used_projects = projects_used_in_macro(parameters)
          if user_cannot_access?(used_projects)
            return %{
              This content contains data for one or more projects of which you are not a member. To see this content you must be a member of the following #{'projects'.plural(used_projects.size)}: #{used_projects.collect(&:name).bold.to_sentence}.
            }

          end
          rendered_content = macro.execute
          render_placeholder = (rendered_content =~ SCRIPT_TAG_FRAGMENT && (!macro.chart? || context[:render_placeholder_for_description]))
          if (context[:preview] || context[:edit]) && (render_placeholder || rendered_content.blank?)
            return placeholder(name)
          end
          content_provider.can_be_cached = false unless macro.can_be_cached?
          rendered_content
        rescue TimeoutError => e
          raise(e)
        rescue StandardError => e
          handle_macro_error(name, e, CGI::unescapeHTML(match.to_s))
        ensure
          context[:project] = context[:content_provider_project]  # reset back to host projectexp
        end
      end
    end

    def placeholder(name="macro")
      readable_name = name.gsub("-", " ")
      "<div class='macro-placeholder'>Your #{readable_name} will display upon saving</div>"
    end

    def projects_used_in_macro(parameters)
      projects = []
      if parameters && parameters['project']
        project_identifier = ValueMacro.project_identifier_from_parameters(parameters, context[:content_provider])
        projects << Project.find_by_identifier(project_identifier.to_s)
      end

      if parameters && parameters[Renderable::PROJECT_GROUP]
         parameters[Renderable::PROJECT_GROUP].split(",").each do |p|
           projects << Project.find_by_identifier(p.strip)
         end
      end

      if series = parameters && parameters['series']
        series.each do |single_series|
          projects << Project.find_by_identifier(single_series['project']) if single_series['project']
        end
      end
      projects.compact.uniq
    end

    def handle_macro_error(name, e, original=nil)
      content_provider.add_macro_execution_error(e)
      if macro_registered?(name)
        message = e.respond_to?(:context_project) && e.context_project ?
          "Error in #{name} macro using #{e.context_project.name} project: #{e.message}" :
          "Error in #{name} macro: #{e.message}"
      else
        message = e.message
      end
      %Q[<div contenteditable="false" class="error macro" raw_text="#{URI.escape(original)}">#{ERB::Util.h message}</div>].html_safe
    end

    protected

    def instantiate_macro(macro_context, name, parameters, raw_content)
      if name =~ /(.*):$/
        name = $1
      end

      plugged_in_macro = MinglePlugins::Macros[name]
      if plugged_in_macro
        CustomMacroWrapper.new(plugged_in_macro, macro_context, parameters, raw_content)
      else
        NativeMacroWrapper.new(name, plugged_in_macro, macro_context, parameters, raw_content)
      end
    end

    private

    def user_cannot_access?(projects)
      !User.current.all_accessible?(projects)
    end

    def unescapeHTML(string)
      CGI::unescapeHTML(string.html_safe? ? String.new(string) : string)
    end

    def macro_registered?(name)
      Macro.registered?(name) || MinglePlugins::Macros.registered?(name)
    end

    def help_link
      "<a href='#{link_to_help('MQL')}' target='blank'>MQL Help</a>"
    end

    class NativeMacroWrapper

      def initialize(name, macro_class, macro_context, parameters, raw_content)
        if parameters && parameters['project']
          begin
            project_identifier = ValueMacro.project_identifier_from_parameters(parameters, macro_context[:content_provider])
          rescue RuntimeError => e
            raise Macro::ProcessingError.new(e.message)
          end
          macro_context[:project] = Project.find_by_identifier(project_identifier.to_s)
          raise Macro::ProcessingError.new("There is no project with identifier #{project_identifier.bold}.") unless macro_context[:project]
        end

        @project = macro_context[:project]

        with_active_project_if_defined do
          @macro = Macro.create(name, macro_context, parameters, raw_content)
        end
      end

      def can_be_cached?
        @macro.can_be_cached?
      end

      def execute
        with_active_project_if_defined do
          @macro.execute
        end
      end

      def execute_with_body(body)
        with_active_project_if_defined do
          @macro.execute_with_body(body)
        end
      end

      def with_active_project_if_defined
        @project.with_active_project do
          yield
        end
      end

      def chart?
        Chart === @macro
      end
    end

    class CustomMacroWrapper
      def initialize(macro_class, macro_context, parameters, raw_content)
        if parameters && parameters['project']
          project_identifier = ValueMacro.project_identifier_from_parameters(parameters)
          macro_context[:project] = Project.find_by_identifier(project_identifier.to_s)
          raise Macro::ProcessingError.new("There is no project with identifier #{project_identifier.bold}.") unless macro_context[:project]
        end

        if parameters && parameters[PROJECT_GROUP]
          raise Macro::ProcessingError.new("This macro does not support project-group") unless (macro_class.respond_to?(:supports_project_group?) && macro_class.supports_project_group?)
          projects = parameters[PROJECT_GROUP].split(",").collect do |p|
            proj = Project.find_by_identifier(p.strip)
            raise Macro::ProcessingError.new("There is no project with identifier #{p.bold}.") unless proj
            proj
          end
        end

        raise Macro::ProcessingError.new("There is no project with identifier #{p.bold}.") if projects && projects.empty?

        loaded_projects = if projects && projects.any?
          projects.collect {|p| MingleModelLoaders::ProjectLoader.new(p, macro_context, self).project }
        else
          MingleModelLoaders::ProjectLoader.new(macro_context[:project], macro_context, self).project
        end

        Macro.with_error_handling do
          @macro = macro_class.new(parameters || {}, loaded_projects, Mingle::User.new(User.current))
        end

      end

      def execute
        return @alerts.uniq.join("\n") unless @alerts.blank?
        macro_result = Macro.with_error_handling { @macro.execute }.to_s
        @alerts.blank? ? macro_result : @alerts.uniq.join("\n")
      end

      def alert(message)
        (@alerts ||= []) << message
      end

      def can_be_cached?
        @macro.respond_to?('can_be_cached?') ? @macro.can_be_cached? : false
      end

      def chart?
        false
      end
    end
  end

  class EscapeMacrosInsideHrefsSubstitution < Substitution

    def pattern
      /href=["'].*\{\{.*\}\}.*["']/
    end

    def substitute(match)
      match.to_s.gsub("{", "%7B").gsub("}", "%7D")
    end

  end

  class ResolveMacrosInsideURLSubstitution < MacroSubstitution
    def pattern
      /(http[s]?\:\/\/.*)(#{MATCH})(.*)/
    end

    def substitute(match)
      "#{match.captures.first}#{MacroSubstitution.new(@context).apply(match.captures[1])}#{match.captures.last}"
    end
  end

  class ProtectMacrosFromSanitization < MacroSubstitution

    def substitute(match)
      macro_params = match.captures[1]
      match.to_s.gsub(macro_params, macro_params.escape_html)
    end

  end

  class UnprotectMacrosFromSanitization < ProtectMacrosFromSanitization

    def substitute(match)
      macro_params = match.captures[1]
      match.to_s.gsub(macro_params, CGI.unescapeHTML(macro_params))
    end

  end

  class WYSIWYGMacroSubstitution < MacroSubstitution
    def substitute(match)
      not_supported_message = %Q{
        Macros are not supported in Dependencies. <a href="#" class="remove-macro" title="Click to remove this macro">Remove.</a>
      }
      begin
         macro_content = content_provider.is_a?(Dependency) ? not_supported_message : super(match)

        if context[:dry_run]
          match
        else
          macro_content = macro_content.to_s.strip
          macro_content = "<span contenteditable=\"false\"></span>" if macro_content.blank?
          first_node = Nokogiri::HTML::DocumentFragment.parse(macro_content).children.first
          first_node = Nokogiri::HTML::DocumentFragment.parse("<span contenteditable=\"false\">#{macro_content}</span>").children.first if first_node.text?

          first_node['raw_text'] = URI.escape(match.to_s)

          css_classes = (first_node['class'] || "").split(" ").compact.reject(&:empty?)
          css_classes << "macro" unless css_classes.include? "macro"

          first_node['class'] = css_classes.join(" ")
          first_node.to_xhtml
        end
      rescue Macro::ProcessingError => e
        handle_macro_error(name, e, CGI::unescapeHTML(match.to_s))
      ensure
        context[:project] = context[:content_provider_project]  # reset back to host projectexp
      end
    end
  end

  class MacroFindSubstitution < Substitution
    include HelpDocHelper

    def pattern
      /\{\{\s*(\S*):?([^}]*)\}\}/
    end

    def substitute(match)
      content_provider.has_macros = true
    end
  end

  module NullMacroSubstitution
    class Pdf < MacroSubstitution
      def substitute(match); ''; end
    end

    class Dependencies < MacroSubstitution
      def substitute(match); '<span class="macro"> Macros are not supported in Dependencies </span>'; end
    end

    class Email < MacroSubstitution #We may be able to fold these two behaviours into one. Talk to the Product Manager.
      def substitute(match)
        name = match.captures[0]
        "<p>[<i>#{name} macro omitted</i>]<p>"
      rescue StandardError => e
        ''
      end
    end
  end

  class PdfLessThanWhenNotMarkupSubstitution < Substitution
    def pattern
      /(<)(\S)/
    end

    def substitute(match)
      "#{match[1]} #{match[2]}"
    end
  end

  class BodyMacroSubstitution < MacroSubstitution
    def pattern
      /
        (?-x: *)                      # optional leading space
        \{% \s* (\S*):? ([^%]*) %\}   # {% macro-name parameters %}
          ( .*? )                     # the macro body (non-greedy)
        (?-x: *)                      # optional leading space
        \{% \s* \1 \s* %\}            # {% macro-name %}
      /xm
    end

    def apply(content)
      content.gsub(pattern) do
        apply(substitute($~))
      end
    end

    def substitute(match)
      # check whether there was a quoting just before the match
      # in that case return $& thereby cancelling the substitution
      original = $&
      if $` =~ /\\$/
        original
      else
        name = match.captures[0]
        parameters = match.captures[1]
        body = match.captures[2]
        begin
          macro = instantiate_macro(context, name, Macro.parse_parameters(parameters), match[0])
          #append leading and tail \n to avoid redcloth rendering overwrite our html tags

          result = "\n" << macro.execute_with_body(body) << "\n"
          content_provider.can_be_cached = false unless macro.can_be_cached?
          result
        rescue ::TimeoutError => e
          #todo: refactor to avoid re-raising
          raise e #To keep exsiting functionality
        rescue StandardError => e
          handle_macro_error(name, $!, match.to_s)
        end
      end
    end
  end

  class NullBodyMacroSubstitution < BodyMacroSubstitution
    def substitute(match)
      begin
        name = match.captures[0]
        "<p>[<i>#{name} macro omitted</i>]<p>"
      rescue StandardError => e
        ''
      end
    end
  end

  # this fixes bug 4829
  class PrepareForSillyRedClothIssuesSubstitution < Substitution
    def pattern
      /\n[ \t]+\{/
    end

    def substitute(match)
      "\n{"
    end
  end

  class RemoveSillyPTagsSubstitution < Substitution
    def pattern
      /^<p>[\s]*((<|&lt;).*(>|&gt;))[\s]*<\/p>$/m
    end

    def substitute(match)
      match.captures[0]
    end
  end

  class AutoLinkSubstitution < Substitution
    def apply(content)
      context[:link] == :none ? content : context[:view_helper].original_auto_link(content, :all, :target => '_blank')
    end
  end

  class RemoveEscapeMarkupSubstitution < Substitution
    def apply(content)
      ActiveSupport::GsubSafety.unsafe_substitution_retaining_html_safety(content) do |unsafe_content|
        unsafe_content = content.gsub(/<[\/]?escape>/, "")
      end
    end
  end

  class AtUserSubstitution < Substitution

    def pattern
      MurmurUserMentions::SEARCH_USER_REGEX
    end

    def substitute(match)
      pre = match.captures[0]
      login = match.captures[1].to_s
      text = "@#{login}"
      content = MurmurUserMentions.detect(project, login) do |type, obj|
        case type
        when :user
          view_helper.content_tag('a', text, { :class => "at-highlight at-user", :title => obj.name, :rel => 'tipsy' })
        when :group
          view_helper.link_to(text, {
                                :controller => 'groups',
                                :action => 'show',
                                :project_id => project.identifier,
                                :id => obj.id },
                              { :class => "at-highlight at-group",
                                :title => "#{obj.user_memberships.count} member(s)", :rel => 'tipsy' }).html_safe
        when :team
          view_helper.link_to(text, {:controller => 'team',
                                :project_id => project.identifier,
                                :action => 'index'},
                              { :class => "at-highlight at-group",
                                :title => "#{obj.count} member(s)", :rel => 'tipsy' }).html_safe
        end
      end
      "#{pre}#{content || text}"
    end
  end

  class InlineLinkSubstitution < Substitution
    def apply(content)
      content.apply_redcloth(:lite_mode => true, :rules => [:inline_textile_link, :inline_markdown_link])
    end
  end

end
