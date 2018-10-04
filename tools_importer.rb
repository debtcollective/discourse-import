require_relative '../base.rb'

module Debtcollective
  class ToolsImporter < ImportScripts::Base
    def initialize
      @old_tools ||= PG.connect(
        host: 'localhost',
        user: 'orlandodelaguila',
        port: '5432',
        password: '',
        dbname: 'dispute_tools_old'
      )

      @new_tools ||= PG.connect(
        host: 'localhost',
        user: 'orlandodelaguila',
        port: '5432',
        password: '',
        dbname: 'dispute_tools_development'
      )

      super
    end

    def perform
      import_users
      import_disputes
      create_dispute_pms
      assign_dispute_thread_ids
      import_dispute_statuses
      import_dispute_comments
      import_dispute_renderers
      import_attachments
      import_admins_disputes
    end

    def import_users
      puts '', 'Migrating Users'

      max = User.where('id > 0').count
      current = 0

      # for each user
      # create user in the new tools database
      User.where('id > 0').order('created_at DESC').find_each do |user|
        current += 1
        next unless user.custom_fields['import_id']

        @new_tools.query(
          'INSERT INTO "Users" (id, name, username, external_id, created_at, updated_at, banned) VALUES ($1, $2, $3, $4, $5, $6, $7)',
          [
            user.custom_fields['import_id'],
            user.name,
            user.username,
            user.id,
            user.created_at,
            user.updated_at,
            false
          ]
        )

        print_status(current, max)
      end
    end

    def import_disputes
      puts '', 'Migrating Disputes'

      max = @old_tools.query('SELECT COUNT(*) FROM "Disputes"').to_a.first['count'].to_i
      current = 0

      @old_tools.query('SELECT * FROM "Disputes"').each do |row|
        current += 1

        @new_tools.query(
          'INSERT INTO "Disputes" (id, user_id, dispute_tool_id, data, deactivated, created_at, updated_at, readable_id) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
          [
            row['id'],
            row['user_id'],
            row['dispute_tool_id'],
            row['data'],
            row['deactivated'],
            row['created_at'],
            row['updated_at'],
            row['readable_id']
          ]
        )

        print_status(current, max)
      end

      # set sequence correctly
      @new_tools.query(%[SELECT setval('readable_id_seq', (SELECT max(readable_id) FROM "Disputes") + 1, false)]).to_a
    end

    def create_dispute_pms
      puts '', 'Creating Dispute PMs'

      total_count = @new_tools.query('SELECT COUNT(*) FROM "Disputes"').to_a.first['count'].to_i
      progress_count = 0
      start_time = Time.now

      # create pms
      create_posts(@new_tools.query('SELECT "Disputes".*, "DisputeTools".readable_name FROM "Disputes" JOIN "DisputeTools" ON "DisputeTools".id = "Disputes".dispute_tool_id;')) do |row|
        dispute_user = find_user_by_import_id(row['user_id'])

        # get admins for dispute
        admin_rows = @new_tools.query(%(SELECT admin_id FROM "AdminsDisputes" WHERE dispute_id = $1), [row['id']]).to_a
        admin_ids = admin_rows.map { |x| x['admin_id'] }.uniq
        admin_users = admin_ids.map { |id| find_user_by_import_id(id) }

        target_usernames = ['system', dispute_user.username] + admin_users.collect(&:username)

        # get pm title
        readable_id = row['readable_id']
        name = dispute_user.name.present? ? dispute_user.name : dispute_user.username
        dispute_tool_name = row['readable_name']

        title = "#{readable_id} - #{name} - #{dispute_tool_name}"

        data = {
          archetype: Archetype.private_message,
          id: "dispute_pm#{row['id']}",
          title: title,
          raw: row['comment'],
          user_id: Discourse.system_user.id,
          target_usernames: target_usernames,
          target_groups: ['dispute_coordinator'],
          created_at: row['created_at'],
          updated_at: row['updated_at'],
          custom_fields: {
            debtcollective_dispute_id: row['id']
          }
        }

        progress_count += 1
        print_status(progress_count, total_count, start_time)
  
        data
      end
    end
    
    def assign_dispute_thread_ids
      puts '', 'Updating Disputes with dispute_thread_id'

      total_count = @new_tools.query('SELECT COUNT(*) FROM "Disputes"').to_a.first['count'].to_i
      progress_count = 0
      start_time = Time.now 

      @new_tools.query('SELECT * FROM "Disputes"').to_a.each do |row|
        dispute_thread_id = topic_lookup_from_imported_post_id("dispute_pm#{row['id']}")[:topic_id]
  
        @new_tools.query('UPDATE "Disputes" SET dispute_thread_id = $1 WHERE "Disputes".id = $2', [
          dispute_thread_id,
          row['id']
        ])

        progress_count += 1
        print_status(progress_count, total_count, start_time) 
      end
    end

    def import_dispute_statuses
      puts '', 'Migrating DisputeStatuses'

      max = @old_tools.query('SELECT COUNT(*) FROM "DisputeStatuses"').to_a.first['count'].to_i
      current = 0

      @old_tools.query('SELECT * FROM "DisputeStatuses"').each do |row|
        current += 1

        @new_tools.query(
          'INSERT INTO "DisputeStatuses" (id, dispute_id, status, comment, created_at, updated_at, notify, pending_submission, note) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)',
          [
            row['id'],
            row['dispute_id'],
            row['status'],
            row['comment'],
            row['created_at'],
            row['updated_at'],
            row['notify'],
            row['pending_submission'],
            row['note']
          ]
        )

        print_status(current, max)
      end
    end

    def import_dispute_comments
      # for each dispute status sorted by created_at ASC where comment is not null
      # get user by import_id
      # create a comment as if it was from the user
    end

    def import_dispute_renderers
      puts '', 'Migrating DisputeRenderers'

      max = @old_tools.query('SELECT COUNT(*) FROM "DisputeRenderers"').to_a.first['count'].to_i
      current = 0

      @old_tools.query('SELECT * FROM "DisputeRenderers"').each do |row|
        current += 1

        @new_tools.query(
          'INSERT INTO "DisputeRenderers" (id, dispute_id, zip_path, zip_meta, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6)',
          [
            row['id'],
            row['dispute_id'],
            row['zip_path'],
            row['zip_meta'],
            row['created_at'],
            row['updated_at']
          ]
        )

        print_status(current, max)
      end
    end

    def import_attachments
      puts '', 'Migrating Attachments'

      max = @old_tools.query('SELECT COUNT(*) FROM "Attachments"').to_a.first['count'].to_i
      current = 0

      @old_tools.query('SELECT * FROM "Attachments"').each do |row|
        current += 1

        @new_tools.query(
          'INSERT INTO "Attachments" (id, type, foreign_key, file_path, file_meta, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7)',
          [
            row['id'],
            row['type'],
            row['foreign_key'],
            row['file_path'],
            row['file_meta'],
            row['created_at'],
            row['updated_at']
          ]
        )

        print_status(current, max)
      end
    end

    def import_admins_disputes
      puts '', 'Migrating AdminsDisputes'

      max = @old_tools.query('SELECT COUNT(*) FROM "AdminsDisputes"').to_a.first['count'].to_i
      current = 0

      @old_tools.query('SELECT * FROM "AdminsDisputes"').each do |row|
        current += 1

        begin
          @new_tools.query(
            'INSERT INTO "AdminsDisputes" (admin_id, dispute_id, created_at, updated_at) VALUES ($1, $2, $3, $4)',
            [
              row['admin_id'],
              row['dispute_id'],
              row['created_at'],
              row['updated_at']
            ]
          )
        rescue PG::UniqueViolation
          puts 'duplicated record, skipping'
        end

        print_status(current, max)
      end
    end

    private

    def print_status(current, max, start_time = nil)
      if start_time.present?
        elapsed_seconds = Time.now - start_time
        elements_per_minute = format('[%.0f items/min]  ', current / elapsed_seconds.to_f * 60)
      else
        elements_per_minute = ''
      end

      print format("\r%9d / %d (%5.1f%%)  %s", current, max, current / max.to_f * 100, elements_per_minute)
    end
  end
end

Debtcollective::ToolsImporter.new.perform if $PROGRAM_NAME == __FILE__