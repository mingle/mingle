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
<template xmlns:v-bind="http://www.w3.org/1999/xhtml">
  <modal height="336" width="600" name="add-member-pop-up" class="add-member-pop-up" :click-to-close="false">
    <div class="add-member-container" id="add-member">
      <div class="header">
        <h2 class="add-member-heading">{{heading}}</h2>
        <strong class='close fa fa-times fa-inverse' @click="closePopUp"></strong>
      </div>
      <div class="pop-up-content">
        <div class="select-user" id="select-user">
          <i class="fa fa-search" aria-hidden="true"></i>
          <v-select id="search" v-model="selectedUser" label="name" :options="users" :searchable="true"
                    :placeholder=placeHolderForSearch></v-select>
          <div class="member-details">
            <div class="member-input-row disabled">
              <div class="name input-fields">
                Name
                <input type="text" v-model="selectedUser['name']">
              </div>
              <div class="sign-in input-fields">
                Sign-in Name
                <input type="text" v-model="selectedUser['login']">
              </div>
            </div>
            <div class="member-input-row disabled">
              <div class="email-id input-fields">
                Email Id
                <input type="text" v-model="selectedUser['email']">
              </div>
              <div class="projects input-fields" :title="projects">
                Projects
                <input type="text" v-model="projects">
              </div>
            </div>
            <div class="member-input-row role" v-bind:class="disabled">
              <div id="select-role">
                Add Role
                <v-select id="role" :disabled="!isUserSelected" v-model="selectedRole" :options="roles"
                          :searchable="false"
                          :placeholder="placeHolderForRole"/>
              </div>
            </div>
          </div>
        </div>
        <div class="action-bar">
          <button class="add primary" @click="addMember" :disabled="!isRoleSelected">
            <span class="fa fa-plus"></span>
            Add
          </button>
          <button class="cancel" @click="closePopUp">Cancel</button>
        </div>
      </div>
    </div>
  </modal>
</template>

<script>

  import vSelect from 'vue-select';

  export default {
    components: {vSelect},
    name: 'add-member-pop-up',
    props: {
      heading: {
        type: String,
        default: 'Add Team Member'
      },
      name: {
        default: 'add_member_pop_up'
      }
    },
    data: function () {
      return {
        selectedUser: "", projects: "", selectedRole: "", placeHolderForSearch: 'Search by name or email id',
        placeHolderForRole: 'Select Role'
      }
    }
    ,
    computed: {
      disabled() {
        return {disabled: (this.selectedUser === "")};
      },

      users() {
        return this.$store.state.programTeam.users
      },

      isUserSelected() {
        return this.selectedUser && this.selectedUser.name !== "";
      },

      isRoleSelected() {
        return this.selectedRole !== "" && this.selectedUser && this.selectedUser.name !== "";
      },

      roles() {
        return this.$store.state.programTeam.roles.map((role) => {
          return {label: role.name, value: role.id}
        });
      }
    },
    methods: {
      closePopUp() {
        this.$modal.hide('add-member-pop-up');
        this.resetPopupData();
      },

      resetPopupData() {
        this.selectedUser = "";
        this.selectedRole = "";
        this.projects = "";
      },

      addMember() {
        this.$store.dispatch('addMember', {
          login: this.selectedUser.login,
          role: this.selectedRole.value
        }).then((result) => {
          if (result.success) {
            this.$emit('update-message', {
              type: 'success',
              text: `${this.selectedUser.name} has been added to this program.`
            });
            this.resetPopupData();
            this.$modal.hide('add-member-pop-up');
          }
        });
      },
    },
    watch: {
      selectedUser: function (newVal, oldVal) {
        if (newVal == null) {
          this.resetPopupData();
        }
        else if (newVal !== '') {
          this.$store.dispatch('fetchProjects', this.selectedUser.login).then((result) => {
            this.projects = result.join(', ');
          });
          if (oldVal != null && oldVal !== '' && newVal.login !== oldVal.login) {
            this.selectedRole = "";
          }
        }
      }
    }
  }
</script>
<style lang="scss" scoped>
  #add-member {
    box-shadow: 5px 5px 3px rgba(0, 0, 0, 0.25);
    width: auto;
    height: inherit;
    background: white;
    .pop-up-content {
      margin-left: 20px;
      margin-top: 20px;
    }
    .header {
      position: relative;
      background-color: #3fbeea;
      .add-member-heading {
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
    .member-details {
      margin-top: 5px;

      .disabled {
        color: black;
        cursor: default;
        opacity: 1;
        input {
          background: #EEE;
          color: #777;
        }
        .dropdown.v-select {
          pointer-events: none;
          background-color: #EEE;
        }
      }

      .member-input-row {
        display: block;
        padding: 5px 0 5px 0;

        .input-fields {
          display: inline-block;
          width: 48%;

          &:first-child {
            margin-right: 10px;
          }
          input {
            pointer-events: none;
            width: 100%;
            padding-left: 5px;
            margin-top: 2px;
          }
        }
      }
    }
    .projects {
      input {
        text-overflow: ellipsis;
      }
    }
  }

  .action-bar {
    position: absolute;
    bottom: 4px;
    padding-left: 6px !important;
  }

</style>
<style lang="scss">
  .v-select .dropdown-menu {
    overflow-y: auto;
    max-height: 190px !important;
    li {
      list-style: none;
      a {
        padding-left: 6px;
      }
    }
  }

  .v-select button.clear {
    display: none;
  }

  #search.dropdown {
    &.v-select {
      width: 98%;

      .dropdown-toggle {
        border-color: #3fbeea;
        border-radius: 0;

        input {
          height: 30px;
        }

        .selected-tag {
          margin: 0;
          padding-left: 5px;
          line-height: 28px;
        }
      }
      .open-indicator:before {
        display: none;
      }
    }
  }

  #select-user {
    .fa.fa-search {
      position: absolute;
      top: 71px;
      right: 20px;
      padding-left: 5px;
    }
  }

  #select-role {
    width: 48%;

    #role.dropdown.v-select {
      .dropdown-toggle {
        border-radius: 0;
        border-color: rgb(204, 204, 204);

        .selected-tag {
          padding-left: 5px;
          margin: 0;
        }

        input {
          height: 24px;
        }

        .open-indicator {
          top: 5px;
        }
      }
      &.open {
        .open-indicator {
          top: 9px;
        }
      }

      &.disabled {
        .dropdown-toggle, .open-indicator {
          background: #EEE;
        }
      }
    }
  }
</style>
