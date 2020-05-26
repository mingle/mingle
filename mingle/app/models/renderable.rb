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

require 'renderable/red_cloth_patch'

module Renderable
  extend Renderable::Caching::SingletonMethods

  def self.included(base)
    Renderable::Substitution # trigger const missing
    base.send(:include, Renderable::Base)
    base.send(:include, Renderable::Caching)
    base.send(:include, Renderable::CrossProject)
    base.send(:include, Renderable::Timeout)
    base.send(:include, Renderable::RenderedDescriptionAnchor)
  end

  def convert_redcloth_to_html!
    self.content = self.formatted_content(default_view_helper, {:conversion_to_html_in_progress => true},backwards_compatibility_substitutions)
    self.redcloth = false
    if self.respond_to?(:convert_tab_character_to_space_in_description)
      self.convert_tab_character_to_space_in_description
    end
    self.send(:update_without_callbacks)
    if self.respond_to?(:after_save_with_oracle_lob)
      self.send(:after_save_with_oracle_lob)
    end
  end

  def set_redcloth_value
    self.redcloth = false
    true
  end

end
