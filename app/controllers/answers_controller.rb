class AnswersController < ApplicationController
  def create
    @question = Question.find(params[:question_id])
    @answer = @question.answers.build(answer_params)

    if @answer.save
      flash[:success] = "Answer saved."
      redirect_to question_path(@question)
    else
      flash[:alert] = "Failed to save answer."
      render "questions/show"
    end
  end

  private

  def answer_params
    params.require(:answer).permit(:body)
  end
end
