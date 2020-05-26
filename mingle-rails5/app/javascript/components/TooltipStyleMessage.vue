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
    <div class="tooltip-style-message" :class="arrowStyle" v-if="messageObj && display"
         :style="{left: `${getPosition.left}px`, bottom: `${getPosition.bottom}px`}">
        <i class="close-button fa fa-times" @click="$emit('close')" v-if="close"></i>
        <message-box :message="messageObj"/>
        <slot name="actions"/>
    </div>
</template>
<script>
  import MessageBox from "./MessageBox";

  export default {
    components: {MessageBox},
    name: "tooltip-style-message",
    props: {
      message: {
        default: null,
        type:Object,
      },
      config: {
        default(){
          return {position:null};
        }
      },
      arrowStyle:{
        type:String,
        default(){
          return 'bottom-arrow'
        }
      },
      close:{
        type:Boolean,
        default:false
      }
    },
    data() {
      return {
        display: true,
        localConfig: {
          selfDestroyable: true,
          activeTime: 2000,
          position: {left: 0, bottom: 35}
        }
      }
    },
    computed: {
      messageObj() {
        return this.message;
      },
      getPosition() {
        return {
          left: (this.config.position.left || this.localConfig.position.left),
          bottom: (this.config.position.bottom || this.localConfig.position.bottom)
        }
      }
    },
    watch: {
      messageObj() {
        if (this.config.hasOwnProperty('selfDestroyable') && !this.config.selfDestroyable ) return;
        if (this.message.text && !this.display)
          this.display = true;
        setTimeout(() => {
          this.display = false;
        }, (this.config.activeTime || this.localConfig.activeTime));
      }
    }
  }
</script>

<style lang="scss" scoped>
    .tooltip-style-message {
        position: absolute;
        padding: 10px;
        background-color: #ffffff !important;
        z-index: 10000;
        box-shadow: 2px 3px 10px 0 #afacac;
        border: 1px solid #c3c3c3;
        text-transform: none;
        .message-box {
            background-color: transparent !important;
            border:none !important;
            &.error {
                margin: 0;
                padding: 5px;
                width: max-content;
            }
        }
        &.bottom-arrow:after {
            position: absolute;
            width: 0;
            height: 0;
            content: "";
            border-left: 10px solid transparent;
            border-right: 10px solid transparent;
            border-top: 10px solid #ffffff;
            bottom: -10px;
            left: 20px;
        }
        &.bottom-arrow:before {
            position: absolute;
            width: 0;
            height: 0;
            content: "";
            border-left: 11px solid transparent;
            border-right: 11px solid transparent;
            border-top: 11px solid #c3c3c3;
            bottom: -11px;
            left: 19px;
        }

        &.left-center-arrow:after {
            position: absolute;
            width: 0;
            height: 0;
            content: "";
            border-bottom: 11px solid transparent;
            border-right: 11px solid #ffffff;
            border-top: 11px solid transparent;
            top: 35%;
            left: -11px;
        }
        &.left-center-arrow:before {
            position: absolute;
            width: 0;
            height: 0;
            content: "";
            border-bottom: 11px solid transparent;
            border-right: 11px solid #c3c3c3;
            border-top: 11px solid transparent;
            top: 35%;
            left: -12px;
        }
        .close-button{
            position: absolute;
            right: 4px;
            top: 2px;
            cursor: pointer;
            font-size: 14px;
        }
    }
</style>