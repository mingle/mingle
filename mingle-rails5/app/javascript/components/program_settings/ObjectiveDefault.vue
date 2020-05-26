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
  <div class="edit-defaults">
    <div class="editable-content">
      <h1>Configure Objective</h1>
      <h1 class="objective-type-name">
        {{ currentObjectiveType.name }}
      </h1>
      <div class="default-value-statement">
        <ckeditor
                :id="ckEditorInstanceId"
                v-model="currentObjectiveType.value_statement"
                :config="ckEditorConfig">
        </ckeditor>
        <div class="objective-type-properties">
          <property-tile v-for="property in currentObjectiveType.property_definitions"
                         :property = property>

          </property-tile>
          <div class="add-property">
            <span class="fa fa-plus"></span>
            Add Property
          </div>
        </div>

      </div>

    </div>
    <div class="actions">
      <progress-bar v-if="displayProgressBar" :target="progressBarTarget" />
      <button class="save primary" :disabled="!enableSave" @click="updateObjectiveType">
        <span class="fa fa-save"></span>
        SAVE ALL CHANGES</button>
      <button class="cancel" @click="resetObjectiveType">
        <span class="fa fa-times"></span>
        CANCEL</button>
    </div>
  </div>
</template>

<script>
  import CkEditor from "vue-ckeditor2";
  import MingleCkEditorConfig from "../../shared/mingle_ckeditor_config";
  import PropertyTile from "./PropertyTile";
  import ProgressBar from "../ProgressBar";


  export default {
    components: {ckeditor: CkEditor,PropertyTile, ProgressBar},
    data: function() {
      return {
        progressBarTarget:'.save.primary',
        displayProgressBar: false,
        ckEditorInstanceId: "default_value_statement_editor",
        ckEditorConfig:  MingleCkEditorConfig({width: '100%'}),
        currentObjectiveType: Object.assign({}, this.objectiveType),
        isSourceMode: false,
        ckEditorInstance: null
      };
    },
    props: {
      objectiveType: {
        type: Object,
        required: true
      }
    },

    computed: {
      enableSave() {
        return (this.currentObjectiveType.value_statement !== this.objectiveType.value_statement) && !this.isSourceMode;
      }
    },

    methods: {
      resetObjectiveType() {
        this.currentObjectiveType = Object.assign({}, this.objectiveType);
        this.ckEditorInstance.setData(this.objectiveType.value_statement);
        this.$emit('updateMessage', {});
      },

      updateObjectiveType() {
        this.displayProgressBar = true;
        this.currentObjectiveType.value_statement = this.ckEditorInstance.getData();
        this.$store.dispatch("updateObjectiveType", this.currentObjectiveType).then(result => {
          this.displayProgressBar = false;
          if (result.success) {
            this.$emit('updateMessage', {type: 'success', text: 'Changes have been updated successfully.'});
          } else {
            this.$emit('updateMessage', {type: 'error', text: result.error})
          }
        });
      },

      modeChanged() {
        this.isSourceMode = this.ckEditorInstance.mode !== 'wysiwyg' ;
      }
    },
    mounted() {
      this.ckEditorInstance = CKEDITOR.instances[this.ckEditorInstanceId];
      this.ckEditorInstance.on('mode', this.modeChanged);
    },
  }

</script>
<style lang="scss" scoped>
  .edit-defaults {
    max-width: 75%;
    .editable-content {
      -moz-box-shadow: 0 5px 5px rgba(0, 0, 0, 0.25);
      -webkit-box-shadow: 0 5px 5px rgba(0, 0, 0, 0.25);
      border: 1px solid #CCC;
      padding: 10px;
    }
    h1 {
      margin-top: 0px;
    }
    h1.objective-type-name {
      color: black;
      border: none;
      padding: 5px;
      background-color: #f3f3f3;
      width:fit-content;
      line-height: 24px;
    }
    .actions {
      margin-top: 15px;
    }
    .objective-type-properties{
      padding: 20px 10px 10px 10px;
      margin-top: 10px;
      height: 100%;
      background-color: #f3f3f3;
      .add-property {
        border: 1px dashed #ccc;
        padding: 5px;
        display: inline-block;
        color: #aaa;
        width: 133px;
        margin-bottom: 10px;
        .fa-plus {
          padding-left: 8px;
        }
      }
    }
  }
</style>