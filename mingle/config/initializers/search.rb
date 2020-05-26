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

if MingleConfiguration.installer? || Rails.env.test?
  ElasticSearch.create_index_with_mappings if MingleConfiguration.search_namespace?
else
  raise 'ES cluster not configured for saas' if MingleConfiguration.aws_es_cluster.blank?
  Rails.logger.info("Initialising AWS Elastic search client")
  ElasticSearch.init_aws_es(MingleConfiguration.aws_es_cluster, MingleConfiguration.aws_es_region)
end
