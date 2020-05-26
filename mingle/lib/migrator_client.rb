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

require 'active_support'
require 'httparty'

# Use script/console to trigger tenant creation for now
class MigratorClient
  include HTTParty


  attr_reader :migrator_url
  def initialize(migrator_url)
    @migrator_url = migrator_url
  end

  def create_site(name)
    params = {
      :name => name,
      :config => {:database_username => name},
      :setup_params => site_setup_params
    }
    self.class.post(endpoint, :body => params)
  end

  def sites
    response = get(endpoint)
    Hash.from_xml(response.body)['tenants'].map {|t| t['name'] }
  end

  def site_setup_params
    {
      :first_admin => {
        :login => "admin",
        :name => "Admin User",
        :email => "email@exmaple.com",
        :lost_password_ticket => "test123"
      },
      :license => valid_license
    }
  end

  def endpoint
    File.join(migrator_url, "api/v2/tenants.xml")
  end

  def valid_license
    {:key => <<-KEY, :licensed_to => "ThoughtWorks Inc."}
GzqxhYI1q4yqQ4HDSE0Ev0aQdJZaVQRIS3l3hyNMK8spVB+VW5zc6HmQ1uss
xPiTalCgemGGeSAFfc/FK7BBkkPRKCaLmm3OqRrBHqUtOAGuF6MGkaBTuQPF
JTJQl52+8kBFcf7QcrrThvef0cYv1o+esP3bpMd3aAFdUC1/HjPP9sC8qy1u
TEqYHdalEz7QhICjz20s/hpfML6mSgOSyLWHgGWo7wg6dbmnJaSvFcZFjTm9
M4zONE2l5Ifw0w5v3+RUMglr+yIaGLxBLEAreTNPcn7tMUcdjPBrERBmBcCp
o1Bsrz/UsRefS680YsaqjcbKr5IZNh7ugQC+Qon+8A==
KEY
  end

end
