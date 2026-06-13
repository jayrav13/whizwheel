class SessionsController < ApplicationController
  def new
  end

  def create
    if (user = User.authenticate_by(username: params[:username], password: params[:password]))
      start_new_session_for(user)
      redirect_to root_path
    else
      redirect_to new_session_path, alert: "Invalid username or password."
    end
  end

  def destroy
    terminate_session
    redirect_to root_path
  end
end
