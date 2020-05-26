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

# create benchmarker instance
RAILS_BENCHMARKER = RailsBenchmark.new

# If your session storage is ActiveRecordStore, and if you want
# sessions to be automatically deleted after benchmarking, use
# RAILS_BENCHMARKER = RailsBenchmarkWithActiveRecordStore.new

# WARNING: don't use RailsBenchmarkWithActiveRecordStore running on
# your production database!

# If your application runs from a url which is not your servers root,
# you should set relative_url_root on the benchmarker instance,
# especially if you use page caching.
# RAILS_BENCHMARKER.relative_url_root = '/blog'

# Create session data required to run the benchmark.
# Customize the code below if your benchmark needs session data.

# require 'user'
RAILS_BENCHMARKER.session_data = { :login=>"pwang" }
