class Message < ApplicationRecord
  validates :user_id, presence: true
  validates :role, presence: true
  validates :text, presence: true

  def self.prompt
    "You are chatting with different users.
    You will be provided with the user id so you know who you are chatting with.
    respond with a json array of one or more messages.
    Respond to the user who messaged you with something short and helpful.
    Optionally respond to an additional user to let them know that a user has said something relevant to them.
    Here is an example of the messages object I will pass to the api: #{example}"
  end

  def self.example
    json = File.open(Rails.root.join("app/example.json")).read
    JSON.parse(json).to_json
  end

  def self.formatted
    [prompt_message] + all.map(&:format)
  end

  def self.prompt_message
    { role: "system", content: prompt }
  end

  def client
    OpenAI::Client.new(access_token: ENV['OPENAI_SECRET'])
  end

  def format
    { role:, content: { user_id:, text: }.to_json }
  end

  def submit
    response = chat
    puts response
    response_messages = assistant_messages(response)

    ActiveRecord::Base.transaction do
      save!
      response_messages.each(&:save!)
    end
  end

  def assistant_messages(response)
    content = response.dig("choices", 0, "message", "content")
    content = JSON.parse(content)
    raise 'Did not receive an array' unless content.is_a? Array

    content.map do |item|
      role = "assistant"
      id = content["id"]
      text = content["text"]
      Message.new(role:, id:, text:)
    end
  end

  def chat
    client.chat(
      parameters: {
        model: 'gpt-4-turbo-preview',
        response_format: { type: 'json_object' },
        messages: Message.formatted,
        temperature: 0
      }
    )
  end

  def send_to_user
    puts "sending"
  end

  def manual_chat(content)
    client.chat(
      parameters: {
        model: 'gpt-4-turbo-preview',
        response_format: { type: 'json_object' },
        messages: Message.formatted << { role: "user", content: "message"},
        temperature: 0
      }
    )
  end
end
