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
    <div v-bind:class="classObject.messageBox">
      <span v-bind:class="classObject.icon"></span>
      {{messageText}}
    </div>
</template>

<script>
  export default {
    props:{
      message:{
        default: null
      }
    },
    computed: {
      classObject() {
        let message = this.message || this.$store.state.message;
        let hasMessage = message && message.text && message.text !== '';
        let isSuccess = message && message.type === "success";
        let isError = message && message.type === "error";
        return { icon: {
          'icon fa fa-inverse': hasMessage,
          'fa-check-circle': isSuccess,
          'fa-exclamation-circle': isError
        }, messageBox: {
          'message-box': hasMessage,
          'error': isError,
          'success': isSuccess
        }
      }},
      messageText() {
        let message = this.message || this.$store.state.message;
        return message && message.text;
      }
    }
  }
</script>
<style lang="scss" scoped>
  .message-box {
      width: auto;
    padding: 10px 10px 10px 20px;
    margin-bottom: 10px;
    color: #333;
    border: 1px solid rgba(0, 0, 0, 0.1);

    &.error {
    background-color: #ECCACA;
    }

    &.success {
      background-color: #E5EEDE;
    }
  }

  .fa-check-circle {
    color: green;
  }
  .fa-exclamation-circle {
    color: red;
  }

</style>
