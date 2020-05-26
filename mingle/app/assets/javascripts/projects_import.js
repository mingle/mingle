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
  $(document).ready(function() {
    var files;

    $("#import-form").submit(function(e) {
      var config = $("[data-signer-url]");
      var query = $.param({
        project: {
          name: $('#project_name').val(),
          identifier: $('#project_identifier').val(),
        },
        s3_object_key: config.data('key')
      });

      function uploadSuccess() {
        $(".cloud-upload-progress").hide();
        var url = [config.data("success-url"), "?", query].join("");
        window.location.replace(url);
      }

      function progress(p) {
        $(".cloud-upload-progress .percent").text((p * 100).toFixed(1));
      }

      function handleError(msg) {
        $(".cloud-upload-progress").hide();
        var error = $("<div class='error-box'/>");
        error.append($("<div class='flash-content'/>").text(msg));
        $("#flash").empty().append(error);
      }

      if (config.length) {
        e.preventDefault();
        $(".cloud-upload-progress .percent").text("0.0");

        var _e_ = new Evaporate({
          logging: true,
          signerUrl: config.data("signer-url"),
          bucket: config.data("bucket"),
          aws_key: config.data("aws-id"),
          aws_url: "https://s3-us-west-1.amazonaws.com", // import bucket is not in US-standard region
          partSize: 10 * 1024 * 1024
        });

        var configuration = {
          name: config.data("key"),
          file: files[0],
          contentType: "application/zip",
          error: handleError,
          progress: progress,
          complete: uploadSuccess
        };

        if (config.data("session-token")) {
          configuration.xAmzHeadersAtInitiate = {
            "x-amz-security-token": config.data("session-token")
          };
          configuration.xAmzHeadersAtUpload = {
            "x-amz-security-token": config.data("session-token")
          };
          configuration.xAmzHeadersAtComplete = {
            "x-amz-security-token": config.data("session-token")
          };
        }

        _e_.add(configuration);
      } else {
        $(".cloud-upload-progress .percent").remove();
      }

      if ($("#success_action_redirect").size() > 0) {
        var redirect_url = $('#success_action_redirect').val();
        var new_url = [redirect_url, "?", query].join("");
        $("#success_action_redirect").val(new_url);
      }

      $("#flash").empty();
      $(".cloud-upload-progress").show();
    });

    $("#import-form input[type='file']").change(function(e) {
      var submit = $("#import-form input[type='submit']");
      if ($(this).val() === "") {
        submit.attr("disabled", "disabled");
      } else {
        files = e.target.files;
        submit.removeAttr("disabled");
      }
    });
  });
})(jQuery);
