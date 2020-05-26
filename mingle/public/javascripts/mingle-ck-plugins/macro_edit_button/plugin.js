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
(function($) {

  if (typeof(CKEDITOR.Mingle) === "undefined") { CKEDITOR.Mingle = {}; }

  CKEDITOR.Mingle.MacroEditButton = (function() {
    function findElements(selector) {
      return $("iframe.cke_wysiwyg_frame").contents().find(selector);
    }

    function button() {
      var editButton = findElements(".macro-edit-button");
      if (editButton.size() !== 1) {
        editButton.remove();
        var icon = "/images/macro_editor.png";
        editButton = $("<img/>").attr({
          "alt": "Edit this macro",
          "src": icon,
          "class": "macro-edit-button",
          "contenteditable": "false"
        }).css({
          position: "absolute"
        });

        // need this to remove resize handles on the macro edit button on IE9
        editButton[0].oncontrolselect = function(){return false;};
        var ck = new CKEDITOR.dom.element(editButton[0]);
        ck.unselectable();

        editButton.click(function click(e) {
          e.stopPropagation();
          e.preventDefault();

          CKEDITOR.Mingle.MacroEditor.currentMacroElement = CKEDITOR.Mingle.MacroEditButton.activeMacro;
          var macro  = decodeURIComponent($j(CKEDITOR.Mingle.MacroEditButton.activeMacro).attr('raw_text'));
          CKEDITOR.Mingle.MacroEditor.macroData = {
            content: macro,
            type: macro.match(/{{\s*(?:([^\s:]*)?|(?:[^\s:]*)):?([^}]*)}}/m)[1]
          };

          if (CKEDITOR.Mingle.MacroEditor.easyChartsMacroEditorEnabledFor(CKEDITOR.Mingle.MacroEditButton.editor, CKEDITOR.Mingle.MacroEditor.macroData.type))
            CKEDITOR.Mingle.MacroEditButton.editor.execCommand('easyChartsMacroEditorDialog');
          else
            CKEDITOR.Mingle.MacroEditButton.editor.execCommand("macroEditorDialog");
          CKEDITOR.Mingle.MacroEditButton.hideButton();
        });

        findElements("body").append(editButton.hide());
      }
      return editButton;
    }

    function detectElement(element) {
      var macro = $(element).closest(".macro");
      if (macro.size() > 0) {
        return macro[0];
      }

      if($(element).hasClass("macro-edit-button")) {
        return element;
      }

      return null;
    }


    return {
      // activeMacro is subtly different from currentMacroElement, but needs to
      // be distinct. it is set on hover, and represents a candidate macro element
      // that *may* be promoted to currentMacroElement when on click.
      activeMacro: null,

      hideButton: function() {
        findElements(".macro").css({outline: "none"});
        // to make tests more resilient
        var delay = $.fx.off ? 0 : 1000;

        if (button()[0].state !== "hide") {
          button().stop(true, true).delay(delay).fadeOut();
        }
        button()[0].state = "hide";
      },
      showButton: function(element) {
        if (button()[0].state !== "show") {
          button().stop(true, true).fadeIn();
        }
        button()[0].state = "show";

        if (!$(element).hasClass("macro-edit-button")) {
          //should stop other fadeouts before setting activeMacro, as fadeout might unset activeMacro.
          $(element).css({outline: "1px dotted #03f"});
          CKEDITOR.Mingle.MacroEditButton.activeMacro = element;
          CKEDITOR.Mingle.MacroEditButton.placeButton();
        }
      },

      'button': button,

      placeButton: function() {
        if (!CKEDITOR.Mingle.MacroEditButton.activeMacro) {
          return;
        }

        var iframe = $("iframe.cke_wysiwyg_frame");
        if (iframe[0]) {
          var buttonOffset = CKEDITOR.Mingle.MacroEditButton.getButtonOffset($(window), iframe, $(iframe[0].contentWindow));
          button().css(buttonOffset);
        }
      },

      getButtonOffset: function(currentWindow, iframe, innerWindow) {
        var activeMacro = CKEDITOR.Mingle.MacroEditButton.activeMacro;
        var framePosition = iframe.offset();
        var macroWidth = $(activeMacro).outerWidth();
        var macroPos = new CKEDITOR.dom.element(activeMacro).getDocumentPosition();

        var macroVertical = Math.round(macroPos.y);
        var macroHorizontal = Math.round(macroPos.x + macroWidth + 2);

        var winScrollTop = currentWindow.scrollTop();
        var topScrollOffset = (winScrollTop > framePosition.top) ? winScrollTop - framePosition.top : 0;
        var maxTop = Math.round(innerWindow.scrollTop() + topScrollOffset);

        var winScrollLeft = currentWindow.scrollLeft();
        var leftScrollOffset = winScrollLeft - framePosition.left;
        var width = Math.min(currentWindow.width() + leftScrollOffset, innerWindow.width());
        var maxLeft = Math.round(width - button().outerWidth()) + innerWindow.scrollLeft();

        return {
          top: Math.max(macroVertical, maxTop) + "px",
          left: Math.min(maxLeft, macroHorizontal) + "px"
        };
      },

      setupScrollHandlers: function() {
        $(window).unbind("scroll", CKEDITOR.Mingle.MacroEditButton.placeButton);
        $(window).scroll(CKEDITOR.Mingle.MacroEditButton.placeButton);

        var iframeWindow = $($("iframe.cke_wysiwyg_frame")[0].contentWindow);
        iframeWindow.unbind("scroll", CKEDITOR.Mingle.MacroEditButton.placeButton);
        iframeWindow.scroll(CKEDITOR.Mingle.MacroEditButton.placeButton);

        findElements("body").unbind("mousemove").mousemove(function(e) {
          var element = detectElement(e.target);
          if (element) {
            CKEDITOR.Mingle.MacroEditButton.showButton(element);
          } else {
            CKEDITOR.Mingle.MacroEditButton.hideButton();
          }
        });
      },

      init: function(editor) {
        CKEDITOR.Mingle.MacroEditButton.editor = editor;
        CKEDITOR.Mingle.MacroEditButton.setupScrollHandlers();
        findElements(".macro-edit-button").remove();
        button();
      },

      teardown: function() {
        findElements(".macro").unbind("mouseleave mouseenter");
        findElements(".macro-edit-button").remove();
      }
    };
  })();

  CKEDITOR.plugins.add("macro_edit_button", {
    init: function(editor) {
      editor.on("contentDom", function(e) {
        var nodes = $(editor.document.$.body).children().length;
        var macroNodes = $(editor.document.$.body).children(".macro").length;
        var isEntirelyMacros =  nodes > 0 && nodes === macroNodes;

        if (isEntirelyMacros) {
          $(editor.document.$.body).append("<p>&nbsp;</p>");
          editor.fire("updateSnapshot");
        }
      });

      if ("dependency[description]" === $(editor.element.$).attr("name")) {
        editor.on("contentDom", function(e) {
          editor.fire("saveSnapshot");

          $(editor.document.$.body).on("click", ".macro a.remove-macro", function(e) {
            $(this).closest(".macro").remove();
            editor.fire("saveSnapshot"); // allow users to undo
          });
        });

        return;
      }

      editor.on("contentDom", function(e) {
        CKEDITOR.Mingle.MacroEditButton.init(editor);
        editor.fire('updateSnapshot');
      });

      var commands = ["undo", "redo"];
      editor.on('afterCommandExec', function (e) {
        if ($.inArray(e.data.name, commands) !== -1) {
          CKEDITOR.Mingle.MacroEditButton.init(editor);
        }
      });

      editor.on('beforeCommandExec', function (e) {
        if ($.inArray(e.data.name, commands) !== -1) {
          CKEDITOR.Mingle.MacroEditButton.teardown();
          editor.fire('updateSnapshot');
        }
      });

      editor.on("getData", function(e) {
        var value = CKEDITOR.tools.callFunction(CKEDITOR.mingle.applyCKFiltersToHtml, editor, e.data.dataValue);
        var content = $("<div/>").html(value);

        var wrappingParagraph = content.find(".macro-edit-button").closest("p");
        content.find(".macro-edit-button").siblings('br').remove();
        content.find(".macro-edit-button").remove();

        if (wrappingParagraph.is(":empty")) {
          wrappingParagraph.remove();
        }

        e.data.dataValue = $.trim(content.html());
      });
    }
  });

})(jQuery);
