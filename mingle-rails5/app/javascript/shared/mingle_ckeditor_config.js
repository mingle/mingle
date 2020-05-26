/*
*  Copyright 2020 ThoughtWorks, Inc.
*
*  This program is free software: you can redistribute it and/or modify
*  it under the terms of the GNU Affero General Public License as
*  published by the Free Software Foundation, either version 3 of the
*  License, or (at your option) any later version.
*
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU Affero General Public License for more details.
*
*  You should have received a copy of the GNU Affero General Public License
*  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
*/
function cssForCkEditor() {
  let cssAssets = [];
  let styleSheets = document.querySelectorAll('link[rel="stylesheet"]');
  for (let styleSheet of styleSheets) {
    if (styleSheet.href.match("/.*css")) {
      cssAssets.push(styleSheet.href);
    }
  }
  return cssAssets;
}

export default function (properties = {}) {
  let defaultConfig = {
    bodyClass: "wiki editor",
    contentsCss: cssForCkEditor(),
    resize_enabled: false,
    toolbar: [
      {
        name: "basicstyles",
        items: ["Bold", "Italic", "Underline", "Strike", "TextColor"]
      },
      {name: "styles", items: ["Format"]},
      {name: "paragraph", items: ["NumberedList", "BulletedList"]},
      {
        name: "paragraph2",
        items: ["-", "Outdent", "Indent", "-", "Blockquote"]
      },
      {name: "links", items: ["Link", "Image", "Table"]},
      {name: "insert", groups: ["insert"]},
      {name: "document", items: ["Source"]},
      {name: "tools", items: ["Maximize"]}
    ],
    height: 310,
    basicEntities: false,
    width: "calc(100% - 12px)"
  };
  return Object.assign(defaultConfig, properties);
};