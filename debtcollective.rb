require_relative './base.rb'
require 'pg'
require 'aws-sdk-s3'

class ImportScripts::Debtcollective < ImportScripts::Base
  def initialize
    super

    @client = PG.connect(
      host: 'localhost',
      user: '',
      port: '',
      password: '',
      dbname: ''
    )

    @s3_bucket = 'my-s3-bucket'
    @s3 = Aws::S3::Client.new(
      region: '',
      access_key_id: '',
      secret_access_key: ''
    )

    @collectives = {
      '11111111-1111-1111-1111-111111111111' => 'for-profit-colleges',
      '22222222-2222-2222-2222-222222222222' => 'student-debt',
      '33333333-3333-3333-3333-333333333333' => 'credit-card-debt',
      '44444444-4444-4444-4444-444444444444' => 'housing-debt',
      '55555555-5555-5555-5555-555555555555' => 'payday-loans',
      '66666666-6666-6666-6666-666666666666' => 'auto-loans',
      '77777777-7777-7777-7777-777777777777' => 'court-fines-fees',
      '88888888-8888-8888-8888-888888888888' => 'medical-debt',
      '99999999-9999-9999-9999-999999999999' => 'solidarity-bloc'
    }
  end

  def import_users
    puts '', 'Migrating Users'

    total_count = @client.query('SELECT COUNT(*) FROM "Users"').to_a.first['count'].to_i
    progress_count = 0
    start_time = Time.now

    create_users(@client.query('SELECT "Users".*, "Accounts".* FROM "Users" LEFT JOIN "Accounts" on "Accounts".user_id = "Users".id')) do |row|
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
          collectives: collective_groups,
          state: row['state'],
          zip: row['zip']
        }
      }
    end
  end

  def import_avatars
    puts '', 'Migrating Avatars'

    total_count = @client.query('SELECT COUNT(*) FROM "Accounts" WHERE image_path IS NOT NULL').to_a.first['count'].to_i
    progress_count = 0
    start_time = Time.now

    @client.query('SELECT * FROM "Accounts" WHERE image_path IS NOT NULL').to_a.each do |row|
      user = find_user_by_import_id(row['user_id'])

      next if user.custom_fields['import_avatar']

      # download image from s3
      avatar_filename = 'medium.jpeg'
      avatar_remote_path = row['image_path'].gsub('{version}.{ext}', avatar_filename)
      avatar_path = "#{Rails.root}/tmp/#{user.id}-#{avatar_filename}"

      begin
        @s3.get_object(
          response_target: avatar_path,
          bucket: @s3_bucket,
          key: avatar_remote_path
        )
      rescue Aws::S3::Errors::NoSuchKey
        puts "Missing upload, #{avatar_remote_path}"
        next
      end

      upload = create_upload(user.id, avatar_path, avatar_filename)

      if upload.persisted?
        user.import_mode = false
        user.create_user_avatar
        user.import_mode = true
        user.user_avatar.update(custom_upload_id: upload.id)
        user.uploaded_avatar_id = upload.id
        user.custom_fields['import_avatar'] = true
        user.save
      else
        puts "Error: Upload did not persist: #{avatar_path}!"
      end

      progress_count += 1
      print_status(progress_count, total_count, start_time)
    end
  end

  def execute
    import_users
    import_avatars
  end
end

ImportScripts::Debtcollective.new.perform if $PROGRAM_NAME == __FILE__
