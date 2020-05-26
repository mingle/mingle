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
var MingleUI = (MingleUI || {});
(function($) {

  function d(message) {
    (console && "function" === typeof console.log) && console.log(message);
  }

  function FirebaseDatasource(endpoint, options) {
    var token     = options.token,
        startAt   = (isNaN(options.startAt) || null === options.startAt) ? 0 : options.startAt;

    function handleAuth(error, authData) {
      if (error) {
        MingleUI.live.status.fb = "auth failed";
        MingleUI.live.status.on = false;

        d("Login Failed!", error);
      } else {
        MingleUI.live.status.fb = "authenticated";
        MingleUI.live.status.on = true;
      }
    }

    var ref = new Firebase(endpoint);
    ref.authWithCustomToken(token, handleAuth);

    var query = ref.orderByChild("id").startAt((isNaN(startAt) || null === startAt) ? 0 : startAt).limitToLast(100);

    var relpath = ref.toString().replace(ref.root().toString());
    var retentionTag = relpath.split("/")[1];

    this.endpointAt = function endpointAt(tag) {
      return ref.toString().replace("/" + retentionTag + "/", "/" + tag + "/");
    };

    this.nextEndpoint = function nextEndpoint() {
      return this.endpointAt(FirebaseDatasource.nextTag(retentionTag));
    };

    this.prevEndpoint = function prevEndpoint() {
      return this.endpointAt(FirebaseDatasource.prevTag(retentionTag));
    };

    this.tag = function getTag() {
      return retentionTag;
    };

    this.on = function on(eventName, handler) {
      if (query) {
        query.on(eventName, handler);
      }
      return this;
    };

    this.terminate = function terminate() {
      ref.off();
      query.off();
      ref = query = null;
    };
  }

  function adjustTagByDays(tag, numDays) {
    var components = tag.split("-"); // ISO-8601 date string

    for (var i = 0, len = components.length; i < len; i++) {
      components[i] = parseInt(components[i], 10);

      if (i === 2) components[i] += numDays; // adjust by number of days
    }

    var date = new Date(Date.UTC(components[0], components[1] - 1 /* month is zero-based */, components[2]));

    // note: NOT the same as JSON.stringify(); Date.toJSON() is a precursor/intermediate step to the result of JSON.stringify(Date)
    return date.toJSON().split("T")[0];
  }

  $.extend(FirebaseDatasource, {
    nextTag: function(currentTag) {
      return adjustTagByDays(currentTag, 7);
    },
    prevTag: function(currentTag) {
      return adjustTagByDays(currentTag, -7);
    }
  });

  function FederatedFirebase(endpoint, options) {
    var federated = new Firebase(endpoint);

    federated.authWithCustomToken(options.token, function(error, authData) {
      if (error) d("Failed to acquire federated week, auth failed.");
    });

    function firebased(fn) {
      return function (snapshot) {
        fn(snapshot.val());
      };
    }

    this.useStrategy = function(handler) {
      federated.off("value");
      federated.on("value", firebased(handler));
    };
  }

  function SwitchingDatasource(endpoints, handler, options) {
    var sources = [], DatasourceType, EndpointFederation, federation;

    DatasourceType = ("function" === typeof options.provider) ? options.provider : FirebaseDatasource;
    delete options.provider;

    federation = options.federation;
    delete options.federation;

    function switchingWrapper(source, fn) {
      return function (snapshot, previousKey) {
        var last = sources.length - 1;

        if (last === 2 && sources.indexOf(source) === last) {
          var promoted = sources[last]; // promote to the current datasource

          d("Switching datasources; received data on newest datasource: " + promoted.tag());

          // evict oldest datasource; it shouldn't have any relevant data anymore
          d("Evicting datasource: " + sources[0].tag());
          sources.shift().terminate();

          // create future datasource
          var nextSource = new DatasourceType(promoted.nextEndpoint(), options);
          sources.push(nextSource.on("child_added", switchingWrapper(nextSource, handler)));

          d("Demoted datasource: " + sources[0].tag());
          d("Current datasource: " + sources[1].tag());
          d("Next datasource: " + sources[2].tag());
        }

        fn(snapshot, previousKey);
      };
    }

    function setupEndpoints() {
      $.each(endpoints, function (i, url) {
        var source = new DatasourceType(url, options);
        sources.push(source.on("child_added", switchingWrapper(source, handler)));
      });
    }

    function ensureDatasourcesIncludeCurrent(snapshot) {
      if (null === snapshot) {
        return;
      }

      var current = snapshot, activeTags = [];

      for (var i = 0, len = sources.length; i < len; i++) {
        activeTags.push(sources[i].tag());
      }

      if (activeTags.indexOf(current) === -1) {
        // update the endpoints to surround the current week
        endpoints = [sources[0].endpointAt(DatasourceType.prevTag(current)), sources[0].endpointAt(current), sources[0].endpointAt(DatasourceType.nextTag(current))];

        while (sources.length > 0) {
          // purge all of the sources
          sources.shift().terminate();
        }

        // replenish with new sources
        setupEndpoints();
      }
    }

    this.sources = sources;
    setupEndpoints();

    // if the automatic switching fails to choose the actual current week, we can ask the server to tell us what the current
    // week should be and renew all datasources. this might only happen in some edge cases, as the switchingWrapper() is pretty
    // reliable. this might be completely unnecessary since all issues are fixed when the page reloads.
    //
    // a theoretical situation that needs this would be if a browser hasn't been connected to firebase for a very long time (e.g.
    // for weeks), and the page hasn't been refreshed (e.g. team dashboard/radiator), we may never receive data on the final endpoint
    // to trigger a datasource switch.
    if (federation) {
      EndpointFederation = ("function" === typeof federation.provider) ? federation.provider : FederatedFirebase;
      delete federation.provider;
      var url = federation.endpoint;
      delete federation.endpoint;

      var federated = new EndpointFederation(url, federation);
      federated.useStrategy(ensureDatasourcesIncludeCurrent);
    }
  }

  MingleUI.live = $.extend(MingleUI.live || {}, {
    SwitchingDatasource: SwitchingDatasource,
    FirebaseDatasource: FirebaseDatasource
  });

})(jQuery);
