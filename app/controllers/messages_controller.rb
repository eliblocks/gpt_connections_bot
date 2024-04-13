class MessagesController < ApplicationController
  def create
    user_id = params["message"]["from"]["id"].to_s
    text = params["message"]["text"]

    Message.chat(user_id:, text:)

    head :ok
  end
end
