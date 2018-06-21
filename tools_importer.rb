require_relative './base.rb'

module Debtcollective
  class ToolsImporter
    def initialize
      @old_tools ||= PG.connect(
        host: 'localhost',
        user: 'orlando',
        port: '5432',
        password: '',
        dbname: 'debtcollective_development'
      )

      @new_tools ||= PG.connect(
        host: 'localhost',
        user: 'orlando',
        port: '5432',
        password: '',
        dbname: 'dispute_tools_development'
      )
    end

    def perform
      import_users
      import_disputes
      import_dispute_statuses
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
          'INSERT INTO "Users" (id, external_id, created_at, updated_at, banned) VALUES ($1, $2, $3, $4, $5)',
          [
            user.custom_fields['import_id'],
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
      @new_tools.query(%Q[SELECT setval('readable_id_seq', (SELECT max(readable_id) FROM "Disputes") + 1, false)]).to_a
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