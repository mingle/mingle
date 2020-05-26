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
  var pageSize = 25;

  function setFooter(element, murmurs) {
    murmurs.find(".murmurs-panel-footer").html(element);
  }

  function createInfoEle(text) {
    return $("<div class='info'>" + text + "</div>");
  }

  function loading(murmurs) {
    return murmurs.siblings('.murmurs-loading');
  }

  function mId(m) {
    var id = m.data('murmur-id');
    if (id) {
      return parseInt(id);
    } else {
      return -1;
    }
  }

  function appendLoadMore(murmurs) {
    if(murmurs.find('.load-more').length === 0) {
      var element = $('<button class="primary load-more">Load more</button>');
      setFooter(element, murmurs);
      element.click(function(e) {
        setFooter($('<i class="fa fa-refresh fa-spin fa-2x"></i>'), murmurs);
        loadMore(murmurs, function(data) {
          if (data.length === pageSize) {
            appendLoadMore(murmurs);
          } else {
            setFooter(createInfoEle("No more murmurs."), murmurs);
          }
        });
        return false;
      });
    }
  }

  function markAllMurmursRead(murmurs) {
    var fbUrl = murmurs.data("unread-murmurs-fb-url");
    if(!fbUrl) { return; }

    new Firebase(fbUrl).remove();
  }

  function loadMurmurs(murmurs) {
    if (!murmurs.is(":visible")) {
      return;
    }
    murmurs.scrollTop(0);
    loading(murmurs).slideDown();

    var mms = murmurs.find('.murmur-panel');
    var mid = murmurs.data('murmur-id');
    var loadMurmurCond = null;

    mms.show();
    if (mid) {
      mid = parseInt(mid);
      loadMurmurCond = { before_id: mid + 1, since_id: mid - 1 };
      murmurs.data('murmur-id', null);
      try {
        history.replaceState({}, document.title, window.location.href.replace("murmur_id=", "replied="));
      }catch(e) {
        //ignore
      }
    }
    ajaxLoadMurmurs(murmurs, loadMurmurCond, function(data, status, xhr) {
      loading(murmurs).slideUp();

      if (mms.length == 1) {
        $(mms[0]).remove();
        mms = murmurs.find('.murmur-panel');
      }

      var dups = $.map(data.reverse(), function(html, i) {
        var m = $(html);
        var id = mId(m);
        if (murmurs.find('[data-murmur-id='+id+']').length) {
          return m;
        }
        m.hide().prependTo(murmurs).slideDown();
        if (loadMurmurCond != null) {
          m.find('.murmur-reply').click();
        }
      });

      if (data.length === 0) {
        setFooter(createInfoEle("There are currently no murmurs."), murmurs);
      } else {
        if (dups.length === 0) {
          $.each(mms, function(i, e) {
            e.remove();
          });
        }
        if (loadMurmurCond == null) {
          appendLoadMore(murmurs);
        }
      }
    });
    markAllMurmursRead(murmurs);
  }

  function loadMore(murmurs, callback) {
    var lastMurmur = murmurs.find('.murmur-panel').last();
    var beforeId = lastMurmur.data('murmur-id');
    var loadMurmurCond = null;
    if (beforeId) {
      loadMurmurCond = { before_id: beforeId };
    }
    ajaxLoadMurmurs(murmurs, loadMurmurCond, function(data, status, xhr) {
      $.each(data.reverse(), function(i, html) {
        lastMurmur.after($(html));
      });
      callback(data);
    });
  }

  function ajaxLoadMurmurs(murmurs, loadMurmurCond, callback) {
    $.ajax(murmurs.data('source-url'), {
      contentType: 'json',
      data: loadMurmurCond
    }).done(function(data, status, xhr) {
      callback(data, status, xhr);
      murmurs.find('[rel=tipsy]').tipsy();
    });
  }

  function sendMurmur(murmurInput, murmurs) {
    if (murmurInput.val() == "" || murmurInput.data('sending')) {
      return false;
    }
    murmurInput.data('sending', true);
    loading(murmurs).slideDown();
    $.ajax(murmurInput.data('post-url'), {
      type: 'POST',
      dataType: 'json',
      data: {
        murmur: {
          murmur: murmurInput.val(),
          conversation_id: currentConversationId(murmurs),
          replying_to_murmur_id: murmurInput.data('replying-to-murmur')
        }
      }
    }).
      success(function(data) {
        if(data.conversation_id) {
          associateMurmursWithConversation(murmurs, data.murmur_ids, data.conversation_id);
          murmurs.trigger('show-conversation', murmurs.find('[data-murmur-id="'+data.murmur_ids[0]+'"]'));
        } else {
          loadMurmurs(murmurs);
        }
      }).
      always(function(data, status, xhr) {
        murmurInput.data('sending', false);
        murmurInput.val('');
        murmurInput.removeData('replying-to-murmur');
        murmurInput.focus();
        mixpanelTrack('create_murmur', {project_name: $('#header .header-name').text()});
    });
    return true;
  }

  function associateMurmursWithConversation(murmurs, murmurIds, conversationId) {
    murmurs.find(".murmur-panel").each(function() {
      var murmur = $(this);
      var id = murmur.data("murmur-id");
      if ($.inArray(id, murmurIds) >= 0) {
        murmur.data('conversation-id', conversationId);
        murmur.find(".murmur-conversation").show();
      }
    });
  }

  function currentConversationId(murmurs) {
    return murmurs.data("current-conversation-id");
  }

  function setCurrentConversationId(murmurs, id) {
    murmurs.data("current-conversation-id", id);
  }

  function ajaxLoadConversation(murmurs, conversationId, callback) {
    loading(murmurs).slideDown();
    var conversationUrl = murmurs.data("conversations-url") + "?conversation_id=" + conversationId;

    $.ajax(conversationUrl, {
      data_type: 'json',
      success: function(data) {
        $.each(data, function(index, html) {
          murmurs.prepend($(html).addClass("in-conversation"));
        });
        murmurs.trigger('update-conversation-header', $('.murmur-panel').first().data('conversation-count'));
      },
      complete: function() {
        loading(murmurs).slideUp();
        callback();
      }
    });
  }

  function addShowAllButton(murmurs) {
    var element = $('<button class="primary show-all">Show all</button>');
    setFooter(element, murmurs);
    element.click(function(e) {
      element.hide();
      murmurs.trigger('close-conversation');
      loadMurmurs(murmurs);
    });
  }

  function move(element, offset) {
    var oldOffset = element.offset();
    var temp = element.clone().appendTo('body');
    temp.css('position', 'absolute')
      .css('left', oldOffset.left)
      .css('top', oldOffset.top)
      .css('width', element.width())
      .css('height', element.height())
      .css('list-style', 'none')
      .css('zIndex', 99000);
    element.hide();
    temp.animate({'top': offset.top, 'left': offset.left}, 400, function(){
      element.show();
      temp.remove();
    });
  }

  $(document).ready(function() {
    var mdd = $('#murmurs-drop-down');
    var conversationHeader = mdd.find(".conversation-header");
    var input = mdd.find('.murmurs-input [name="murmur"]');
    var murmurs = mdd.find('.murmurs-panel');

    mdd.on("click", ".murmur-conversation", function(e) {
      e.preventDefault();
      murmurs.trigger('show-conversation', $(this).parents("li.murmur-panel"));
    });

    mdd.on("click", ".murmur-reply", function(e) {
      var replyTo = $(this).data("reply-to");
      if ($.trim(replyTo).length) {
        input.focus().val(replyTo + ' ');
      }
      input.data('replying-to-murmur', $(this).data("replying-to-murmur"));
      if(currentConversationId(murmurs)) {
        return;
      }
      murmurs.trigger('show-conversation', $(this).parents("li.murmur-panel"));
    });

    mdd.popover({
      afterShow: function(content) {
        murmurs.trigger('close-conversation');
        loadMurmurs(murmurs);
        mdd.find('[autofocus="true"]').focus();
        mdd.find(".murmurs-input [name=\"murmur\"]").removeData('replying-to-murmur');
      }
    });

    mdd.find('button.send').click(function(e) {
      return sendMurmur(input, murmurs);
    });

    conversationHeader.find('.close-conversation').click(function(e){
      murmurs.trigger('close-conversation');
      loadMurmurs(murmurs);
    });

    murmurs.on('show-conversation', function(e, murmur) {
      murmur = $(murmur);
      input.focus();
      var cid = murmur.data("conversation-id");
      if(cid) {
        setCurrentConversationId(murmurs, cid);
        murmurs.children().hide();
        ajaxLoadConversation(murmurs, cid, function() {
          conversationHeader.slideDown();
        });
      } else {
        murmurs.trigger('update-conversation-header', 1);
        move(murmur, {top: murmurs.offset().top + conversationHeader.height(), left: murmurs.offset().left});
        murmur.siblings().fadeOut();
        conversationHeader.slideDown();
      }
    });

    murmurs.on('close-conversation', function(e) {
      conversationHeader.hide();
      murmurs.find(".murmur-panel.in-conversation").remove();
      setCurrentConversationId(murmurs, null);
      input.removeData('replying-to-murmur');
      input.val('');
      murmurs.find('.murmurs-panel-footer').show();
    });

    murmurs.on('update-conversation-header', function(e, count) {
      var meh = parseInt(count) > 1 ? ' murmurs' : ' murmur';
      conversationHeader.find('.conversation-count').html(count + meh);
    });

    input.keydown(function(e) {
      if (e.which == $.ui.keyCode.ESCAPE) {
        if (currentConversationId(murmurs)) {
          murmurs.trigger('close-conversation');
          loadMurmurs(murmurs);
        } else {
          mdd.popoverClose();
        }
        return;
      }
    });

    input.keypress(function(e) {
      if (!(e.shiftKey || e.metaKey || e.ctrlKey) && e.which == $.ui.keyCode.ENTER) {
        sendMurmur($(this), murmurs);
        return false;
      }
    });

    if (murmurs.data('murmur-id')) {
      mdd.click();
    }
  });
})(jQuery);
