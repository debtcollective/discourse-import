# frozen_string_literal: true

require_relative '../base.rb'
require_relative './constants.rb'
require 'json'

module DebtCollective
  class Seeds
    def perform
      create_categories
      create_user_fields
      create_groups
      create_state_groups
      create_permalinks
      create_staff_tags
    end

    def create_categories
      category = Category.find_or_initialize_by(name: 'General')
      category.assign_attributes(
        name: 'General',
        color: '0088CC',
        text_color: 'FFFFFF',
        user: Discourse.system_user
      )
      category.save
    end

    def create_groups
      puts('Creating Groups')

      create_or_update_group(name: 'team', full_name: 'Team', mentionable_level: Group::ALIAS_LEVELS[:everyone])
      create_or_update_group(name: DISPUTE_TOOLS_GROUP[:name], full_name: DISPUTE_TOOLS_GROUP[:full_name])
      create_or_update_group(name: DISPUTE_COORDINATOR_GROUP[:name], full_name: DISPUTE_COORDINATOR_GROUP[:full_name])
    end

    def create_state_groups
      puts('Creating State Groups')

      USA_STATES.each do |state|
        group_name = state.split.map(&:camelize).join
        group_full_name = "#{state} members"

        create_or_update_group(name: group_name, full_name: group_full_name)
      end
    end

    def create_permalinks
      donate_permalink = Permalink.find_by_url("donate")

      if !donate_permalink
        Permalink.create(url: "donate", external_url: "https://membership.debtcollective.org/")
      end

    end

    def create_user_fields
      puts ('Creating User Fields')

      fields = [{
        name: "State",
        description: "State",
        field_type: "state",
        required: false,
        editable: false,
        show_on_profile: false,
        show_on_user_card: false,
      }, {
        name: "Zip Code",
        description: "Zip Code",
        field_type: "zip-code",
        required: false,
        editable: false,
        show_on_profile: false,
        show_on_user_card: false,
      }, {
        name: "Phone Number",
        description: "Phone Number",
        field_type: "phone-number",
        required: false,
        editable: false,
        show_on_profile: false,
        show_on_user_card: false,
      }, {
        name: "City",
        description: "City",
        field_type: "text",
        required: false,
        editable: false,
        show_on_profile: false,
        show_on_user_card: false,
      }]

      fields.each_with_index do |field, index|
        name = field[:name]
        field[:position] = index + 1

        user_field = UserField.find_or_initialize_by(name: name)
        user_field.assign_attributes(field)
        user_field.save
      end
    end

    def create_staff_tags
      tag = Tag.find_or_create_by(name: 'current-efforts')
      tag_group = TagGroup.find_or_create_by(name: 'staff tags')

      # this set the tag to be usable by staff only but visible to everyone
      tag_group.update(one_per_topic: false, tag_names: [tag.name], permissions: { staff: 1, everyone: 3 })
    end

    private

    def create_or_update_group(options = {})
      defaults = {
        mentionable_level: Group::ALIAS_LEVELS[:mods_and_admins],
        messageable_level: Group::ALIAS_LEVELS[:mods_and_admins],
        visibility_level: Group.visibility_levels[:members],
        primary_group: true,
        public_admission: false,
        allow_membership_requests: false,
        default_notification_level: NotificationLevels.all[:regular]
      }

      options = defaults.merge(options)
      name = options[:name]

      group = Group.find_or_initialize_by(name: name)
      group.assign_attributes(options)
      group.save
    end
  end
end

DebtCollective::Seeds.new.perform if $PROGRAM_NAME == __FILE__
