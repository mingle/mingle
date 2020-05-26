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
AuthenticityToken = {
  appendToForm: function(f) {
    var auth = document.createElement('input');
    auth.type = 'hidden';
    auth.name = $j('meta[name="csrf-param"]').attr('content');
    auth.value = $j('meta[name="csrf-token"]').attr('content');
    f.appendChild(auth);
  },

  clearCache: function() {
    var token = $j('meta[name="csrf-token"]').attr('content');
    if (token) {
        $j('input[name="authenticity_token"]').val(token);
    }
  }
};

Ajax.Responders.register({
  onCreate: function(request, response) {
    if (request.method == 'post') {
      var token = $j('meta[name="csrf-token"]').attr('content');
      if (token) {
        if (!request.options.requestHeaders) {
          request.options.requestHeaders = {};
        }
        request.options.requestHeaders['X-CSRF-Token'] = token;
      }
    }
  }
});

if ($j) {
  $j.ajaxSetup({
    beforeSend: function(request) {
      if (request.method != 'get') {
        request.setRequestHeader("X-CSRF-TOKEN", $j('meta[name="csrf-token"]').attr("content"));
      }
    }
  });
}

MingleUI.readyOrAjaxComplete(function() {
  AuthenticityToken.clearCache();
});
