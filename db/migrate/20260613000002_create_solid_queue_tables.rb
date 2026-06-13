class CreateSolidQueueTables < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_queue_jobs, if_not_exists: true do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.integer :priority, default: 0, null: false
      t.string :active_job_id
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.string :concurrency_key
      t.timestamps null: false

      t.index :active_job_id, if_not_exists: true
      t.index :class_name, if_not_exists: true
      t.index :finished_at, if_not_exists: true
      t.index [ :queue_name, :finished_at ], name: :index_solid_queue_jobs_for_filtering, if_not_exists: true
      t.index [ :scheduled_at, :finished_at ], name: :index_solid_queue_jobs_for_alerting, if_not_exists: true
    end

    create_table :solid_queue_blocked_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.string :concurrency_key, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false

      t.index [ :concurrency_key, :priority, :job_id ], name: :index_solid_queue_blocked_executions_for_release, if_not_exists: true
      t.index [ :expires_at, :concurrency_key ], name: :index_solid_queue_blocked_executions_for_maintenance, if_not_exists: true
      t.index :job_id, unique: true, if_not_exists: true
    end

    create_table :solid_queue_claimed_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.bigint :process_id
      t.datetime :created_at, null: false

      t.index :job_id, unique: true, if_not_exists: true
      t.index [ :process_id, :job_id ], if_not_exists: true
    end

    create_table :solid_queue_failed_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.text :error
      t.datetime :created_at, null: false

      t.index :job_id, unique: true, if_not_exists: true
    end

    create_table :solid_queue_pauses, if_not_exists: true do |t|
      t.string :queue_name, null: false
      t.datetime :created_at, null: false

      t.index :queue_name, unique: true, if_not_exists: true
    end

    create_table :solid_queue_processes, if_not_exists: true do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.bigint :supervisor_id
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.datetime :created_at, null: false
      t.string :name, null: false

      t.index :last_heartbeat_at, if_not_exists: true
      t.index [ :name, :supervisor_id ], unique: true, if_not_exists: true
      t.index :supervisor_id, if_not_exists: true
    end

    create_table :solid_queue_ready_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true, if_not_exists: true
      t.index [ :priority, :job_id ], name: :index_solid_queue_poll_all, if_not_exists: true
      t.index [ :queue_name, :priority, :job_id ], name: :index_solid_queue_poll_by_queue, if_not_exists: true
    end

    create_table :solid_queue_recurring_tasks, if_not_exists: true do |t|
      t.string :key, null: false
      t.string :schedule, null: false
      t.string :command, limit: 2048
      t.string :class_name
      t.text :arguments
      t.string :queue_name
      t.integer :priority, default: 0
      t.boolean :static, default: true, null: false
      t.text :description
      t.timestamps null: false

      t.index :key, unique: true, if_not_exists: true
      t.index :static, if_not_exists: true
    end

    create_table :solid_queue_recurring_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.string :task_key, null: false
      t.datetime :run_at, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true, if_not_exists: true
      t.index [ :task_key, :run_at ], unique: true, if_not_exists: true
    end

    create_table :solid_queue_scheduled_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true, if_not_exists: true
      t.index [ :scheduled_at, :priority, :job_id ], name: :index_solid_queue_dispatch_all, if_not_exists: true
    end

    create_table :solid_queue_semaphores, if_not_exists: true do |t|
      t.string :key, null: false
      t.integer :value, default: 1, null: false
      t.datetime :expires_at, null: false
      t.timestamps null: false

      t.index :expires_at, if_not_exists: true
      t.index [ :key, :value ], if_not_exists: true
      t.index :key, unique: true, if_not_exists: true
    end

    add_solid_queue_foreign_key :solid_queue_blocked_executions
    add_solid_queue_foreign_key :solid_queue_claimed_executions
    add_solid_queue_foreign_key :solid_queue_failed_executions
    add_solid_queue_foreign_key :solid_queue_ready_executions
    add_solid_queue_foreign_key :solid_queue_recurring_executions
    add_solid_queue_foreign_key :solid_queue_scheduled_executions
  end

  private

  def add_solid_queue_foreign_key(table)
    return if foreign_key_exists?(table, :solid_queue_jobs, column: :job_id)

    add_foreign_key table, :solid_queue_jobs, column: :job_id, on_delete: :cascade
  end
end
