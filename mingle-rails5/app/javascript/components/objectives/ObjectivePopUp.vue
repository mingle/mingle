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
    <div class="modal-container">
        <div class="wrapper">
            <div class="container">
                <objective-edit
                        v-if="showEditMode"
                        v-bind:objective="objective"
                        v-bind:popup-mode="popupMode"
                        :popup-resized="popupResized"
                        v-on:updated="updatePopupMode('VIEW')"
                        v-on:close="closePopup"
                        v-on:cancel="updatePopupMode('VIEW')" />

                <objective-view v-else
                                        v-bind:objective="objective"
                                        v-on:edit="updatePopupMode('EDIT')"
                                        v-on:close="$emit('close')"/>
            </div>
            <strong class='close fa fa-times' v-if="isViewMode" @click="closePopup"></strong>
        </div>
        <div class="objective-type-container">
            <h2 class="objective-type-name">Objective</h2>
        </div>
    </div>
</template>

<script>
  import ObjectiveEdit from "./ObjectiveEdit";
  import ObjectiveView from "./ObjectiveView";

  export default {
    name: 'objective-popup',
    components: {
      ObjectiveView,
      ObjectiveEdit,
    },
    props: {
      popupResized: {
        default: false
      },
      name: {
        default: 'objective_popup'
      },
      mode:{
        default:'VIEW',
        type:String
      }
    },
    data(){
      return {
        popupMode: this.mode
      }
    },
    computed: {
      objective() {
        return this.$store.state.currentObjectiveData;
      },
      isViewMode(){
        return this.popupMode === 'VIEW';
      },
      showEditMode(){
        return this.popupMode != 'VIEW' && !this.$store.state.toggles.readOnlyModeEnabled;
      }
    },
    methods: {
      closePopup() {
        this.$modal.hide(this.name);
        this.updatePopupMode('VIEW');
      },
      updatePopupMode(mode){
        this.popupMode = mode;
      }
    }
  }
</script>

<style lang="scss" scoped>
    .modal-container {
        width: 100%;
        height: 100%;
        background: transparent;
        .wrapper {
            position: absolute;
            width: 100%;
            height: calc(100% - 42px);
            background: white;
            top: 42px;
            border-left: 10px solid #3fbeea;
            .close {
                width: 29px;
                height: 29px;
                background-color: #eee;
                text-align: center;
                position: absolute;
                top: 0;
                right: 0;
                line-height: 29px;
                font-size: 14px;
                cursor: pointer;
                color:black;
            }
            .container {
                width: 100%;
                height: 100%;
                position: absolute;
                top: 0px;
            }
        }
        .objective-type-container {
            padding: 11px;
            display: inline-block;
            width: auto;
            background: #3fbeea;
            .objective-type-name {
                color: black;
                margin: 0;
                padding: 0;
            }
        }
    }
</style>
<style lang="scss">
    .v--modal-overlay {
        overflow-y: auto;
        height: 96vh;
        .v--modal-box.v--modal {
            background: transparent;
            box-shadow: 0 60px 43px 0 rgba(92, 92, 92, 0.25);
            overflow: visible;
        }

    }
</style>
