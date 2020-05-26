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
CkeditorConfig = {
    init: function (CKEDITOR, $) {
        var basePath = CKEDITOR.basePath;
        basePath = basePath.substr(0, basePath.indexOf("/ckeditor-"));
        CKEDITOR.mingleRevision = $(document.documentElement).data("rev");

        var minglePlugins = [
            "image_upload",
            "mingle_layout",
            "macro_editor",
            "macro_builder",
            "macro_edit_button",
            "drag_drop_files",
            "autosave"
        ];

        this._loadPlugins(minglePlugins, basePath + "/mingle-ck-plugins/");

        CKEDITOR.editorConfig = function (config) {
            var css = $("link[rel=\"stylesheet\"]").map(function (i, l) {
                return l.href;
            }).filter(function (i, l) {
                return /(planner|app)[-\w]*.css/.test(l);
            }).get();

            if (css.length !== 0) {
                config.contentsCss = css;
            }

            config.toolbar = 'base';
            config.toolbar_base = [
                ['Bold', 'Italic', 'Underline', 'Strike', 'TextColor'],
                ['Format'],
                ['NumberedList', 'BulletedList'],
                ['Outdent', 'Indent', '-', 'Blockquote'],
                ['Link', 'Table']
            ];

            var sourceAndMax = [['Source'], ['Maximize']];

            var mingleMacros = [
                ['macro_editor'],
                ['project_macro_button', 'project-variable_macro_button'],
                ['add_one_column_layout_button', 'add_two_column_layout_button'],
                ['average_macro_button', 'value_macro_button', 'table-query_macro_button', 'table-view_macro_button', 'pivot-table_macro_button'],
                ['stacked-bar-chart_macro_button', 'data-series-chart_macro_button', 'daily-history-chart_macro_button', 'ratio-bar-chart_macro_button', 'pie-chart_macro_button','cumulative-flow-graph_macro_button']
            ];

            config.toolbar_with_image_upload = config.toolbar_base.slice(0);
            config.toolbar_with_image_upload[4] = ['Link', 'image_upload', 'Table'];
            config.toolbar_basic_editor_with_image_upload = config.toolbar_with_image_upload.concat(sourceAndMax);

            config.toolbar_with_image_upload = config.toolbar_with_image_upload.concat(mingleMacros).concat(sourceAndMax);

            config.toolbar_base = config.toolbar_base.concat(mingleMacros).concat(sourceAndMax);

            config.extraPlugins = minglePlugins.join(",");
            config.skin = 'moono';
            config.bodyId = 'renderable-contents';
            config.bodyClass = 'wiki editor';
            config.format_tags = 'p;pre;h3;h2;h1';
            config.tabSpaces = 4;
            config.entities = false;
            config.disableNativeSpellChecker = false;
            config.startupFocus = MingleUI.focusOnCkeditor;
            config.image_previewText = " ";
            config.resize_enabled = true;
            config.autoParagraph = false;
            config.language = 'en';

            // This changed in 4.1:
            // Default (automatic) mode will remove unknown content tags, including macros
            // http://docs.ckeditor.com/#!/guide/dev_advanced_content_filter
            CKEDITOR.config.allowedContent = {
                $0: {
                    elements: CKEDITOR.dtd,
                    attributes: true,
                    styles: true,
                    classes: true
                }
            };
            config.disallowedContent = 'script;*[on*]';

            config.keystrokes = [
                [CKEDITOR.CTRL + 75 /*K*/, 'link'],
                [CKEDITOR.CTRL + 76 /*L*/, null], // Ensure that Ctrl+L defaults to browser's default behaviour, which is to highlight address bar
                [CKEDITOR.CTRL + CKEDITOR.SHIFT + 55 /*7*/, 'numberedlist'],
                [CKEDITOR.CTRL + CKEDITOR.SHIFT + 56 /*8*/, 'bulletedlist']
            ];
        };

        CKEDITOR.mingle = {};

        // hijack link dialog to handle attachment links properly
        CKEDITOR.on("dialogDefinition", function (ev) {
            if (ev.data.name == "link") {
                var definition = ev.data.definition;

                // disable the "ok" button - it doesn't make sense when uploading
                // because the upload button injects the link and closes the dialog
                definition.dialog.on("selectPage", function (e) {
                    if (e.data.page === "upload") {
                        this.disableButton("ok");
                    } else {
                        this.enableButton("ok");
                    }
                });

                var upload = definition.getContents("upload");
                // add a hidden field to receive the response from server and
                // inject the element with the special inline attachment link markup
                upload.add({
                    id: "filename",
                    type: "text",
                    inputStyle: "display: none;",
                    onChange: function (ev) {
                        var editor = this.getDialog().getParentEditor();
                        var filename = $.parseJSON(ev.data.value).filename;
                        this.attachmentLink = editor.document.createElement("p");
                        this.attachmentLink.setText("[[" + filename + "]]");
                        editor.insertElement(this.attachmentLink);
                        this.getDialog().hide();
                    }
                }, "uploadButton");

                // wire up the upload button to use our new hidden field + handler
                var button = upload.get("uploadButton");
                button.label = "Attach file and insert link";
                button.filebrowser.target = "upload:filename";
            }
        });

        //todo: move this to a plugin
        CKEDITOR.footbar_help = function (editor) {
            var bottom = editor.ui.space('bottom');
            bottom.appendHtml("<span class='footbar-help'></span>");
            var h = bottom.findOne('.footbar-help');
            var k = CKEDITOR.env.mac ? 'CMD' : 'CTRL';
            var hint = null;
            editor.on('selectionChange', function (ev) {
                if (hint) {
                    return;
                }

                var hasTable = false;
                $.each(editor.elementPath().elements, function (i, ckel) {
                    hasTable = hasTable || "table" === ckel.getName();
                    return !hasTable;
                });

                if (hasTable) {
                    h.setText(k + ' + right click to show editor specific context menu.');
                    hint = setTimeout(function () {
                        h.setText('');
                        hint = null;
                    }, 7000);
                }
            });
        };

        CKEDITOR.on('instanceReady', function (e) {
            // Override lang strings
            CKEDITOR.lang['en'].format.tag_pre = "Code Block";
            CKEDITOR.lang['en'].list.bulletedlist = "Bulleted List (Ctrl + Shift + 8)";
            CKEDITOR.lang['en'].list.numberedlist = "Numbered List (Ctrl + Shift + 7)";
            CKEDITOR.lang['en'].link.toolbar = "Link (Ctrl + K)";

            // Utility function to call in plugins that applies ckeditor's filters to an html string.
            // This method is important because it filters out content that can be used for
            // an XSS attack (even if you don't save the card).
            //   example:
            //      var str = "<img src='/' onerror=\"alert('boo');\" />"
            //      var results = CKEDITOR.tools.callFunction(applyCKFiltersToHtml, editor, str);
            //      results -> "<img src='/' />"
            CKEDITOR.mingle.applyCKFiltersToHtml = CKEDITOR.tools.addFunction(function (editor, htmlStr) {
                var writer = new CKEDITOR.htmlWriter();
                var data = CKEDITOR.htmlParser.fragment.fromHtml(htmlStr);
                editor.filter.applyTo(data);
                data.writeHtml(writer);
                return writer.getHtml();
            });

            var editor = e.editor;

            editor.on('paste', function (e) {
                var incomingText = e.data.dataValue;
                e.data.dataValue = incomingText.replace(/(<[^>]+)(class="macro")/g, function (entireMatch, $1, $2) {
                    return $1;
                });
            });

            editor.on("key", function (e) {
                // CKEDITOR magically maps command -> ctrl on mac
                var hotkey = CKEDITOR.CTRL + jQuery.ui.keyCode.ENTER;
                if (e.data.keyCode === hotkey) {
                    e.data.domEvent.preventDefault();
                    MingleUI.cmd.saveEditor();
                }
            });

            editor.on('destroy', function (e) {
                CKEDITOR.tools.removeFunction(CKEDITOR.mingle.applyCKFiltersToHtml);
            });

            CKEDITOR.footbar_help(editor);
            CKEDITOR.mingle.ready = true;
        });
    },

    _loadPlugins: function(plugins, pluginsPath){
        for (var i = 0, len = plugins.length, plug; i < len; i++) {
            plug = plugins[i];
            CKEDITOR.plugins.addExternal(plug, pluginsPath + plug + "/plugin.js?rev=" + CKEDITOR.mingleRevision, "");
        }
    }
};

