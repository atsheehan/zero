class QuestionsController < ApplicationController
  QUESTIONS_PER_PAGE = 20

  def index
    @questions = Question.recent.limit(QUESTIONS_PER_PAGE)
  end

  def show
    @question = Question.find(params[:id])
    @answer = Answer.new
  end

  def new
    @question = Question.new
  end

  def create
    @question = Question.new(create_params)

    if @question.save
      flash[:success] = "Question submitted."
      redirect_to questions_path
    else
      flash[:alert] = "Failed to save question."
      render :new
    end
  end

  private

  def create_params
    params.require(:question).permit(:title, :body)
  end
end
