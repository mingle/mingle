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
  <div :class="containerClass" v-click-outside="onClickOutside">
    <div>
      <button :disabled="disabled" @click="toggleDropDownOptions" class="drop-down-toggle selected-tag" :style="{'max-width':options.maxWidth}" v-if="options.buttonTypeDropdown">
        {{selectedValue}}
        <span class="fa fa-angle-up" v-if="openDropDownOptions"></span>
        <span class="fa fa-angle-down" v-else></span>
      </button>
      <div :disabled="disabled" @click="toggleDropDownOptions" class="drop-down-toggle selected-tag" :style="{'max-width':options.maxWidth}" v-else>
        {{selectedValue}}
        <span class="fa fa-angle-up" v-if="openDropDownOptions"></span>
        <span class="fa fa-angle-down" v-else></span>
      </div>
    </div>
    <ul class="drop-down-options" v-if="openDropDownOptions" :style="{width:options.maxWidth,'max-height':options.maxHeight}">
      <li class="drop-down-option" v-for="selectOption in selectOptions"
          :class="{selected: isSelected(selectOption)}"
          @click="optionSelected(selectOption)"
          @mouseover="highlightSelected = false">
        {{getOptionLabel(selectOption)}}
      </li>
    </ul>
  </div>
</template>

<script>
  export default {
    name: "drop-down",
    props: {
      containerClass: {
        type: String,
        default: 'simple-drop-down'
      },
      selected: {
        type: Array,
        default() {
          return [];
        }
      },
      selectOptions: {
        type: Array,
        default() {
          return [];
        }
      },
      label: {
        type: String,
        default: 'label'
      },
      value: {
        type: String,
        default: 'value'
      },
      disabled: {
        type: Boolean,
        default: false
      },
      placeHolder: {
        type: String,
        default: 'Select'
      },
      displaySelectedValue:{
        type:Boolean,
        default:true
      },
      options:{
        default(){
          return {
            maxWidth:'200px',
            maxHeight:'200px',
            buttonTypeDropdown:false
          }
        }
      },
      onChange:{
        type:Function,
        default(payload){
          this.$emit('drop-down-option-changed', payload);
        }
      }
    },
    data() {
      return {
        openDropDownOptions: false,
        highlightSelected:true
      }
    },
    methods: {
      toggleDropDownOptions() {
        this.openDropDownOptions = !this.openDropDownOptions
      },
      onClickOutside() {
        this.openDropDownOptions = false;
        this.highlightSelected = true;
      },
      isSelected(selectOption){
        return this.highlightSelected && this.selected[0] && this.getOptionLabel(this.selected[0]) === this.getOptionLabel(selectOption);
      },
      hasOptionChanged(selectedOption) {
        if(this.selected.length < 1) return true;
        return this.getOptionLabel(this.selected[0]) !== this.getOptionLabel(selectedOption) && this.getOptionValue(this.selected[0]) !== this.getOptionValue(selectedOption);
      },
      optionSelected(selectedOption){
        if(this.hasOptionChanged(selectedOption))
          this.onChange(selectedOption);
        this.openDropDownOptions = false;
        this.highlightSelected = true;
      },
      getOptionLabel(option){
        if(option.constructor === Object)
          return option[this.label];
        return option;
      },
      getOptionValue(option){
        if(option.constructor === Object)
          return option[this.value];
        return option;
      }
    },
    computed: {
      selectedValue() {
        if(this.displaySelectedValue && this.selected.length)
          return this.getOptionLabel(this.selected[0]);
        return this.placeHolder
      }
    }
  }
</script>

<style scoped lang="scss">

   .fa-angle-down, .fa-angle-up {
    -webkit-text-stroke-width: 2px;
    -moz-text-stroke-width: 2px;
   }

    $dropdown-border-color:#cccccc;
    button.drop-down-toggle {
      font-family: Arial, Helvetica, sans-serif;
      span{
        padding-left: 5px;
        font-size: 20px;
        line-height: 0;
        top: 3px;
        position: relative;
      }
    }

    div.drop-down-toggle {
      font-family: Arial, Helvetica, sans-serif;
      color: #333;
      padding: 5px;
      border: 1px solid $dropdown-border-color;
      border-radius: 2px;
      span {
        font-size: 20px;
        line-height: 0;
        top: 6px;
        position: relative;
        float: right;
        right: 5px;
        color: rgba(60,60,60,.5);
      }
    }
    .drop-down-options {
      background: white;
      width: fit-content;
      position: absolute;
      box-shadow: 1px 2px 11px $dropdown-border-color;
      border-bottom: 1px solid $dropdown-border-color;
      border-left: 1px solid $dropdown-border-color;
      border-right: 1px solid $dropdown-border-color;
      margin: 0;
      z-index: 1000;
      overflow: scroll;
      li {
        list-style: none;
        padding: 5px 10px;
        cursor: pointer;
        &:hover {
          background: #5897fb;
        }
        &.selected{
          background: #5897fb;
        }
      }
    }
</style>