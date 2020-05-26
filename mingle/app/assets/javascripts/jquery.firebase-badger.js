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

  function badgeRefresh(badge) {
    if(!badge.hasClass('hidden')) {
      badge.toggle(badgeGetCount(badge) !== 0);
    }
  }

  function badgeSetCount(badge, count) {
    badge.text(count);
    badgeRefresh(badge);
  }

  function badgeGetCount(badge) {
    return parseInt(badge.text() || 0);
  }

  function badgeIncrement(badge) {
    badgeSetCount(badge, badgeGetCount(badge) + 1);
  }

  function badgeDecrement(badge) {
    badgeSetCount(badge, badgeGetCount(badge) - 1);
  }

  function expiredFbEvent(snapshot) {
    var fourteenDaysAgo = (new Date().getTime() - (1209600000));
    if (fourteenDaysAgo >= new Date(snapshot.val().created_at).getTime()) {
      snapshot.ref().remove();
      return true;
    }
    return false;
  }

  function send_murmur_desktop_notification(badge, murmur) {
    if (!murmur.author || !Notification) {
      return;
    }

    if (Notification.permission !== "granted")
      Notification.requestPermission();
    else {
      var userName = JSON.parse(murmur.author).name;
      var isCardMurmur = murmur.card_number ? true : false;
      var onCard = isCardMurmur ? ' on #' + murmur.card_number : '';
      var title = 'You have been murmured' + onCard;
      var notification = new Notification(title, {
        icon: window.location.origin + '/images/mingle_logo_blue.png',
        body: userName + ": " + murmur.text
      });

      var openGlobalMurmurs = function() {
        if ($j("#murmurs-drop-down")) {
          $j("#murmurs-drop-down").click();

          //In case it was open already and we closed it
          if (!$j("#murmurs-drop-down").hasClass('open'))
            $j("#murmurs-drop-down").click();
        }
      };

      var openCardPopup = function() {
        $.ajax({
            url: badge.data("card-popup-url"),
            data: {"number" : murmur.card_number},
            type: 'GET'
          }).done(function(data, status, xhr) {
            badgeSetCount(badge, 0);
            var lightbox = $('.card-popup-lightbox [data-card-number="' + murmur.card_number +'"]').parents('.card-popup-lightbox');
            MingleUI.lightbox.displayMurmursPanel(lightbox);
          }).fail(function(e) {
            openGlobalMurmurs();
          });
      };

      notification.onclick = function () {
        window.focus();
        if (isCardMurmur) {
          openCardPopup();
        } else {
          openGlobalMurmurs();
        }
        this.close();
        mixpanelTrack('murmur_desktop_notification_clicked', {project_name: $j('#header .header-name').text()});
      };

      notification.onclose = function () {
          var fbUrl = $j("#murmurs-drop-down .murmurs-panel").data("unread-murmurs-fb-url");
          if(!fbUrl) { return; }
          new Firebase(fbUrl).remove();
      };
    }
  }

  $.fn.firebaseBadger = function() {
    return $(this).each(function() {
        var badge = $(this);
        badgeRefresh(badge);
        var fbItemUrl = badge.data("fb-items-url");
        if (!fbItemUrl) { return; }

        var fb = new Firebase(fbItemUrl);
        var fbToken = badge.data("fb-token");

        if (fbToken !== undefined) {
            fb.authWithCustomToken(fbToken, function(error) {});
        }

        fb.on("child_added", function(snapshot) {
            if (!expiredFbEvent(snapshot)) {
              badgeIncrement(badge);
              send_murmur_desktop_notification(badge, snapshot.val());
            }
        });

        fb.on("child_removed", function(snapshot) {
            if (!expiredFbEvent(snapshot)) {
              badgeDecrement(badge);
            }
        });

    });
  };

})(jQuery);
