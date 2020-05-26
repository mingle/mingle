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
var BacklogObjectives = {

  createObjective: function(form) {
    $j.ajax({
      type: 'post',
      data: form.serialize(),
      url: form.attr('action'),
      success: function(response) {
          $j('#backlog_objectives_list').removeClass('hide');
          $j('#flash').empty();
          $j('#backlog_objective_input_box').val("");
          $j('ul.objectives').prepend(response);
          editor = $j('ul.objectives li').first().find('.editor');
          BacklogObjectiveEditor.closeAll();
          BacklogObjectiveEditor.initialize(editor);
          BacklogObjectiveEditor.showDetails(editor);
        },
      error: function(response, textStatus, error) {
        BacklogObjectiveEditor.closeAll();
        $j('#flash').replaceWith(response.responseText);
       }
    });
  },

  initializeAllObjectiveContentEditors: function() {
    $j('.editor').each(function(idx, editor) {
      BacklogObjectiveEditor.initialize($j(editor));
    });

    $j(document).click(function(e) {
      if (BacklogObjectives.clickedOutsideObjectiveContent(e.target) && !BacklogObjectives.clickedOnLightbox(e.target)) {
        BacklogObjectiveEditor.closeAll();
      }
    });
  },

  clickedOutsideObjectiveContent: function(elementClickedOn) {
    return $j(elementClickedOn).closest('.objective-box').size() == 0;
  },

  clickedOnLightbox: function(elementClickedOn) {
    return $j(elementClickedOn).closest('.overlay').size() > 0 || $j(elementClickedOn).closest('#lightbox').size() > 0;
  }
};

var BacklogObjectiveEditor = {

  initialize: function(editor){
    editor.parent().find(".name-container").click(BacklogObjectiveEditor._toggleEditor);
    BacklogObjectiveEditor._storeSavedValues(editor);
  },

  closeAll: function() {
    $j('.editor').each(function(index, editor) {
      editor = $j(editor);
      if (editor.is(':visible')) {
        BacklogObjectiveEditor.save(editor);
      }
    });
  },

  save: function(editor, callback) {
    form = editor.closest('form');
    BacklogObjectiveEditor._disableEditMode(editor);

    var nameElement = form.find('.name');
    $j(nameElement).data('savedValue', nameElement.text());

    nameElement.text(form.find('.name_input').val());
    editor.find('.objective_error').empty();
    $j.ajax({
      type: 'put',
      data: form.serialize(),
      url: form.attr('action'),
      success: function(response) {
                BacklogObjectiveEditor._storeSavedValues(editor);
                editor.parent().find('.name_input').removeClass('error');
                if(callback) {
                  callback();
                }
              },
      error: function(response) {
        nameElement.text($j(nameElement).data('savedValue'));
        BacklogObjectiveEditor.showDetails(editor);
        editor.find('.objective_error').append(response.responseText);
        editor.parent().find('.name_input').addClass('error');
      }
    });
  },

  plan: function(form) {
    editor = form.parent().find('.editor');
    BacklogObjectiveEditor.save($j(editor), function(){ form.submit(); });
  },

  cancelEditing: function(editor) {
    editor.parent().find('.name_input').removeClass('error');
    editor.find('.objective_error').empty();
    BacklogObjectiveEditor._resetToSavedValues(editor);
    BacklogObjectiveEditor._disableEditMode(editor);
  },

  showDetails: function(source) {
    var objective_summary = source.siblings('.objective_summary');
    objective_summary.find('.name_input').show();
    objective_summary.find('.name').hide();
    source.slideDown(BacklogObjectiveSort._disableSorting);
  },

  _toggleEditor: function (e) {
    var source = $j(e.target).closest('.objective-box').find(".editor");
    if (source.is(':visible')) {
      if(!$j(e.target).hasClass('handle') && !$j(e.target).hasClass('name_input')) {
        BacklogObjectiveEditor.save(source);
      }
    } else {
      if(!$j(e.target).hasClass('handle')) {
        BacklogObjectiveEditor.closeAll();
        BacklogObjectiveEditor.showDetails(source);
      }
    }
  },

  _storeSavedValues: function(editors) {
    editors.parent().find('.name_input, textarea').each(function(i, input) {
      $j(input).data('savedValue', input.value);
    });
  },

  _resetToSavedValues: function(editor) {
    editor.parent().find('.name_input, textarea').each(function(i, input) {
      input.value = $j(input).data('savedValue');
    });
  },

  _disableEditMode: function(source) {
    source.slideUp(BacklogObjectiveSort._enableSorting);
    var objective_summary = source.siblings('.objective_summary');
    objective_summary.find('.name_input').hide();
    objective_summary.find('.name').show();
  }
};

var BacklogObjectiveSort = {
  reorder_ready: function(reorder_url) {
    $j(function () {
      objectives = '.objectives';
      $j(objectives).sortable({
        handle: '.handle',
        cursor: 'move',
        scroll: true,
        revert: 200,
        containment: objectives,
        tolerance: 'pointer',
        update: function () {
          $j.ajax({
            type: 'put',
            data: $j(objectives).sortable('serialize'),
            dataType: 'script',
            complete: function (request) {},
            url: reorder_url
          });
        }
      });
    });
  },

  _disableSorting: function() {
    $j('.objectives').addClass("disabled_sorting").sortable({disabled: true});
  },

  _enableSorting: function() {
    if($j('.editor').filter(':visible').size() == 0) {
      $j('.objectives').removeClass("disabled_sorting").sortable({disabled: false});
    }
  }
};


var BacklogObjectiveRatio = {

  initialize_ratio: function(progress_bar, form) {
    var widget = progress_bar.progressbar({
      value: BacklogObjectiveRatio._ratioFromForm(form),
      max: 10
    });

    var handler = function() {
      var ratio = BacklogObjectiveRatio._ratioFromForm(form);
      widget.progressbar("value", ratio);
    };

    BacklogObjectiveHelper._hiddenField(form, 'size').change(handler);
    BacklogObjectiveHelper._hiddenField(form, 'value').change(handler);
  },

  _ratioFromForm: function(form) {
    var value = parseInt(BacklogObjectiveHelper._hiddenField(form, 'value').attr('value'), 10);
    var size = parseInt(BacklogObjectiveHelper._hiddenField(form, 'size').attr('value'), 10);
    return BacklogObjectiveRatio._calculateRatio(value, size);
  },

  _calculateRatio: function(value, size) {
    if (0 === size) {
      return 0;
    }
    return value / size;
  }
};

var BacklogObjectiveSlider = {
  initialize_slider:  function(slider_element, update_url, initial_size, attribute) {
    $j(function () {
      var form = $j(slider_element).closest('form');

      slider_element.slider({
          range: "min",
          value: initial_size,
          min: 0,
          max: 100,
          step: 10,
          slide: function(event, ui) {
            BacklogObjectiveHelper._hiddenField(form, attribute).attr('value', ui.value).trigger("change");
          },
          stop: function (event, ui) {
            $j.ajax({
              type: 'put',
              dataType: 'script',
              data: form.serialize(),
              url: update_url
            });
          }
      });
   });
  }
};

var BacklogObjectiveHelper = {
  _hiddenField: function(form, attribute) {
    return form.find('input[name="objective['+ attribute +']"]');
  }
};