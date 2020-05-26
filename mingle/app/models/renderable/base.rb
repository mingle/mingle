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

  TEXT_ENTITIES_TO_PRESERVE = {
    "!" => "#33",
    "{" => "#123",
    "}" => "#125"
  }

  module Base
    include ActionController::UrlWriter

    attr_accessor :editor_content_processing

    def self.included(base)
      base.class_eval do

        if base.respond_to?(:before_validation)
          before_validation :set_redcloth_value, :if => Proc.new { |renderable| renderable.new_record? && renderable.respond_to?(:redcloth) }
        end

        if base.respond_to?(:before_save)
          before_save :create_attachments, :if => Proc.new { |renderable| renderable.new_record? }
          before_save :replace_with_inline_mingle_markup, :if => Proc.new { |renderable| renderable.content.present? }
          before_save :detect_macro_content
        end

        def process_content?
          !redcloth && !!editor_content_processing
        end

        def create_attachments
          self.content = ImageAttachmentProcessor.new(self.content).process do |img_tag, attachment|
            attachings << self.attachings.new(:attachment => attachment) unless (attachings.detect {|a| a.attachment == attachment})
          end if process_content?
        end

        def replace_with_inline_mingle_markup
          self.content = InlineMarkupProcessor.new(self.content).process if process_content?
        end

        def self.default_url_options
          {}
        end
      end
    end

    # todo: can_be_cached should be renamed to static_content?
    # for it is only used by, and not part of logic of caching module anymore
    attr_writer :can_be_cached

    def can_be_cached?
      @can_be_cached
    end

    def export_macro_count
      macros = []
      Renderable::MacroSubstitution.new.macro_count(content || '').each do |k, v|
        macro_name = k.gsub('-', ' ').humanize
        pluralised_name = v > 1 && macro_name.last.downcase != 's' ? "#{macro_name}s" : macro_name
        macros << "#{v} #{pluralised_name}"
      end
      macros
    end

    def formatted_content(view_helper, context={}, substitutions = nil)
      substitutions ||= begin
        self.redcloth ? redcloth_view_substitutions : default_substitutions
      end
      formatted = format(view_helper, content, context, substitutions)
      log_rendering_errors(macro_execution_errors) unless macro_execution_errors.blank?
      formatted
    end

    def formatted_wysiwyg_content(view_helper)
      formatted_content(view_helper, {}, edit_substitutions)
    end

    def formatted_content_summary(view_helper, max_limit=200)
      desc = formatted_content(view_helper)
      return if desc.blank?
      doc = Nokogiri::HTML::DocumentFragment.parse(desc)
      doc.xpath("//img").to_xhtml + "<div>#{view_helper.truncate(doc.text, :length => max_limit)}</div>"
    end

    def formatted_content_as_snippet(view_helper)
      content = formatted_content(view_helper)
      if content =~ /\A<p>(.*)<\/p>\z/m
        $1
      else
        content
      end
    end

    def formatted_name_content(view_helper)
      format(view_helper, self.name, {}, [WYSIWYGInlineImageSubstitution, SanitizeSubstitution])
    end

    def formatted_email_content(view_helper)
      formatted_content_custom(view_helper, {}, email_substitutions)
    end

    def formatted_pdf_content(view_helper)
      formatted_content_custom(view_helper, {}, pdf_substitutions)
    end

    def formatted_content_preview(view_helper, _ = {})
      # add preview option for chart to generate preview image url
      formatted_content_custom(view_helper, :preview => true)
    end

    def formatted_content_editor(view_helper, _ = {})
      formatted_content_custom(view_helper, {:edit => true, :link => :none}, edit_substitutions)
    end

    def add_macro_execution_error(error)
      @macro_execution_errors = [] unless @macro_execution_errors
      @macro_execution_errors << error
    end

    def macro_execution_errors
      @macro_execution_errors || []
    end

    def reset_macro_execution_errors
      @macro_execution_errors = []
    end

    def detect_macro_content
      self.has_macros = false
      return unless content
      MacroFindSubstitution.new({:content_provider => self, :project => owner}).apply(content.dup)
    end

    def dry_run_macro_substitution
      substitution = MacroSubstitution.new({:dry_run => true, :content_provider => self, :project => owner})
      substitution.apply(content.to_s.dup)
      substitution
    end

    def owner
      project
    end

    def indexable_content
      return unless content
      content.gsub(/\b_(.+?)_\b/) do
        $1
      end
    end

    private

    def formatted_content_custom(view_helper, context = {}, substitutions=default_substitutions)
      format(view_helper, self.content, context, substitutions)
    end

    def log_rendering_errors(errors)
      if (Project.logger.level == Logger::DEBUG)
        root_cause = ""
        errors.each{|e| root_cause << "\n#{e}:\n#{e.backtrace.join("\n")}\n"}
        User.logger.error("\nError rendering #{self}. In most cases this is because of an error in MQL syntax or a misspelled property name or value in MQL.\n\nRoot cause of error: #{root_cause}")
      else
        User.logger.info("\nError rendering #{self}. In most cases this is because of an error in MQL syntax or a misspelled property name or value in MQL. If you suspect a serious problem, please run Mingle with log level set to DEBUG to see the full detail of this error.\n")
      end
    end

    def default_view_helper
      view = ActionView::Base.new([], {}, self)
      view.extend(ApplicationHelper)
      view
    end

    def remove_html_tags(content)
      content.remove_html_tags
    end

    def format(view_helper, content, context = {}, substitutions=default_substitutions)
      self.can_be_cached = true
      return '' unless content

      content = strip_trailing_spaces(content)
      context.merge!(:view_helper => view_helper, :content_provider => content_provider, :content_provider_project => owner, :project => owner)
      content = process(content, context, substitutions)

      if context[:conversion_to_html_in_progress]
        content.gsub!(Renderable::MacroSubstitution::MATCH) do |match|
          "{{#{URI.escape(match.to_s)}}}"
        end
      end

      result = ensure_html_renderable(content)

      if context[:conversion_to_html_in_progress]
        result = result.gsub(Renderable::MacroSubstitution::MATCH) do |match|
          URI.unescape(match.gsub(/\{|\}/, ''))
        end
      end

      result
    end

    def content_provider
      self
    end

    def strip_trailing_spaces(content)
      # this is to fix an issue in redcloth
      content.gsub(/ +\r?\n/, "\n")
    end

    def email_substitutions
      default_substitutions_with_replacements({
        MacroSubstitution => NullMacroSubstitution::Email
      })
    end

    def pdf_substitutions
      default_substitutions_with_replacements({
        WYSIWYGInlineImageSubstitution => NullInlineImageSubstitution,
        MacroSubstitution => NullMacroSubstitution::Pdf
      })
    end

    def default_substitutions
      [
        ProtectMacrosFromSanitization,
        EscapeMingleSpecificMarkupInsideCodeAndPreTagsSubstitution,
        SanitizeSubstitution,
        EscapeMacrosInsideHrefsSubstitution, #sanitize unescapes them :-/
        UnprotectMacrosFromSanitization,
        AttachmentLinkSubstitution,
        WYSIWYGInlineImageSubstitution,
        WikiLinkSubstitution,
        MacroSubstitution,
        CrossProjectCardSubstitution,
        CardSubstitution,
        AutoLinkSubstitution,
        RemoveEscapeMarkupSubstitution,
        DependencySubstitution
      ]
    end

    def edit_substitutions
      [
        WYSIWYGInlineImageSubstitution,
        ProtectMacrosFromSanitization,
        SanitizeSubstitution,
        UnprotectMacrosFromSanitization,
        EscapeMacrosInsideHrefsSubstitution,
        WYSIWYGMacroSubstitution,
        AutoLinkSubstitution,
        RemoveEscapeMarkupSubstitution,
        EnsureLastElementAppendableSubstituion
      ]
    end

    def dependency_substitutions
      default_substitutions_with_replacements({
        MacroSubstitution => NullMacroSubstitution::Dependencies
      })
    end
    public :dependency_substitutions

    def backwards_compatibility_substitutions
      [
        BodyMacroSubstitution,
        EscapeHTMLInsideCodeAndPreTagsSubstitution,
        PrepareForSillyRedClothIssuesSubstitution,
        ProtectWikiLinksDuringConversionSubstitution,
        ProtectMingleImageDuringConversionSubstitution,
        RedClothSubstitution,
        ResolveMacrosInsideURLSubstitution,
        AutoLinkSubstitution,
        RemoveSillyPTagsSubstitution,
        RemoveEscapeMarkupSubstitution
      ]
    end

    def redcloth_view_substitutions
      [
        EscapeHTMLInsideCodeAndPreTagsSubstitution,
        AttachmentLinkSubstitution,
        InlineImageSubstitution,
        WikiLinkSubstitution,
        PrepareForSillyRedClothIssuesSubstitution,
        BodyMacroSubstitution,
        RedClothSubstitution,
        SanitizeSubstitution,
        MacroSubstitution,
        CrossProjectCardSubstitution,
        CardSubstitution,
        AutoLinkSubstitution,
        RemoveSillyPTagsSubstitution,
        RemoveEscapeMarkupSubstitution
      ]
    end

    def process(content, context, substitutions=default_substitutions)
      content = content.dup
      if $trace
        puts "========== Initial content =========="
        puts content
        puts "====================================="
      end

      reset_macro_execution_errors

      substitutions.each do |s|
        context_copy = context.dup
        content = s.new(context_copy).apply(content)

        if $trace
          puts "===== Content after substitution: #{s.inspect} ====="
          puts content
          puts "===================================================="
        end
      end
      content = ActiveSupport::GsubSafety.unsafe_substitution_retaining_html_safety(content) do |unsafe_content|
        unsafe_content.gsub('\\[', '[').gsub('\\]', ']').gsub(/&#38;/, '%26')
      end
      content
    end

    def ensure_html_renderable(content)
      Nokogiri::HTML::DocumentFragment.parse(content, 'utf-8').to_xhtml
    end

    def default_substitutions_with_replacements(replacements)
      default_substitutions.tap do |result|
        replacements.each do |replaceable, replacement|
          result[result.index(replaceable)] = replacement
        end
        result.compact!
      end
    end

  end
end
