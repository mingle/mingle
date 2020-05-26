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

    function track(action) {
        mixpanelTrack("drag+drop", {action: action});
    }
    /*
     * Main handlers/entry points
     */

    function dropHandler(e, editor) {
        var dt = e.dataTransfer;

        var file = dt.files[0], placeholder;

        function positionElementAtMouse(element) {
            // dropped file below the body element, attach to the bottom of content
            if (e.target === editor.document.$.documentElement) {
                cke(element).appendTo(editor.document.getBody());
            } else {
                var x = e.x || e.pageX, y = e.y || e.pageY;
                var range = rangeAt(x, y, editor.document.$);

                insertElementAtCaret(element, range, editor);
            }
        }

        $(editor.container.$).find(".cke_contents").removeClass("drop-target");

        if (file) {
            if (file.size > 0) {
                placeholder = makePlaceholder(file, editor.document.$);
                positionElementAtMouse(placeholder);

                file.editor = editor;
                editor.dz.addFile(file);
            } else {
                displayError("This file is empty.", editor);
            }
            e.preventDefault();
            track("drop file");
        } else if (hasType(dt, "text/uri-list") && hasType(dt, "text/html")) { // possible image drag from another browser window
            var node = $(dt.getData("text/html")).not("meta").find("img:first").addBack("img:first").not(".mingle-image");
            if (node.length) {
                var src = node.attr("src");
                var basename = MingleUI.attachable.randomId("clip", 2);
                var fileStub = {name: basename, generatedName: basename, editor: editor};

                placeholder = makePlaceholder(fileStub, editor.document.$);
                positionElementAtMouse(placeholder);

                uploadFromSrc(src, fileStub);
                track("drop markup");
            }
            e.preventDefault();
        }
    }

    function imageDataPasteHandler(e, editor) { // handle pasting raw data from clipboard, e.g. MacOS, MS Paint, etc
        var items = e.clipboardData ? e.clipboardData.items : e.view.clipboardData.files;
        if (items && items.length && items[0].type.match(/image.*/)) {
            var file = items[0].getAsFile ? items[0].getAsFile() : items[0];
            file.editor = editor;

            // file.name is "" when pasting, and file.name is a readonly property
            // as defined in the standard. while Chrome relaxes this restriction,
            // IE honors it. since we can't change it, inject it into another property
            // and check for it when needed.
            file.name = file.generatedName = MingleUI.attachable.randomId("clip", 2) + "." + file.type.split("/").pop();

            var placeholder = makePlaceholder(file, editor.document.$);
            var range = editor.window.$.getSelection().getRangeAt(0);

            insertElementAtCaret(placeholder, range, editor);

            editor.dz.addFile(file);
            e.preventDefault();
            e.stopPropagation();
            track("paste image data");
        }
    }

    function imageMarkupPasteHandler(ckEvent) { // pasting images may come in as HTML depending on OS
        if (ckEvent.data.type === "html" && ckEvent.data.dataValue.match(/<img /i) && $(ckEvent.data.dataValue).is("img")) {
            var src = $(ckEvent.data.dataValue).attr("src");
            var editor = ckEvent.editor;

            var basename = MingleUI.attachable.randomId("clip", 2);
            var fileStub = {name: basename, generatedName: basename, editor: editor};

            var range = editor.window.$.getSelection().getRangeAt(0);
            var placeholder = makePlaceholder(fileStub, editor.document.$);
            insertElementAtCaret(placeholder, range, editor);

            uploadFromSrc(src, fileStub);
            ckEvent.cancel();
            editor.focus();
            track("paste markup");
        }
    }

    function uploadFromSrc(src, stub) {
        var editor = stub.editor;
        var textarea = $(editor.element.$);
        var basename = stub.generatedName;

        function askServerToRetrieveImage(external, fileStub) {
            var url = textarea.data("attachments-upload-external-url");
            $.ajax({
                url: url,
                type: "POST",
                dataType: "json",
                data: {
                    external: external,
                    basename: fileStub.generatedName
                }
            }).done(function(data, status, xhr) {
                fileStub.type = data.contentType;
                success(fileStub, data);

                var f = {filename: data.filename, url: data.path, id: data.path.split("/").pop()};
                $.extend(fileStub, {size: "", stored: f, status: Dropzone.SUCCESS});
                editor.dz.files.push(fileStub);
                editor.dz.emit("addedfile", fileStub);

            }).fail(function(xhr, status, err) {
                locatePlaceholder(fileStub).remove();
                displayError("Some images cannot be created. Try saving it, then dragging the file instead.", fileStub.editor, 5000);
            });
        }

        // it happens, though rarely
        if (src.match(/^data\:/)) {
            var file = blobFromDataUrl(src);
            file.editor = editor;
            file.name = file.generatedName = basename + "." + file.type.split("/").pop();
            file.uid = stub.uid;

            editor.dz.addFile(file);
        } else {
            askServerToRetrieveImage(src, stub);
        }
    }

    function success(file, data, e) {
        var dropzone = this;
        var editor = file.editor;
        var placeholder = locatePlaceholder(file);

        if (("string" === typeof data) && file.xhr && file.xhr.responseXML) {
            if (placeholder && placeholder.length) {
                placeholder.html(placeholder.html().replace(/Uploading/g, "Processing"));
                placeholder.find(".progress-bar").css("background-color", "rgb(10, 91, 175)");
            }

            // at this point, we only have S3 response, so exit early after updating the placeholder message
            return;
        }

        if (editor) {
            var el = makeInlineElement(file.type, data);

            (placeholder && placeholder.length) ? placeholder.replaceWith(el) : cke(el).appendTo(editor.document.getBody());
            editor.fire("change");
        }

        teardown(file);
    }

    function teardown(file) {
        if (file.editor) {
            removePlaceholders(file.editor.document.$.body, locatePlaceholder(file));
        }
    }

    function handleDropzoneError(file, errorMessage, xhr) {
        teardown(file);
        if (file.editor) {
            var editor = file.editor;
            displayError(errorMessage, editor);
        }
    }

    /*
     * Element insertion and range manipulation
     */

    function insertElementAtCaret(element, range, editor) {
        var rangeParent = $(range.startContainer || range.parentElement());

        // in IE, CKEditor uses the pastebin element, so we lose the handle on the range parent.
        // instead, look for the invisible bookmarks left by CKEditor to determine if we should
        // allow paste at that location.
        if (rangeParent.attr("id") === "cke_pastebin") {
            rangeParent = $(editor.document.getBody().$).find("[data-cke-bookmark]");
        }

        var deniedSelectors = ".macro,[contenteditable='false']";
        var prohibited = rangeParent.closest(deniedSelectors).addBack(deniedSelectors);

        if (!prohibited.length) {
            insertAtRange(element, range);
            range.collapse(false);
        } else {
            $(element).insertAfter($(prohibited.get(0)));
            moveCKCaretToEndOf(element, editor);
        }

    }

    function insertAtRange(element, range) {
        if ("function" === typeof range.insertNode) {
            range.insertNode(element);
        } else {
            var rangeParent = range.startContainer || range.parentElement();
            var tmpId = MingleUI.attachable.randomId("t", 2);
            range.pasteHTML('<i id="' + tmpId + '">&nbsp;</i>');
            var tmp = rangeParent.ownerDocument.getElementById(tmpId);
            tmp.parentNode.replaceChild(element, tmp);
        }
    }

    function rangeAt(x, y, doc) {
        var range;
        doc = doc || document;

        // IE
        if (doc.body.createTextRange) {
            range = doc.body.createTextRange();
            try {
                range.moveToPoint(x, y);
            } catch(e) {
                d("IE sometimes fails on TextRange.moveToPoint(): " + e.message);
            }
            doc.defaultView.getSelection().removeAllRanges();
            range.collapse(false);
            range.select();
        } else {
            // WebKit
            if (doc.caretRangeFromPoint) {
                range = doc.caretRangeFromPoint(x, y);
            } else {
                // W3C
                var pos = doc.caretPositionFromPoint(x, y);
                range = doc.createRange();
                range.setStart(pos.offsetNode, pos.offset);
                range.collapse();
            }
            var selection = doc.defaultView.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);
        }

        return range;
    }

    function moveCKCaretToEndOf(el, editor) {
        var range = editor.createRange(), c = cke(el), sel = editor.getSelection();
        range.moveToClosestEditablePosition(c, true);
        sel.removeAllRanges();
        sel.selectRanges([range]);
    }

    /*
     * Element utility and manipulation (e.g. placeholders)
     */

    function makeInlineElement(mimeType, data) {
        if (mimeType.match(/image.*/)) {
            return $("<img/>").attr({
                "class": "mingle-image",
                "src": data.path,
                "alt": data.filename
            }).get(0);
        } else {
            return $("<span/>").text("[[" + data.filename + "]]").get(0);
        }
    }

    function makePlaceholder(file, doc) {
        var message = "Uploading " + (file.generatedName || file.name) + "&hellip;";
        var uid = file.uid ? file.uid : (file.uid = MingleUI.attachable.randomId("file", 4));
        var markup = '<span class="with-progress-bar" rel="upload-placeholder" contenteditable="false" data-file-uid="' + uid + '">' +
                         '<span class="progress">' +
                             '<span class="progress-bar" role="progressbar">' +
                                 '<span class="sr-only">' + message +'</span>' +
                             '</span>' +
                         '</span>' +
                         '<span class="upload-placeholder">' + message +' <i class="fa fa-close">&nbsp;</i></span>' +
                     '</span>';
        return $(markup, doc).get(0);
    }

    function removePlaceholders(container, placeholder) {
        if (!placeholder) {
            // if you don't specify a placeholder, remove all placeholders
            var criterion = ".with-progress-bar";
            placeholder = $(container).find(criterion);
        }

        if (!placeholder.length) {
            return; // nothing to remove
        }

        var wrappingParagraph = placeholder.closest("p");

        placeholder.remove();
        wrappingParagraph.filter(":empty").remove();
    }

    function locatePlaceholder(file) {
        var el;
        if (file.editor) {
            el = $(file.editor.document.$.body).find("[data-file-uid=\"" + file.uid +"\"]");
            el.length !== 1 && d("found " + el.length + " placeholders for file: " + file.uid);
        }
        return el;
    }

    /*
     * User-facing error handling
     */

    function displayError(errorMessage, editor, timeout) {
        if ("undefined" === typeof timeout) {
            timeout = 1250;
        }
        var container = $(editor.element.$).closest("div");
        var element = getErrorPanel(container);
        element.find(".message").text(errorMessage);
        element.fadeIn("fast").delay(timeout).fadeOut("fast", function(e) {
            $(this).hide().find(".message").html("");
        });
    }

    function getErrorPanel(container) {
        container.css("position", "relative");

        if (container.find(".upload-error").length > 0) {
            return container.find(".upload-error").hide().fadeOut("fast");
        }

        var markup = '<div class="error-entry">' +
                         '<span class="fa-stack fa-lg">' +
                             '<i class="fa fa-upload fa-stack-1x"></i>' +
                             '<i class="fa fa-ban fa-stack-2x text-danger"></i>' +
                         '</span>' +
                         '<span class="message"></span>' +
                     '</div>';

        var panel = $("<div class=\"upload-error\"/>").hide().fadeOut("fast").html(markup).appendTo(container);

        panel.on("click", function(e) {
            e.preventDefault();
            $(this).stop(true, true).fadeOut("fast", function(e) {
                $(this).hide();
            });
        }).on("drop dragstart dragenter dragover", function(e) {
            e.preventDefault();
        });

        return panel;
    }

    /*
     * misc handlers for things you shouldn't have to think about
     */

    function scrub(ckEvent) {
        var editor = this;
        var value = CKEDITOR.tools.callFunction(CKEDITOR.mingle.applyCKFiltersToHtml, editor, ckEvent.data.dataValue);
        var content = $("<div/>").html(value);
        removePlaceholders(content);
        ckEvent.data.dataValue = $.trim(content.html());
    }

    function allow(ckEvent) {
        var e = ckEvent.data.$;
        var editor = this;
        var x, y, el;
        e.dataTransfer.dropEffect = "copy";

        if (e.type === "dragenter" && e.target === editor.document.$.body) {
            $(editor.container.$).find(".cke_contents").addClass("drop-target");
        }

        if (e.type === "dragleave") {
            x = e.x || e.pageX, y = e.y || e.pageY;
            el = editor.document.$.elementFromPoint(x, y);

            if (!el || !(el === editor.document.$.body || $.contains(editor.document.$, el))) {
                $(editor.container.$).find(".cke_contents").removeClass("drop-target");
            }
        }

        if (document.body.createTextRange) {
            e.preventDefault();
        }
    }

    /*
     * Utility methods
     */

    function hasType(dt, type) {
        return dt.types.indexOf ? dt.types.indexOf(type) !== -1 : dt.types.contains(type);
    }

    function cke(el) {
        return new CKEDITOR.dom.element(el);
    }

    function ckShim(fn, editor) {
        return function(ckEvent) {
            var e = ckEvent.data.$;
            fn(e, editor);
        };
    }

    function blobFromDataUrl(url) {
        var BASE64_MARKER = ';base64,';
        var parts, contentType, raw;
        if (url.indexOf(BASE64_MARKER) === -1) {
            parts = url.split(',');
            contentType = parts[0].split(':')[1];
            raw = decodeURIComponent(parts[1]);
            return new Blob([raw], {type: contentType});
        }
        parts = url.split(BASE64_MARKER);
        contentType = parts[0].split(':')[1];
        raw = window.atob(parts[1]);
        var rawLength = raw.length;
        var uInt8Array = new Uint8Array(rawLength);
        for (var i = 0; i < rawLength; ++i) {
            uInt8Array[i] = raw.charCodeAt(i);
        }
        return new Blob([uInt8Array], {type: contentType});
    }

    function d(message) {
        (console && "function" === typeof console.log) && console.log(message);
    }

    /*
     * Final wire-up
     */

    CKEDITOR.plugins.add("drag_drop_files", {
      onLoad: function() {
          CKEDITOR.addCss(
              "html, body {" +
                  "margin: 0;" +
              "}"
          );

      },
      init: function(editor) {
        var textarea = $(editor.element.$);
        if (!textarea.data("attachments-upload-url")) {
            return;
        }

        // garbage collect any Dropzone instance that is not:
        //   1. the current full view edit instance (up to 1 instance)
        //   2. is not currently displayed in a lightbox (up to 2 instances - add new card, and exising card preview)
        for (var i = Dropzone.instances.length, dz, attid, isDisplayed; i > 0; i--) {
            dz = Dropzone.instances[i - 1];
            attid = $(dz.element).data("attachable-id");
            isDisplayed = $("[data-attachable-id='" + attid + "']").length;

            if (dz.element && !$.contains(document.body, dz.element) && !isDisplayed) {
                dz.destroy();
            }
        }

        var id = textarea.data("attachable-id");


        // Try to locate the dropzone element; generally, it's a good idea to search within a known (and guaranteed) common parent
        // instead of relying on some type of identifier (e.g. html ID, database ID, card number, etc.). Identifiers may well serve
        // as an additional layer of validation, but shouldn't be the means to find the associated dropzone, such as in the case of
        // multiple instances of a UI element representing an instance of some Rails model.
        //
        // Essentially:
        //
        // It is no longer reliable to select dropzones by element ID, as there may be multiple dropzones attached to
        // the DOM. This is compounded by the fact that one can now open card popups from foreign projects, and thus identifiers are
        // not guaranteed to be unique on the DOM, even when considering the Rails model type. Don't locate via identifier from
        // the document body e.g. $("some-selector"). Instead, the most reliable way is to locate the closest common container
        // relative to CKEditor's element and the dropzone, and then use .find() with an appropriate selector. This ensures we isolate
        // the element search/traversal within the intended scope (e.g. a particular card, page, or dependency's lightbox).
        //
        // * in full-view edit pages, the attachments dropzone is always within the editor's parent form
        // * in lightboxes, the attachments dropzone is outside always of the form, but inside the lightbox conatiner

        var container = textarea.closest(".lightbox_content");
        if (!container.length) {
            container = textarea.closest("form");
        }

        var element = container.find(".dropzone[data-attachable-id]");
        var dropzone;

        // We must be able to support old lightbox behavior of constructing dropzones not attached to the DOM
        if (!element.length || id !== element.data("attachable-id")) {
            element = $("<div/>").
            data("attachments-upload-url", textarea.data("attachments-upload-url")).
            data("attachment-maxsize", parseInt(textarea.data("attachment-maxsize"), 10)).
            data("attachable-id", textarea.data("attachable-id"));

            if (textarea.data("s3-url")) {
                element.
                    data("s3-url", textarea.data("s3-url")).
                    data("s3-fields", textarea.data("s3-fields")).
                    data("s3-base-key", textarea.data("s3-base-key"));
            }
        }

        if (element.get(0).dropzone) {
            dropzone = element.get(0).dropzone;
        } else {
            dropzone = MingleUI.attachable.initDropzone(element.get(0));
        }

        dropzone.on("success", success);
        dropzone.on("error", handleDropzoneError);
        dropzone.on("cancel", teardown);

        editor.dz = dropzone;

        editor.on("contentDom", function(e) {
            editor.document.on("dragenter", allow, editor);
            editor.document.on("dragleave", allow, editor);
            editor.document.on("dragover", allow, editor);
            editor.document.on("drop", ckShim(dropHandler, editor));

            editor.document.getBody().on("paste", ckShim(imageDataPasteHandler, editor));
            editor.on("paste", imageMarkupPasteHandler);

            $(editor.document.$.body).on("click", ".upload-placeholder .fa-close", function(e) {
                var placeholder = $(e.target).closest(".with-progress-bar");
                var uid = placeholder.data("file-uid");
                var file = uid ? $.grep(editor.dz.files, function(f, i) {
                        return f.uid && f.uid === uid;
                    })[0] : null;

                if (uid && file) {
                    editor.dz.cancelUpload(file);
                } else {
                    d("Failed to cancel upload: uid = " + uid + ", file = " + (file && (file.generatedName || file.name)));
                }

                placeholder.remove();
                e.preventDefault();
            }).on("drop dragover dragenter", "[contenteditable='false']", function(e) {
                e.preventDefault();
            });

          // extends the dropzone so the drop zone takes up the entire space when the content is short
          var padding = $(editor.document.$.documentElement).parent().height() - $(editor.document.$.body).height() - 10;
          if (padding > 0) {
              $(editor.document.$.body).css("padding-bottom", padding + "px");
          }
        });

        editor.on("contentDomUnload", function(e) {
            if (editor.document) {
                editor.document.removeAllListeners();
            }
        });

        editor.on("getData", scrub);
      }
    });

    CKEDITOR.on("instanceDestroyed", function(e) {
        var editor = e.editor;

        if (editor) {
            editor.dz.off("success", success);
            editor.dz.off("error", handleDropzoneError);
            editor.dz.off("cancel", teardown);
        }
    });

    // Easy access for testing
    CKEDITOR.mingle.ddf = {
        dropHandler: dropHandler,
        imageDataPasteHandler: imageDataPasteHandler,
        uploadFromSrc: uploadFromSrc,
        makeInlineElement: makeInlineElement,
        rangeAt: rangeAt
    };
})(jQuery);

// you can run this in the console at runtime to follow all of CKEditor's event firing
function enableCKEventDebug(editor) {
    var orig =  editor.fire;
    editor.fire = function() {
        console.log(arguments);
        return orig.apply(editor, arguments);
    };
}
