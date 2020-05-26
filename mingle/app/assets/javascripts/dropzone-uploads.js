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
    // we want to finely control dropzone instantiation
    Dropzone.autoDiscover = false;

    // Don't ask user via alert, just pass through
    Dropzone.confirm = function(question, accepted, rejected) {
        accepted();
    };

    /*
     * Wire up with dropzone to handle server upload, etc
     */

    function initDropzone(element) {

        var template = '<li class="dz-preview" ondragenter="return false;" ondragleave="return false;" ondragover="return false;">' +
                           '<div class="dz-progress"><span class="dz-upload" data-dz-uploadprogress></span></div>' +
                           '<a href="#" class="file-action view-file" target="_blank" title="Open attachment in browser"><i class="fa fa-eye"></i></a>' +
                           '<a href="#" class="file-action download-file" title="Download attachment"><i class="fa fa-cloud-download"></i></a>' +
                           '<div class="dz-filename"><span data-dz-name></span><span data-dz-errormessage></span></div>' +
                       '</li>';

        var blessed = $(element);
        var options = {
            url: blessed.data("s3-url") || blessed.data("attachments-upload-url"),
            paramName: blessed.data("s3-url") ? "file" : "upload",
            maxFilesize: parseInt(blessed.data("attachment-maxsize"), 10),
            createImageThumbnails: false,
            clickable: $.contains(document.documentElement, element) ? ".click-upload" : true,
            previewTemplate: template,
            parallelUploads: 1,
            processing: function(file) {
                // set S3 key/path before upload
                if (this.options.baseKey) {
                    this.options.params.key = [this.options.baseKey, randomId(null, 2), (file.generatedName || file.name)].join("/");
                    this.options.params["Content-Type"] = file.type;
                }
            },
            sending: function(file, xhr, formData) {
                // for S3 upload, the filename is set by the S3 key
                if (!blessed.data("s3-url")) {
                    addCSRFHeader(xhr);
                    if (file.generatedName) {
                        // when file.name is blank, the file isn't uploaded, as is the case with pasting
                        formData.append("upload", file, file.generatedName);
                    }
                }
            },
            success: successfulUpload,
            dragleave: function(e) {
                var x = e.x || e.pageX, y = e.y || e.pageY;
                var el = document.elementFromPoint(x, y);

                if (!el || !(el === element || $.contains(element, el))) {
                    blessed.removeClass("dz-drag-hover");
                }
            }
        };

        if (blessed.data("s3-fields")) {
            options.params = blessed.data("s3-fields");
            options.baseKey = blessed.data("s3-base-key");
        }
        var dropzone = new Dropzone(element, options);

        if (blessed.hasClass('dz-disabled')) {
          dropzone.disable();
        }

        dropzone.on("error", function(file, errorMessage, xhr) {
            $(file.previewElement).find(".file-action").removeAttr("href").on("click", function(e) {return false;});
        });

        dropzone.on("addedfile", function(file) {
            var preview = $(file.previewElement);
            preview.find("[data-dz-thumbnail]").replaceWith("<i class=\"fa fa-fw fa-5x fa-file\">");

            if (file.stored) {
                preview.data("download-url", file.stored.url);
                preview.find(".file-action").attr("href", file.stored.url);
                preview.find(".download-file").attr("href", file.stored.url + "?download=yes");
                preview.attr("title", file.name);
                preview.addClass("dz-complete").addClass("dz-success").find("[data-dz-size]").text("Saved");
            }
            var el = $(dropzone.element);
            var removeLink;
            if (!el.data("authorized-to-delete")) {
              removeLink = $("<i class=\"dz-remove disabled\" title=\"Delete attachment\"></i>");
            } else {
              removeLink = $("<i class=\"dz-remove\" title=\"Delete attachment\"></i>").on("click", function(e) {
                if (confirm("Are you sure you want to delete this attachment?")) {
                  if ("show" === el.data("mode") && preview.is(".dz-success")) {
                    var filename = preview.find("[data-dz-name]").text();
                    preview.find("[data-dz-name]").html("Removing&hellip; <i class='fa fa-spin fa-circle-notch-o'></i>");
                    $.ajax({
                      url: el.data("delete-url") + "&" + $.param({file_name: filename}),
                      type: "POST",
                      dataType: "json",
                    }).done(function () {
                        dropzone.removeFile(file);
                    });
                  } else {
                      dropzone.removeFile(file);
                  }
                }
              });
            }
            preview.append(removeLink);

        });
        dropzone.on("removedfile", function(file) {
            if (file.status === Dropzone.SUCCESS) {
                if ("edit" === $(dropzone.element).data("mode")) {
                    var realName = $(file.previewElement).find("[data-dz-name]").text();
                    var hiddenInput = $("<input type=\"hidden\" />").val(true);
                    hiddenInput.attr("name", "deleted_attachments[" + realName + "]");
                    $(this.element).prepend(hiddenInput);
                } else {
                    // remove version param from add_description
                    var links = $("#add_description_link, a.edit");
                    if (links.length) {
                        var re = new RegExp("[\\?\\&]coming_from_version=\\d+");
                        links.each(function (i, el) {
                            el = $(el);
                            el.attr("href", el.attr("href").replace(re, ""));
                        });
                    }
                }
            }
            updateFileCount(dropzone);
        });
        dropzone.on("complete", resetS3Params);

        updateExistingAttachments(blessed);
        updateFileCount(dropzone);

        return dropzone;
    }

    // persists attachment to Mingle
    function successfulUpload(file, data, e) {
        var dropzone = this;

        // for add new card/page, pending attachments will be associated on save
        var attachmentId;
        var preview = $(file.previewElement);

        if (("string" === typeof data) && file.xhr && file.xhr.responseXML) {
            var s3key = $(file.xhr.responseXML).find("Key").text();

            preview.addClass("save-in-progress").find("[data-dz-name]").text("Processing " + file.name + "…");
            preview.find(".dz-details").prepend("<span class='busy'><i class='fa fa-spin fa-3x fa-fw fa-cog'/><br/>Processing&hellip;</span>");
            $.ajax({
                url: $(dropzone.element).data("attachments-upload-url"),
                type: "POST",
                dataType: "json",
                async: false,
                data: {"s3": s3key},
            }).done(function(json, status, xhr) {
                preview.find("[data-dz-size]").text("Saved");
                preview.find(".busy").remove();

                dropzone.emit("success", file, json);
            });
        } else {
            attachmentId = data.path.split("/").pop();
            preview.find("[data-dz-name]").text(data.filename);
            preview.attr("title", data.filename);
            preview.data("download-url", data.path);
            preview.find(".file-action").attr("href", data.path);
            preview.find(".download-file").attr("href", data.path + "?download=yes");
            preview.addClass("dz-success").removeClass("save-in-progress");

            updateFileCount(dropzone);
            ensureAttachedToNewRecords(attachmentId, dropzone);
        }
    }

    function updateExistingAttachments(element) {
        element[0].dropzone.removeAllFiles();
        var attachments = element.removeData("attached").data("attached");

        if (attachments) {
            $.each(attachments, function(i, f) {
                var fakefile = {name: f.filename, size: "", stored: f, status: Dropzone.SUCCESS};
                element[0].dropzone.files.push(fakefile);
                element[0].dropzone.emit("addedfile", fakefile);
            });
        }

        updateFileCount(element[0].dropzone);
    }

    // updates file counter on header
    function updateFileCount(dropzone) {
        var panel = $(dropzone.element).closest(".panel-content");

        if (panel.length) {
            var count = $(dropzone.element).find(".dz-success").length;
            count = count > 100 ? "99+" : count.toString();
            panel.find("[data-total-files]").attr('data-total-files', count);
        }
    }

    // this adds the proper inputs on card/page create
    function ensureAttachedToNewRecords(attachmentId, dropzone) {
        if ($("input[value='" + attachmentId + "']").length > 0) {
          return;
        }

        var input = $("<input name='pending_attachments[]' type='hidden'/>").val(attachmentId);
        if ($.contains(document.body, dropzone.element)) {
           // full view
           $(dropzone.element).prepend(input);
        } else {
            // lightbox does not have an attachments container, but we still need to associate attachments
            $(".lightbox_content form").prepend(input);
        }
    }

    function resetS3Params(file) {
      var dropzone = this;
        if (dropzone.options.params.key) {
            dropzone.options.params.key = null;
            dropzone.options.params["Content-Type"] = null;
        }
    }

    function addCSRFHeader(request) {
        request.setRequestHeader("X-CSRF-TOKEN", csrfAuthToken());
    }

    function csrfAuthToken() {
        return $('meta[name="csrf-token"]').attr("content");
    }

    function randomId(prefix, grouplength) {
        var r = (!!prefix ? [prefix] : []);
        for (var i = 0; i < grouplength; i++) {
            r.push(Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1));
        }
        return r.join("-");
    }

    MingleUI.attachable = {
        initDropzone: initDropzone,
        updateExistingAttachments: updateExistingAttachments,
        randomId: randomId
    };

    $(document).ready(function(e) {
        var element = $(".dropzone[data-attachable-id]");
        if (element.length) {
            var dropzone = initDropzone(element.get(0));
        }
    });
})(jQuery);
