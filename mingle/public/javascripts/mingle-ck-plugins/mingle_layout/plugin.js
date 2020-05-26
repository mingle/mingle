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
(function ($) {
    var builder = $("<div/>");

    builder.empty().append(
        $("<div class='yui-g'/>").append(
            $("<div class='yui-u first'/>").append(
                $("<div class='dashboard-half-panel'/>").append(
                    "<h2>Left heading</h2><div class='dashboard-content'>Left content</div>"
                )
            )
        ).append(
            $("<div class='yui-u'/>").append(
                $("<div class='dashboard-half-panel'/>").append(
                    "<h2>Right heading</h2><div class='dashboard-content'>Right content</div>"
                )
            )
        )
    ).append("<div class='clear-both clear_float'/><br/>");

    var twoColumnLayout = builder.html();

    builder.empty().append(
        $("<div class='dashboard-panel'/>").append(
            "<h2>Heading</h2><div class='dashboard-content'>Content</div>"
        )
    ).append("<br/>");

    var oneColumnLayout = builder.html();
    builder.empty();


    CKEDITOR.plugins.add("mingle_layout", {
        init: function (editor) {

            var plugin = this;
            editor.addCommand("add_two_column_layout", {
                exec: function (editor) {
                    editor.insertHtml(twoColumnLayout);
                }
            });

            editor.ui.addButton("add_two_column_layout_button", {
                label: "Add two column layout",
                command: "add_two_column_layout",
                icon: plugin.path + "icons/two_column.png"
            });


            editor.addCommand("add_one_column_layout", {
                exec: function (editor) {
                    editor.insertHtml(oneColumnLayout);
                }
            });

            editor.ui.addButton("add_one_column_layout_button", {
                label: "Add one column layout",
                command: "add_one_column_layout",
                icon: plugin.path + "icons/one_column.png"
            });
        }
    });

})(jQuery);
