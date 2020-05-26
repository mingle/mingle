#!/usr/bin/env bash
# Copyright 2020 ThoughtWorks, Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
# Use this to copy asset files from rails 2 and the asset config file so you can run rails 5 without
# dual app setup. Symlinking logo file so the layout does not break
set -e

mkdir -p public/assets
mkdir -p public/images
pushd ../mingle

echo "Building Rails 2 assets"
bundle exec rake assets
cp -r public/assets/sprockets_app*.js ../mingle-rails5/public/assets
cp -r public/assets/sprockets_app*.css ../mingle-rails5/public/assets
cp -r public/assets/sprockets_planner*.css ../mingle-rails5/public/assets
cp -r public/assets/print-*.css ../mingle-rails5/public/assets
cp -r public/fonts ../mingle-rails5/public/fonts
echo "Copied Rails 2 js, css and fonts"

bundle exec rake shared_assets
cp shared_assets.yml ../mingle-rails5/config
echo "Copied Rails 5 asset config file"

popd
rm -f public/images/logo.png
echo "Symlinking logo image to public/images/logo.png"
ln -s ../../../mingle/public/images/logo.png public/images/logo.png

