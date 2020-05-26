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

class Attaching < ActiveRecord::Base
  belongs_to :attachment
  belongs_to :attachable, :polymorphic => true
  
  # todo: I want to add this validation but attachments test failed, will investigate onto it latter
  validates_presence_of :attachment
  # if add the following validation, the card object would be old version after it saved, need time to dig more deep.
  # validates_presence_of :attachable

  validates_associated :attachable
  validates_associated :attachment
end
