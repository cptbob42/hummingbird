class StoriesController < ApplicationController
  def index
    params.permit(:user_id, :news_feed, :page)

    if params[:user_id]
      stories = User.find(params[:user_id]).stories.for_user(current_user).order('updated_at DESC').includes(:user, :target, substories: :user).page(params[:page]).per(30)
    elsif params[:news_feed]
      stories = NewsFeed.new(current_user).fetch(params[:page] || 1)
    end

    render json: stories, meta: {cursor: 1 + (params[:page] || 1).to_i}
  end

  def create
    authenticate_user!
    params.require(:story).permit(:user_id, :comment)

    user = User.find(params[:story][:user_id])
    story = Action.broadcast(
      action_type: "created_profile_comment",
      user: user,
      poster: current_user,
      comment: params[:story][:comment]
    )

    render json: story
  end

  def destroy
    authenticate_user!
    params.require(:id)
    story = Story.find_by(id: params[:id])

    if story.nil?
      # Story has already been deleted.
      render json: true
      return
    end

    if story.can_be_deleted_by?(current_user)
      story.destroy!
      render json: true
    else
      render json: false
    end
  end
end
