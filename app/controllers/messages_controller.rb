class MessagesController < ApplicationController
  def create
    role = "user"
    user_id = params["message"]["from"]["id"].to_s
    text = params["message"]["text"]
    content = { user_id:, text: }.as_json

    message = Message.new(role:, content:)

    message.submit

    head :ok
  end
end


# {"update_id"=>227341818, "message"=>{"message_id"=>4, "from"=>{"id"=>5899443915, "is_bot"=>false, "first_name"=>"Eli", "last_name"=>"Block", "language_code"=>"en"}, "chat"=>{"id"=>5899443915, "first_name"=>"Eli", "last_name"=>"Block", "type"=>"private"}, "date"=>1712326920, "text"=>"Testing again"}}
