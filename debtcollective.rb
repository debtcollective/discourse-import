# frozen_string_literal: true

require_relative '../base.rb'
require_relative './constants.rb'
require 'aws-sdk-s3'

class ImportScripts::Debtcollective < ImportScripts::Base
  def initialize
    super

    @client = PG.connect(
      host: 'localhost',
      user: 'orlando',
      port: '5432',
      password: '',
      dbname: 'debtcollective_development'
    ) 

    @collectives = {
      '11111111-1111-1111-1111-111111111111' => 'for_profit_colleges',
      '22222222-2222-2222-2222-222222222222' => 'student_debt',
      '33333333-3333-3333-3333-333333333333' => 'credit_card_debt',
      '44444444-4444-4444-4444-444444444444' => 'housing_debt',
      '55555555-5555-5555-5555-555555555555' => 'payday_loans',
      '66666666-6666-6666-6666-666666666666' => 'auto_loans',
      '77777777-7777-7777-7777-777777777777' => 'court_fines_and_fees',
      '88888888-8888-8888-8888-888888888888' => 'medical_debt',
      '99999999-9999-9999-9999-999999999999' => 'solidarity_bloc'
    }
  end

  def import_users
    puts '', 'Migrating Users'

    total_count = @client.query('SELECT COUNT(*) FROM "Users"').to_a.first['count'].to_i
    progress_count = 0
    start_time = Time.now

    create_users(@client.query('SELECT "Users".*, "Accounts".* FROM "Users" LEFT JOIN "Accounts" on "Accounts".user_id = "Users".id ORDER BY "Users".created_at ASC')) do |row|
      progress_count += 1
      print_status(progress_count, total_count, start_time)

      next if find_user_by_import_id(row['user_id'])

      collectives = @client.query(
        %(SELECT "Collectives".* FROM "UsersCollectives" LEFT JOIN "Collectives" on "UsersCollectives".collective_id = "Collectives".id WHERE "UsersCollectives".user_id = '#{row['user_id']}')
      ).to_a

      collective_groups = collectives.map { |collective| @collectives[collective['id']] }.compact

      {
        id: row['user_id'],
        name: row['fullname'],
        email: row['email'],
        admin: row['role'] == 'Admin',
        created_at: row['created_at'],
        updated_at: row['updated_at'],
        location: row['state'],
        bio_raw: row['bio'],
        trust_level: 1,
        custom_fields: {
          import_pass: row['encrypted_password'],
          state: row['state'],
          zip: row['zip']
        },
        post_create_action: proc do |user|
          # add user to groups
          collective_groups.each do |collective|
            group = Group.find_by_name(collective)
            group.add(user)
            group.save
          end

          if user.admin
            group = Group.find_by_name(DISPUTE_TOOLS_GROUP[:name])
            group.add(user)
            group.save
          end
        end
      }
    end
  end

  def execute
    import_users
  end
end

ImportScripts::Debtcollective.new.perform if $PROGRAM_NAME == __FILE__
