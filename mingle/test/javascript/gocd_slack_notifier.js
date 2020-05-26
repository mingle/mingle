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
var GoCDSlackNotifier = function(){
	var env = require('system').env;

	function serialize(obj) {
		var str = [];
		for(var p in obj) {
			if (obj.hasOwnProperty(p)) {
				str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
			}
		}
		return str.join("&");
	};

	var GitLab = function() {
		var apiVersion = env.API_VERSION || 'v3';
		var projectPath = encodeURIComponent(env.GITLAB_PROJECT_PATH_WITH_NAMESPACE || 'mingle/mingle');
		var commitUrl = env.GITLAB_BASE_URL + "/api/" + apiVersion + "/projects/" + projectPath + "/repository/commits/" + env.GO_REVISION_GIT;
		var settings = { headers: { "PRIVATE-TOKEN": env.GITLAB_PRIVATE_TOKEN } };

		this.fetchCommitData = function(page, callback) {
			console.log("Fetching username from commit");
			var data =null;
			page.open(commitUrl, settings, function(status) {
				if(status === "success"){
					data = JSON.parse(page.plainText);
				} else {
					console.log("GitLab failure: ", page.plainText);
				}
			});

			page.onLoadFinished = function () {
				callback(page, data);
			}
		};
	}

	var Slack = function() {
		var attachments = JSON.stringify([{"text": "", "image_url": "https://media.giphy.com/media/X4YqmJEl6wJoY/giphy.gif"}]);
		var fs = require("fs");
		var gitlabSlackUserData = JSON.parse(fs.read(env.GIT_SLACK_USER_FILE));

		this.notify = function(page, authorName, message, done) {
			console.log("Notifying user on Slack");
			var queryString = serialize({
				token: env.SLACK_API_TOKEN,
				channel: "@"+gitlabSlackUserData[authorName],
				text: message || "I am so disappoint",
				username: "GoCDBot",
				as_user: false,
				attachments: attachments
			});
			page.open("https://slack.com/api/chat.postMessage?"+queryString, function(status) {
				done(status);
			});
		};
	}

	this.notify = function(message, success, failure) {
		var page = require('webpage').create();

		new GitLab().fetchCommitData(page, function(_page, data) {
			_page.onLoadFinished = function() {};
			if (data && data.author_name) {
				new Slack().notify(_page, data.author_name, message, function(status) {
					if (status === 'success') {
						console.log("Done");
						success && success();
					} else {
						failure && failure();
					}
				});
			} else {
				failure && failure();
			}
		});
	};
}

// Example usage:
var success = function() {
	phantom.exit(0);
};

var failure = function() {
	phantom.exit(1);
}

var fs = require('fs');
if (fs.exists('./jshint.errors')) {
	var errors = fs.read('./jshint.errors');
	new GoCDSlackNotifier().notify(errors + "\nI'm so disappoint", success, failure);
}
