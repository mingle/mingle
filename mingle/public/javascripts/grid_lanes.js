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

    function PropertyDropDown(element, options) {
      this.element = element;

      var self = this;
      var content = this.element.find(".content");
      var form = this.element.find("form.filter-values");
      var filter = form.find("input");

      this.options = $.extend({
        beforeShow: $.noop,
        afterShow: $.noop,
        doCreate: $.noop,
        doSelect: $.noop,
        dataAttr: "values"
      }, options || {});

      // bind these functions to this
      this.options.beforeShow = $.proxy(this.options.beforeShow, this);
      this.options.afterShow = $.proxy(this.options.afterShow, this);
      this.options.doCreate = $.proxy(this.options.doCreate, this);
      this.options.doSelect = $.proxy(this.options.doSelect, this);

      this.refresh = function refresh() {
        filter.val("").focus().filteredList("search", "").trigger("keydown");
      };

      var zeroOrGreater = function(number){
        return [0, number].max();
      };

      this.element.popover({
        beforeShow: function(content) {
          content.removeClass("create-new-value");
          filter.val("");
          self.options.beforeShow(content);
        },
        afterShow: function(content) {
          self.refresh();

          // try to center the dropdown
          var dd = self.element;
          var center = dd.offset().left + (dd.width() / 2);
          if (!dd.is(".open")) {
            dd.addClass(".open");
          }
          var leftEdgeFromDoc = content.offset().left;
          var centerContent = leftEdgeFromDoc + (content.outerWidth() / 2);

          // make sure dropdown doesn't fall off the left edge of the viewport
          var left = zeroOrGreater(content.position().left - Math.min(leftEdgeFromDoc, (centerContent - center)));
          content.css("left", left + "px");

          // make sure dropdown doesn't fall off the right edge of the viewport
          var rightEdge = content[0].getBoundingClientRect().right;
          if (rightEdge > $j(window).width()) {
            var adjustment = rightEdge - $j(window).width();
            left = zeroOrGreater(left - adjustment);
            content.css("left", left + "px");
          }
          self.options.afterShow(content);
        }
      });

      var newValueForm = this.element.find("form.create");
      if (newValueForm.size() > 0) {

        this.element.on("click", ".new-property", function(e) {
          newValueForm[0].reset();
          content.addClass("create-new-value");
          newValueForm.find("input[type='text']").focus();
        });

        newValueForm.submit(function(e) {
          e.preventDefault();
          var name = $.trim(newValueForm.find("input[type='text']").val());
          self.options.doCreate(name);
        });
      }

      this.close = function close() {
        self.element.popoverClose();
        $(document).trigger("mingle:relayout");
      };

      this.element.on("keydown", "input[type='text']", function(e) {
        if (e.keyCode === $.ui.keyCode.ESCAPE) {
          self.close();
        }
      });

      form.submit(function(e) {
        e.preventDefault();
      });

      filter.filteredList({
        minLength: 0,
        delay: 0,
        appendTo: form,
        containerClass: "properties",
        position: {using: function(){}},
        source: function( request, response ) {
          var values = self.element.data(self.options.dataAttr);
          response(MingleUI.fuzzy.finder(values, request.term.toString()));
        },
        select: function(e, ui) {
          self.options.doSelect(e, ui);
        }
      });
    }

    $.fn.propertyDropDown = function() {
      // deinitialize previous handlers e.g. after AJAX refresh
      $(document).off("click", this.selector);

      this.pdd = new PropertyDropDown(this);
      return this;
    };

    $.fn.gridAxisDropDown = function() {
      // deinitialize previous handlers e.g. after AJAX refresh
      $(document).off("click", this.selector);

      this.each(function(i, element) {
        var self = $(element);

        var propertyIds = {};
        $.each(["lane", "row"], function(i, axis) {
          if ("undefined" !== typeof self.attr("data-" + axis + "-property-id")) {
            propertyIds[axis] = self.data(axis + "-property-id");
          }
        });

        var pdd = new PropertyDropDown(self, {
          beforeShow: function(content) {
            if (content.find(".choices").length) {
              content.attr("grid-axis", "");
            }

            // set a datasource when only one dimension is shown
            // when there are 2 dimensions, this will be dynamically set
            if (this.element.attr("data-lane-values")) {
              this.options.dataAttr = "lane-values";
            } else {
              this.options.dataAttr = "row-values";
            }
          },

          doCreate: function(value) {
            if ("" !== value) {
              var dimension = this.options.dataAttr.split("-")[0];
              this.close();
              this.requester.add(dimension, value);
            }
          },

          doSelect: function(e, ui) {
            var dimension = this.options.dataAttr.split("-")[0];
            this.close();
            this.requester.add(dimension, ui.item.value);
          }
        });

        pdd.requester = new DimensionAdder(self, self.data("url"), propertyIds);

        self.on("click", ".choices a", function(e) {
          e.preventDefault();
          var dimension = $(this).attr("dimension");
          pdd.options.dataAttr = dimension + "-values";
          pdd.element.find("[grid-axis]").attr("grid-axis", dimension);
          pdd.refresh();
        });

        element.pdd = pdd;
      });

      return this;
    };

    $.fn.editableLanes = function(spinnerHtml) {

        var submitting = false;

        var lanes = $(this);
        return lanes.each(function() {
            var self = $(this);
            //destroy old editable, to make sure there is only one
            //editable attached at any point of time
            self.editable('destroy');

            var header = self.parents('th');
            var spinner = $(spinnerHtml);

            function setup(settings) {
                if (submitting === true) {
                    return false;
                }
                submitting = true;
                self.find("input").prop('readonly', true);
                window.docLinkHandler.disableLinks();
                var freshEditUrl = self.parents('th').find('a.edit-lane-url-link').attr('href');
                settings.target = freshEditUrl;

                header.append(spinner);
                spinner.show();
                return true;
            }

            function cleanUp() {
                header.removeClass('expanded');
                self.removeClass("editing");
                spinner.hide();
                $j(document).trigger("mingle:relayout");
                self.find("input").prop('readonly', false);
                $('#swimming-pool').toggleClass('lane-editing-in-progress');
                window.docLinkHandler.enableLinks();
                submitting = false;
                return true;
            }

            function onReset() {
                if (submitting === true) {
                  return false;
                }
                return cleanUp();
            }

            self.editable('', {
                method: 'POST',
                width: 130,
                height: 20,
                name: 'new_lane_name',
                ajaxoptions: {
                    dataType: 'script',
                    complete: cleanUp
                },
                data: function() {
                    return $(this).parents('th').data('lane-value');
                },

                onsubmit: setup,
                callback: function(data) {
                    var oldVal = header.data('lane-value');
                    var newVal = $.trim($(this).find('input').val());
                    $(this).text(newVal);
                    header.data('lane-value', newVal);
                    $("td[lane_value='" + oldVal + "']").attr('lane_value', newVal);
                    self.append(self.childrenNodes);
                },

                onedit: function() {
                    if (submitting === true) {
                      return false;
                    }

                    $('#swimming-pool').toggleClass('lane-editing-in-progress');

                    if(header.outerWidth() < 200) {
                        header.addClass('expanded');
                    }
                    self.childrenNodes = self.children();
                    self.addClass("editing");
                    $j(document).trigger("mingle:relayout");
                    $(document.body).trigger('click');
                    return true;
                },

                onreset: onReset,

                onerror: function(setting, element, xhr) {
                    eval(xhr.responseText);
                    submitting = false;
                },

                submitdata: function() {
                    return { lane_to_rename: header.data('lane-value') };
                }
            });
        });
    };

    $.fn.hideLane = function(properties) {
      var lanes = $(this);
      var spinnerHtml = "<i class=\"fa fa-refresh fa-spin\"></i>";

      return lanes.each(function() {
        var lane = $(this);
        var header = lane.parents('th');
        lane.off('click');
        lane.click(function() {

          var payload = {};
          var dimension = header.is(".lane_header") ? "lane" : "row";

          payload[dimension] = {
            property_definition_id: properties[dimension],
            value: header.data('lane-value')
          };

          var spinner = $(spinnerHtml);
          header.prepend(spinner);
          lane.detach();
          window.docLinkHandler.disableLinks();

          $.ajax({
            url: lane.find('a.hide-lane-url').attr('href'),
            method: 'POST',
            dataType: 'script',
            data: payload,
            error: function(jqXHR, textStatus, errorThrown ) {
              header.prepend(lane);
              eval(jqXHR.responseText);
            },
            complete: function() {
              spinner.remove();
              window.docLinkHandler.enableLinks();
            }
          });
        });
      });
    };

    $.fn.reorderableLanes = function(reorderUrl, spinnerHtml) {
        var draggables = '.draggable_lane';
        var spinner = $(spinnerHtml);

        function equalOrder(order1, order2) {
            return JSON.stringify(order1) === JSON.stringify(order2);
        }

        function setupSorttable(el) {
          function collectOrder(originalTable) {
            var order = {};
            originalTable.find('th' + draggables).each(function(i) {
                if (this.id !== '') {
                    order[$(this).data('lane-value')] = i;
                }
            });
            return order;
          }

          // Sorttable creates a placeholder only within the thead section which is the size of the table does not fill the tbody section.
          // So we create an empty cell with the row-span of size of table body rows and fill all the columns of the table body.
          var addEmptyBodyCells = function(event, ui) {
            var table = ui.placeholder.parents('table');
            var tableHeader = table.find('thead');
            var tableBody = table.find('tbody');
            if (!ui.item.bodyPlaceholder) {
              ui.item.bodyPlaceholder = $("<td/>", {
                rowSpan: parseInt(ui.placeholder.attr('rowSpan')) - 1, // thead takes one row
                css: { height: ui.helper.height() - tableHeader.height()} // original table body height
              });
            } else {
              ui.item.bodyPlaceholder.detach();
            }
            var placeholderIndex = ui.placeholder.siblings(".draggable_lane:visible").addBack().index(ui.placeholder);
            var firstBodyRow = $(tableBody).find('tr:eq(0)');
            $(ui.item.bodyPlaceholder).insertBefore(firstBodyRow.find('td:visible:eq(' + placeholderIndex + ')'));
          };

          return el.sorttable({
            placeholder: 'column-placeholder',
            helperCells: null,
            items: '.draggable_lane',
            containment: '#swimming-pool',
            forcePlaceholderSize: true,
            forceHelperSize: true,
            tolerance: "pointer",
            cancel: '.lane-editing-in-progress th.draggable_lane',
            fixHeaderWidth: false,
            axis: 'x',
            start: function(e, ui) {
              if ($(ui.item.closest('thead.fixed')).length) {
                // scroll up to the table if headers are fixed when user has scrolled down on the page
                $('html, body').animate({
                  scrollTop: $(ui.item.closest('table')).offset().top
                }, 500);
              }
              ui.helper.addClass('dragged-column');
              var table = $j(ui.item).parents('table');
              $(document.body).trigger("click");  // trigger blur for all home grown components
              $(table).data("old_order", collectOrder(table));
              addEmptyBodyCells(e, ui);
            },
            change: addEmptyBodyCells,
            stop: function(e, ui) {
              var table = $j(ui.item).parents('table');
              var newOrder = collectOrder(table);
              if (equalOrder(newOrder, $(table).data("old_order"))) {
                  return;
              }

              $j(ui.item).append(spinner);
              spinner.show();
              window.docLinkHandler.disableLinks();

              $.ajax({
                url: reorderUrl,
                method: 'post',
                data: { new_order: newOrder },
                async: true,
                complete: function() {
                    spinner.hide();
                    window.docLinkHandler.enableLinks();
                }
              });
            },
            beforeStop: function(e, ui) {
              if (ui.item.bodyPlaceholder) {
                ui.item.bodyPlaceholder.remove();
              }
            }
          }).disableSelection();
        }

        var el = setupSorttable($(this));
        return el;
    };

    function DimensionAdder(element, url, propertyIds) {
      var spinnerHtml = "<i class=\"fa fa-refresh fa-spin\"></i>";

      function add(dimension, name) {
        element.replaceWith(spinnerHtml);

        var payload = {};
        payload[dimension] = {
          property_definition_id: propertyIds[dimension],
          value: name
        };

        window.docLinkHandler.disableLinks();
        $.ajax({
          url: url,
          method: "POST",
          dataType: "script",
          data: payload,
          error: function(jqXHR, textStatus, errorThrown ) {
            eval(jqXHR.responseText);
          },
          complete: function() {
            window.docLinkHandler.enableLinks();
          }
        });
      }

      this.add = add;
    }
}(jQuery));
