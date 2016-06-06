class CreateAnswers < ActiveRecord::Migration
  def change
    create_table :answers do |t|
      t.integer :question_id, null: false
      t.string :body, null: false, limit: 50_000
      t.timestamps null: false
    end

    add_index :answers, :question_id
  end
end
