<!--
Copyright 2020 ThoughtWorks, Inc.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
-->
<template>
  <div class="edit-popup-container">
    <div class="objective-content">
      <div class="header">
        <h1>
          <span class="number"> #{{objective.number}} </span>
          <input class="name" v-model="name" maxlength=80>
        </h1>
      </div>
      <div class="objective-value-statement">
        <ckeditor
          :id="ckEditorInstanceId"
          v-model="content"
          :config="ckEditorConfig">
        </ckeditor>
      </div>
      <objective-properties v-bind:objectiveProperties="objectiveProperties" v-on:propertiesChanged="updateObjectiveProperties"></objective-properties>
    </div>
    <div class="actions">
      <tooltip-style-message-box :message="errorMessage" :config="getTooltipMessageConfig"/>
      <progress-bar v-if="displayProgressBar" :target="progressBarTarget" />
      <button class="save primary save-objective" v-if="isEditMode" @click="saveObjective">
        <span class="fa fa-save"></span>
        SAVE
      </button>
      <button class="save-and-close" v-if="isEditMode" @click="saveObjective">SAVE & CLOSE </button>
      <button class="add primary" v-if="popupMode === 'ADD'" @click="createObjective">
        <span class="fa fa-plus"></span>
        ADD
      </button>
      <button class="cancel" @click="destroyCkEditorWithEvent((!isEditMode ? 'close' : 'cancel'))">
        <span class="fa fa-times" v-if="!isEditMode"></span>
        CANCEL
      </button>
    </div>
  </div>
</template>

<script>
  import CkEditor from "vue-ckeditor2";
  import "src/wiki.scss";
  import "src/custom_ck_editor_styles.scss";
  import TooltipStyleMessageBox from "../TooltipStyleMessage";
  import ProgressBar from "../ProgressBar";
  import ObjectiveProperties from "./ObjectiveProperties";
  import MingleCkEditorConfig from "../../shared/mingle_ckeditor_config";

  export default {
    components: {
      ProgressBar,
      TooltipStyleMessageBox,
      ckeditor: CkEditor,
      ObjectiveProperties
    },
    data() {
      return {
        progressBarTarget:'.save-objective',
        objectiveProperties: this.objective.property_definitions,
        displayProgressBar: false,
        errorMessage: null,
        buttonDimensions: {
          width: 0,
          positionFromLeft: 0,
          positionFromTop: 1
        },
        messageBoxPositionFromLeft: 0,
        name: this.objective.name,
        content: this.editorContent(),
        ckEditorInstanceId: "objective_value_statement_editor",
        ckEditorConfig: MingleCkEditorConfig()
      };
    },
    props: {
      objective: {
        type: Object,
        required: true
      },
      popupResized: {
        default: false
      },
      popupMode:{
        default:'EDIT',
        type:String
      }
    },
    methods: {
      cssForCkEditor() {
        let cssAssets = [];
        let styleSheets = document.querySelectorAll('link[rel="stylesheet"]');
        for (let styleSheet of styleSheets) {
          if (styleSheet.href.match("/.*css")) {
            cssAssets.push(styleSheet.href);
          }
        }
        return cssAssets;
      },
      saveObjective(event) {
        this.progressBarTarget  = `.${event.target.className.trim().split(/\s+/).join(".")}`;
        this.displayProgressBar = true;
        let eventName = event.target.hasClassName("save-and-close") ? "Save and Close" : "Save";
        let payload = {objectiveData: {}, scopedMessage: true, eventName: eventName};
        this.content = CKEDITOR.instances[this.ckEditorInstanceId].getData();
        Object.assign(payload.objectiveData, this.objective, {
          value_statement: this.content,
          name: this.name,
          property_definitions:this.objectiveProperties
        });
        this.$store.dispatch("updateCurrentObjective", payload).then(result => {
          this.messageBoxPositionFromLeft = event.target.positionedOffset().left;
          this.displayProgressBar = false;
          if (result.success) {
            let eventName = event.target.hasClassName("save-and-close") ? "close" : "updated";
            this.destroyCkEditorWithEvent(eventName);
          }
          else if (result.errorType == 'deleted') {
            this.$emit('close');
          }
          else {
            this.errorMessage = result.message;
          }
        });
      },
      createObjective(event) {
        this.progressBarTarget  = `.${event.target.className.trim().split(/\s+/).join(".")}`;

        this.content = CKEDITOR.instances[this.ckEditorInstanceId].getData();
        let objectiveData = {
          value_statement: this.content,
          name: this.name,
          property_definitions: this.objectiveProperties,
        };
        this.displayProgressBar = true;
        this.$store.dispatch("createObjective", objectiveData).then(result => {
          this.displayProgressBar = false;
          if (result.success) {
            this.destroyCkEditorWithEvent('cancel');
          } else {
            this.messageBoxPositionFromLeft = event.target.positionedOffset().left;
            this.errorMessage = result.message;
          }
        });
      },

      destroyCkEditorWithEvent(eventName) {
        CKEDITOR.instances[this.ckEditorInstanceId].destroy();
        this.$emit(eventName);
      }
      ,
      ckeditorSize() {
        return {height: this.$el.getHeight() - 180, width: this.$el.getWidth() - 30}
      }
      ,
      resizeCkEditor() {
        CKEDITOR.instances[this.ckEditorInstanceId].resize(this.ckeditorSize().width, this.ckeditorSize().height);
      }
      ,
      editorContent() {
        return this.objective.value_statement;
      },
      updateObjectiveProperties(updatedProperties) {
        this.objectiveProperties = updatedProperties;
      }
    },
    computed: {
      getTooltipMessageConfig() {
        return {position: {left: this.messageBoxPositionFromLeft}};
      },
      isEditMode() {
        return this.popupMode === 'EDIT';
      },
      valueVsSizeRatio: function () {
        if (this.objective.size === 0)
          return 0;
        let ratio = (this.objective.value / this.objective.size);
        if (Math.round(ratio) !== ratio)
          ratio = ratio.toFixed(2);
        return ratio;
      }
    },
    mounted() {
      CKEDITOR.instances[this.ckEditorInstanceId].on('instanceReady', this.resizeCkEditor);
    },
    watch: {
      popupResized() {
        this.resizeCkEditor();
      }
    }
  };
</script>

<style lang="scss" scoped>
  .edit-popup-container {
    width: 100%;
    height: 100%;
    position: absolute;
    padding-left: 15px;
    padding-top: 15px;
    .objective-content {
      height: calc(100% - 15px);
      width: calc(100% - 15px);
      position: inherit;
      .header {
        .number {
          font-weight: bold;
          margin-right: 10px;
          color: black;
        }
        .name {
          outline: none;
          border: 1px dashed #bbb;
          font-family: "Helvetica Neue", Arial, Helvetica;
          font-size: 21px;
          font-weight: 300;
          width: 85%;
        }
      }
    }
    .actions {
      position: absolute;
      bottom: 18px;
    }
  }
</style>
