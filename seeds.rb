# frozen_string_literal: true

require_relative '../base.rb'
require_relative './constants.rb'
require 'json'

module DebtCollective
  class Seeds
    def perform
      create_categories
      create_collectives
      create_user_fields
      create_groups
      create_state_groups
      import_wizards
      create_permalinks
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

    def create_collectives
      collectives.each do |collective|
        puts("Creating #{collective[:category][:name]}")

        # collectives are created as categories
        # this method adds:
        # - category with custom fields
        # - group for collective members (used for persmissions)

        # create categories
        category = Category.find_or_initialize_by(name: collective[:category][:name])
        category.assign_attributes(
          name: collective[:category][:name],
          color: 'FF4630',
          text_color: '2B2B2B',
          user: Discourse.system_user
        )
        category.save

        # create group for the collective
        group = Group.find_or_initialize_by(name: collective[:group][:name])
        group.assign_attributes(
          name: collective[:group][:name],
          full_name: collective[:group][:full_name],
          mentionable_level: Group::ALIAS_LEVELS[:mods_and_admins],
          messageable_level: Group::ALIAS_LEVELS[:mods_and_admins],
          visibility_level: Group.visibility_levels[:members],
          primary_group: true,
          public_admission: false,
          allow_membership_requests: false,
          default_notification_level: NotificationLevels.all[:regular]
        )
        group.save

        # update category topic content
        topic = category.topic
        topic.title = collective[:topic][:title]
        topic.save

        post = topic.first_post
        post.raw = collective[:post][:raw]
        post.save

        # set category permissions
        # everyone can see this category by only members of the group and staff can post/comment
        category.permissions = { :everyone => :read, :staff => :full, group.id => :full }

        # custom fields
        category.custom_fields = { "tdc_is_collective": true }

        category.save
      end
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

    def import_wizards
      puts('Importing wizards')

      json = File.read(File.join(__dir__, 'data/wizards.json'))
      obj = JSON.parse(json)

      # code taken from
      # https://github.com/paviliondev/discourse-custom-wizard/blob/5f07814f0ec62c898e789ddce68b0653fe73b56b/controllers/custom_wizard/transfer.rb#L44-L66
      success_ids = []
      failed_ids = []

      obj.each do |o|
        if !CustomWizard::Wizard.new(o)
          failed_ids.push o['id']
          next
        end

        pluginStoreEntry = PluginStore.new 'custom_wizard'
        saved = pluginStoreEntry.set(o['id'], o) unless pluginStoreEntry.get(o['id'])
        success_ids.push o['id'] if !!saved
        failed_ids.push o['id'] if !saved
      end

      puts ("Wizards imported: #{success_ids.size} - Failures: #{failed_ids.size}")
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
        required: true,
        editable: true,
        show_on_profile: false,
        show_on_user_card: false,
      }, {
        name: "Phone Number",
        description: "In case we need to contact you about your debt disputes.",
        field_type: "phone-number",
        required: true,
        editable: true,
        show_on_profile: false,
        show_on_user_card: false,
      },
      {
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

    def collectives
      @collectives ||= [{
        group: {
          name: 'for_profit_colleges',
          full_name: 'For Profit Colleges Collective'
        },
        topic: {
          title: 'About the For Profit Colleges Collective'
        },
        post: {
          raw: %(For anyone who is in debt after attending a for-profit college.

### We are former for-profit college students who have joined with others in our situation to fight back against predatory creditors and the federal government.
We fight because it is wrong that 40 percent of people in debt use credit cards to cover basic living costs including rent, food, and utilities. It is wrong that 62 percent of personal bankruptcies in the U.S. are linked to medical debt. It is wrong that students are leaving college owing an average of $35,000, and millions are in default. It is wrong that payday lenders earn high profits from poverty. And it is wrong that local court systems target poor people, disproportionately black and brown, and load them up with debt.
We are different in many ways. Some of us are old, and some are young; we are from different parts of the country; we are diverse in race, ethnicity and religious background. A common belief unites us: everyone should have access to the goods and services they need to live without going broke or going into debt.
Debt has isolated us and made us feel alone and ashamed. We have come out of the shadows to fight back as individuals and as a collective. We are here because we are organizing to win debt relief and a better economic system for all.)
        },
        category: {
          name: 'For Profit Colleges'
        }
      }, {
        group: {
          name: 'student_debt',
          full_name: 'Student Debt Collective'
        },
        topic: {
          title: 'About the Student Debt Collective'
        },
        post: {
          raw: %(For anyone who has student loans.

  ### We are student debtors who have joined with others in our situation to fight back against predatory creditors and the federal government.
  We fight because it is wrong that 40 percent of people in debt use credit cards to cover basic living costs including rent, food, and utilities. It is wrong that 62 percent of personal bankruptcies in the U.S. are linked to medical debt. It is wrong that students are leaving college owing an average of $35,000, and millions are in default. It is wrong that payday lenders earn high profits from poverty. And it is wrong that local court systems target poor people, disproportionately black and brown, and load them up with debt.
  We are different in many ways. Some of us are old, and some are young; we are from different parts of the country; we are diverse in race, ethnicity and religious background. A common belief unites us: everyone should have access to the goods and services they need to live without going broke or going into debt.
  Debt has isolated us and made us feel alone and ashamed. We have come out of the shadows to fight back as individuals and as a collective. We are here because we are organizing to win debt relief and a better economic system for all.)
        },
        category: {
          name: 'Student Debt Collective'
        }
      }, {
        group: {
          name: 'credit_card_debt',
          full_name: 'Credit Card Debt Collective'
        },
        topic: {
          title: 'About the Credit Card Debt Collective'
        },
        post: {
          raw: %(For anyone who has credit card debt.

### We are working together to plan actions, to develop debt resistance campaigns and to launch coordinated strikes.
We fight because it is wrong that 40 percent of people in debt use credit cards to cover basic living costs including rent, food, and utilities. It is wrong that 62 percent of personal bankruptcies in the U.S. are linked to medical debt. It is wrong that students are leaving college owing an average of $35,000, and millions are in default. It is wrong that payday lenders earn high profits from poverty. And it is wrong that local court systems target poor people, disproportionately black and brown, and load them up with debt.
We are different in many ways. Some of us are old, and some are young; we are from different parts of the country; we are diverse in race, ethnicity and religious background. A common belief unites us: everyone should have access to the goods and services they need to live without going broke or going into debt.
Debt has isolated us and made us feel alone and ashamed. We have come out of the shadows to fight back as individuals and as a collective. We are here because we are organizing to win debt relief and a better economic system for all.)
        },
        category: {
          name: 'Credit Card Debt Collective'
        }
      }, {
        group: {
          name: 'housing_debt',
          full_name: 'Housing Debt Collective'
        },
        topic: {
          title: 'About the Housing Debt Collective'
        },
        post: {
          raw: %(For anyone who went into debt for a place to live.

### We are working together to plan actions, to develop debt resistance campaigns and to launch coordinated strikes.
We fight because it is wrong that 40 percent of people in debt use credit cards to cover basic living costs including rent, food, and utilities. It is wrong that 62 percent of personal bankruptcies in the U.S. are linked to medical debt. It is wrong that students are leaving college owing an average of $35,000, and millions are in default. It is wrong that payday lenders earn high profits from poverty. And it is wrong that local court systems target poor people, disproportionately black and brown, and load them up with debt.
We are different in many ways. Some of us are old, and some are young; we are from different parts of the country; we are diverse in race, ethnicity and religious background. A common belief unites us: everyone should have access to the goods and services they need to live without going broke or going into debt.
Debt has isolated us and made us feel alone and ashamed. We have come out of the shadows to fight back as individuals and as a collective. We are here because we are organizing to win debt relief and a better economic system for all.)
        },
        category: {
          name: 'Housing Debt Collective'
        }
      }, {
        group: {
          name: 'payday_loans',
          full_name: 'Payday Loans Collective'
        },
        topic: {
          title: 'About the Payday Loans Collective'
        },
        post: {
          raw: %(For anybody in debt to a payday lender or check casher.

    ### We are working together to plan actions, to develop debt resistance campaigns and to launch coordinated strikes.
    We fight because it is wrong that 40 percent of people in debt use credit cards to cover basic living costs including rent, food, and utilities. It is wrong that 62 percent of personal bankruptcies in the U.S. are linked to medical debt. It is wrong that students are leaving college owing an average of $35,000, and millions are in default. It is wrong that payday lenders earn high profits from poverty. And it is wrong that local court systems target poor people, disproportionately black and brown, and load them up with debt.
    We are different in many ways. Some of us are old, and some are young; we are from different parts of the country; we are diverse in race, ethnicity and religious background. A common belief unites us: everyone should have access to the goods and services they need to live without going broke or going into debt.
    Debt has isolated us and made us feel alone and ashamed. We have come out of the shadows to fight back as individuals and as a collective. We are here because we are organizing to win debt relief and a better economic system for all.)
        },
        category: {
          name: 'Payday Loans Collective'
        }
      }, {
        group: {
          name: 'auto_loans',
          full_name: 'Auto Loans Collective'
        },
        topic: {
          title: 'About the Auto Loans Collective'
        },
        post: {
          raw: %(For anyone who went into debt to buy a car.

      ### We are working together to plan actions, to develop debt resistance campaigns and to launch coordinated strikes.

      We fight because it is wrong that 40 percent of people in debt use credit cards to cover basic living costs including rent, food, and utilities. It is wrong that 62 percent of personal bankruptcies in the U.S. are linked to medical debt. It is wrong that students are leaving college owing an average of $35,000, and millions are in default. It is wrong that payday lenders earn high profits from poverty. And it is wrong that local court systems target poor people, disproportionately black and brown, and load them up with debt.
      We are different in many ways. Some of us are old, and some are young; we are from different parts of the country; we are diverse in race, ethnicity and religious background. A common belief unites us: everyone should have access to the goods and services they need to live without going broke or going into debt
      Debt has isolated us and made us feel alone and ashamed. We have come out of the shadows to fight back as individuals and as a collective. We are here because we are organizing to win debt relief and a better economic system for all.)
        },
        category: {
          name: 'Auto Loans Collective'
        }
      }, {
        group: {
          name: 'court_fines_and_fees',
          full_name: 'Court Fines and Fees Collective'
        },
        topic: {
          title: 'About the Court Fines and Fees Collective'
        },
        post: {
          raw: %(For anyone who is in debt to a local court system or probation company.

    ### We are working together to plan actions, to develop debt resistance campaigns and to launch coordinated strikes.
    We fight because it is wrong that 40 percent of people in debt use credit cards to cover basic living costs including rent, food, and utilities. It is wrong that 62 percent of personal bankruptcies in the U.S. are linked to medical debt. It is wrong that students are leaving college owing an average of $35,000, and millions are in default. It is wrong that payday lenders earn high profits from poverty. And it is wrong that local court systems target poor people, disproportionately black and brown, and load them up with debt.
    We are different in many ways. Some of us are old, and some are young; we are from different parts of the country; we are diverse in race, ethnicity and religious background. A common belief unites us: everyone should have access to the goods and services they need to live without going broke or going into debt.
    Debt has isolated us and made us feel alone and ashamed. We have come out of the shadows to fight back as individuals and as a collective. We are here because we are organizing to win debt relief and a better economic system for all.)
        },
        category: {
          name: 'Court Fines and Fees Collective'
        }
      }, {
        group: {
          name: 'medical_debt',
          full_name: 'Medical Debt Collective'
        },
        topic: {
          title: 'About the Medical Debt Collective'
        },
        post: {
          raw: %(For anyone who went into debt for health care.
    ### We are working together to plan actions, to develop debt resistance campaigns and to launch coordinated strikes.
    We fight because it is wrong that 40 percent of people in debt use credit cards to cover basic living costs including rent, food, and utilities. It is wrong that 62 percent of personal bankruptcies in the U.S. are linked to medical debt. It is wrong that students are leaving college owing an average of $35,000, and millions are in default. It is wrong that payday lenders earn high profits from poverty. And it is wrong that local court systems target poor people, disproportionately black and brown, and load them up with debt.
    We are different in many ways. Some of us are old, and some are young; we are from different parts of the country; we are diverse in race, ethnicity and religious background. A common belief unites us: everyone should have access to the goods and services they need to live without going broke or going into debt.
    Debt has isolated us and made us feel alone and ashamed. We have come out of the shadows to fight back as individuals and as a collective. We are here because we are organizing to win debt relief and a better economic system for all.)
        },
        category: {
          name: 'Medical Debt Collective'
        }
      }, {
        group: {
          name: 'solidarity_bloc',
          full_name: 'Solidarity Bloc'
        },
        topic: {
          title: 'About the Solidarity Bloc'
        },
        post: {
          raw: %(For anyone organizing in solidarity with people in debt.
    We organize in solidarity with those who are struggling under the weight of indebtedness for simply trying to access basic needs like healthcare, education and housing.
    We are committed to direct action, mutual aid and campaign support.)
        },
        category: {
          name: 'Solidarity Bloc'
        }
      }]
    end
  end
end

DebtCollective::Seeds.new.perform if $PROGRAM_NAME == __FILE__
