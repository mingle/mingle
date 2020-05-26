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
    "use strict";

    var SUCCESS = "error";
    var FAILURE = "failure";

    $.fn.makeFavoritesRenamable = function (options) {
        var favoritesContainer = $(this);

        if(favoritesContainer.data("rename-bound")){
            return;
        }

        favoritesContainer.data("rename-bound", true);

        favoritesContainer.find('div.favorite-item-container').each(function (_, item) {
            attachFavoritesEvent($(item));
        });

        function attachFavoritesEvent(item) {
            var renamingIcon = item.find('.favorites-pencil-icon');
            var savingIcon = item.find('.favorite-save-button');
            item.bindCount = item.bindCount || 1;

            renamingIcon.click(function (_) {
                enterEditMode(item);
            });

            savingIcon.click(function (_) {
                savingIcon.withProgressBar({ event: "mingle.renameFavorite" });
                renameFavoriteWithAjax(item);
            });

            item.find('.input-text').keydown(function(e) {
                if (e.which === $.ui.keyCode.ENTER) {
                    renameFavoriteWithAjax(item);
                    return false;
                }
                if (e.which === $.ui.keyCode.ESCAPE) {
                    enterViewMode(item);
                    return false;
                }
            });

            item.bind("clickoutside", function(){
                enterViewMode(item);
            });
        }

        function enterEditMode(favorite) {
            favorite.find('.view-mode-only').hide();
            favorite.find('.edit-mode-only').show();
            var inputElement = favorite.find('.input-text');
            inputElement.focus();
            inputElement.caret(inputElement.val().length);
        }

        function enterViewMode(favorite) {
            favorite.find('.edit-mode-only').hide();
            favorite.find('.view-mode-only').show();
        }

        function updateFavorite(favorite, data) {
            var truncatedName = truncateString(data.new_name);
            favorite.find('.favorite-link').text(truncatedName);
            favorite.find('.favorite-link').prop('title', data.new_name);
            var updateLinkElement = favorite.find('.update-saved-view');
            var viewUpdateLink = updateLinkElement.attr('href');
            updateLinkElement.attr('title', options.saveTooltipPrefix + " '" + data.new_name + "'");
            var encodedNewNameURIComponent = 'view[name]=' + encodeURIComponent(data.new_name);
            var newLinkAttribute = viewUpdateLink.replace(/(view\[name\]=[^&]+)/, encodedNewNameURIComponent);
            updateLinkElement.attr("href", newLinkAttribute);
            enterViewMode(favorite);
        }

        function truncateString(someString){
            if(('truncationLength' in options) && someString.length > options.truncationLength){
                someString = someString.slice(0,options.truncationLength-3) + '...';
            }
            return someString;
        }

        var errorHandler = makeErrorHandler($, favoritesContainer, {
            errorElementCssClass: "favorites-error-message",
            customrErrorReasons: {
                404: "Favorite may have been destroyed by someone else.",
                422: "Favorite item must have a name"
            },
        });

        function renameFavoriteWithAjax(favorite) {
            favorite.find('.favorite-save-button').trigger('mingle.renameFavorite');
            var params = {
                id: favorite.data('favorite-id'),
                project_id: favorite.data('project-id'),
                new_name: favorite.find('.input-text').val(),
                format: 'json'
            };
            $.ajax(favorite.data('rename-url'), {
                method: 'PUT',
                data: params
            }).done(function(data) {
                updateFavorite(favorite, $.extend({}, params, data));
            }).fail(errorHandler);
        }
    };

    $.fn.bindSaveFavoriteLink = function (options) {
        function displayMessage(message, type, element) {
            var cssClass = (type === SUCCESS) ? "favorite-update-success" : "favorite-update-failure";
            var resultMessageElementHTML = "<div class=\"" + cssClass + "\">" + message + "</div>";
            var resultMessageElement = $(resultMessageElementHTML);
            var favoriteId = element.parents("div.favorite-item-container").data("favorite-id");
            element.parents("li#favorite-" + favoriteId).after(resultMessageElement);
            setTimeout(function() {
                resultMessageElement.remove();
            }, 5000);
        }

        function bindClick(element) {
            $(element).on("click", function(e){
                e.preventDefault();
                var request_data = element.attr("href").split("?");
                var url = request_data[0];
                var params = request_data[1];

                $.ajax(url, {
                    method: 'POST',
                    data: params
                }).done(function() {
                    displayMessage("Favorite saved successfully", SUCCESS, element);
                }).fail(function(data) {
                    displayMessage("Favorite save failed : " + (data.responseText || "Mingle could not be reached."), FAILURE, element);
                });
            });
        }

        function bindParamsListener(element) {
            var user_id = element.parents("div.favorite-item-container").data("user-id");
            ParamsController.register(
                new CardListViewLink(
                    element.attr("id"),
                    {"merge": {"user_id": user_id, "view":{"name":element.data("name")}}}
                    )
            );
        }

        $.each(this.find(".update-saved-view"), function(_, element){
            bindClick($(element));
            bindParamsListener($(element));
        });
    };

    MingleJavascript.register(function(){
        $('#favorites-container').bindSaveFavoriteLink({});
    });
})(jQuery);
