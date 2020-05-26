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

module MacroSizeValidationHelper

  UNCOUNTABLE_MACROS = ["project", "project-variable", "value", "google-maps", "google-calendar", "average"]

  def too_many_macros?(renderable)
    warning_disabled = session[:too_many_macros_warning_visible] && session[:too_many_macros_warning_visible].include?(request.request_uri)
    if renderable && (User.current.anonymous? || !warning_disabled)
      macros = renderable.dry_run_macro_substitution.rendered_macros - UNCOUNTABLE_MACROS
      return macros.size > 10
    end
  end

end
