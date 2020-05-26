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
    <div class="property-pop-up-container">
      <div class="header">
        <h2 class="heading">{{heading}}</h2>
        <strong class='close fa fa-times fa-inverse' @click="closePopUp"></strong>
      </div>
      <div class="property-info">
        <div id="name">
          <span class="label">Name</span>
          <input type="text" maxlength="40" name="name" v-model="property.name">
        </div>
       <div id="desc">
         <span class="label">
          Description
        </span>
         <textarea rows="5" maxlength="300" v-model="property.description"></textarea>
       </div>
        <div id="type" v-if="isCreateMode">
          <div class="label">Type</div>
          <input type="radio" name="type" id="any-text" value="AnyText" v-model="property.type"> Any Text <br>
          <input type="radio" name="type" id="managed-text" value="ManagedText" v-model="property.type"> Managed Text <br>
          <input type="radio" name="type" id="any-number" value="AnyNumber" v-model="property.type"> Any Number <br>
          <input type="radio" name="type" id="managed-number" value="ManagedNumber" v-model="property.type"> Managed Number <br>
          <input type="radio" name="type" id="date" value="DateType" v-model="property.type"> Date <br>
          <input type="radio" name="type" id="team-member" value="TeamMember" v-model="property.type"> Team Member <br>
        </div>
        <div id="type-info" v-else>
          <div class="label">Type</div>
          <span id="type-name">{{property.type}}</span></div>
      </div>
      <div class="actions">
        <div class="action-bar">
          <tooltip-style-message-box :message="errorMessage" :config="getTooltipMessageConfig"/>
          <button class="create primary" @click="createProperty" :disabled="disabled" v-if="isCreateMode">
            <span class="fa fa-plus"></span>
            Create</button>
          <button class="save" :disabled="disabled" v-else>
            <span class="fa fa-save"></span>
            Save</button>
          <button class="cancel" @click="closePopUp">Cancel</button>
        </div>
      </div>
    </div>
</template>

<script>
  import TooltipStyleMessageBox from "../TooltipStyleMessage";
  import { EventBus } from "../../shared/event_bus"

  export default {
    components: {TooltipStyleMessageBox},
    name: "CreatePropertyPopUp",
    props: {
      heading: {
        type: String,
        default: 'Create New Property'
      },
      mode: {
        type: String,
        required: true
      },
      currentPropertyData: {
        type: Object,
        default: () => ({name: "", description: "",type:""})
      }
    },
    data: function () {
      return {
        property: this.currentPropertyData,
        errorMessage: null,
        messageBoxPositionFromLeft: 0
      }
    },

    computed: {
      disabled() {
        return !(this.property.name.trim() !== "" && this.property.type !== "");
      },
      getTooltipMessageConfig() {
        return {position: {left: this.messageBoxPositionFromLeft, bottom: 60}};
      },
      isCreateMode() {
        return this.mode === 'CREATE';
      }
    },
    methods: {
      createProperty(event) {
        this.messageBoxPositionFromLeft = event.target.positionedOffset().left;
        if(this.isValidName(this.property.name)) {
          this.property.name = this.property.name.trim();
          this.$store.dispatch('createProperty', this.property).then((result)=>{
            if (result.success) {
              EventBus.$emit('updateMessage', {type: 'success', text: `${this.property.name} property has been created successfully.`});
              this.closePopUp();
            } else {
              this.errorMessage = result.message;
            }
          });
        }
        else {
          this.errorMessage = {text: "Name can't contain '&', '=', '#', '\"', '\;', '[' or ']' characters.", type: 'error'}
        }
      },

      closePopUp() {
        this.$emit('close');
        this.resetPopUpData();
      },

      resetPopUpData() {
        this.property = {name: "", description: "",type:""};
        this.errorMessage = null;
      },

      isValidName(propertyName) {
        var regex = new RegExp (/[&=#;\"\[\]]/);
        return !regex.test(propertyName);
      }
    }
  }
</script>

<style lang="scss" scoped>

  .property-pop-up-container {
    box-shadow: 5px 5px 3px rgba(0, 0, 0, 0.25);
    background: white;
    height: 100%;
    .header {
      position: relative;
      background-color: #3fbeea;
      margin-bottom: 20px;

      h2.heading {
        color: white;
        margin: 0 0 0 20px;
        font-weight: 300;
        padding-top: 10px;
      }
      .close {
        font-size: 14px;
        position: absolute;
        right: 10px;
        top: 12px;
        overflow: hidden;
        cursor: pointer;
      }
    }
    .property-info {
      margin-bottom: 10px;
      margin-left: 20px;
      color: #444;

      #name .label, #type .label {
        &:after {
          content: ' \002A';
          color: red;
        }
      }
      .label {
        width: 65px;
        display: inline-block;
        font-weight: 700;
      }
      #name {
        margin-bottom: 10px;
        input {
          width: 300px;
          margin-left: 10px;
          font-weight: 300;
        }
      }
      #desc{
        margin-bottom: 10px;
        .label {
          vertical-align: top;
        }
      }
      #type {
        .label {
          display: block;
          margin-bottom: 10px;
        }
      }
      #type-name {
        margin-left: 10px;
        color: #999;
      }
      textarea{
        width: 300px;
        margin-left: 10px;
      }
    }
    .action-bar {
      margin-left: 10px !important;
    }
  }
</style>