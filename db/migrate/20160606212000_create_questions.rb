class CreateQuestions < ActiveRecord::Migration
  def change
    create_table :questions do |t|
      t.string :title, null: false
      t.string :body, null: false, limit: 50_000
      t.timestamps null: false
    end

    add_index :questions, :created_at
  end
end
