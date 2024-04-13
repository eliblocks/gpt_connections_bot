class Message < ApplicationRecord
  validates :role, presence: true
  validates :user_id, presence: true
  validates :text, presence: true

  def self.prompt
    "You are chatting with different users.
    You will be provided with a json list of all messages that have been sent by users and by the assistant.
    reply to any users that need a reply by calling send_message with the user_id and message text as many times as neceessary.
    Your purpose is to introduce users to each other based on relevant messages.
    If there are no relevant messages in the thread reply to the user with a short, helpful message.
    If there is a relevant message send messages to both users asking if they wish to be introduced.
    the only way to communicate with users is by calling send_message with the user_id and text"
  end

  def self.example
    json = File.open(Rails.root.join("app/example.json")).read
    JSON.parse(json).to_json
  end

  def self.build_from(user_id, text)
    new(role: "user", user_id:, text:)
  end

  def self.formatted
    [prompt_message] + all.map(&:formatted)
  end

  def self.prompt_message
    { role: "system", content: prompt }
  end

  def formatted
    { role:, content: { user_id:, text: }.to_json }
  end

  def client
    OpenAI::Client.new(access_token: ENV['OPENAI_SECRET'])
  end

  def submit
    response = chat
    puts response
    ActiveRecord::Base.transaction do
      save!
      responses = response_messages(response)
      responses.each(&:save!)
      responses.each(&:send_to_user)
    end
  end

  def message_history
    Message.formatted << formatted
  end

  def chat
    client.chat(
      parameters: {
        model: 'gpt-4-turbo',
        messages: message_history,
        temperature: 0.5,
        tools: [
          {
            type: "function",
            function: {
              name: "send_message",
              description: "send a message to a user",
              parameters: {
                type: "object",
                properties: {
                  user_id: {
                    type: "string",
                    description: "the id of the user the message is for"
                  },
                  text: {
                    type: "string",
                    description: "The content of the message"
                  }
                }
              }
            }
          }
        ]
      }
    )
  end

  def send_to_user
    puts "sending to user: #{user_id}, text: #{text}"
  end

  def tool_calls(response)
    calls = response.dig("choices", 0, "message", "tool_calls")
    raise "No tool calls" unless calls&.any?

    calls
  end

  def response_messages(response)
    tool_calls(response).map do |call|
      function_name = call["function"]["name"]

      raise "received unknown function call" unless function_name == "send_message"

      args = call["function"]["arguments"]

      parsed_args = JSON.parse(args)

      user_id = parsed_args["user_id"]
      text = parsed_args["text"]

      raise "received incorrect function arguments" unless user_id && text

      Message.new(role: "assistant", user_id:, text:)
    end
  end
end
