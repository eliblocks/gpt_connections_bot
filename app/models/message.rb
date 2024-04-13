class Message < ApplicationRecord
  validates :user_id, presence: true
  validates :role, presence: true
  validates :text, presence: true

  def self.prompt
"You are chatting with different user_ids. \
Your purpose is to introduce users to each other based on relevant messages. \
If there are no relevant messages in the thread reply to the user with a short, helpful message. \
If there is a relevant message send messages to both users asking if they wish to be introduced. \
respond with a json array of messages you want to send. Example: { 88823: hello }"
  end

  def self.example
    json = File.open(Rails.root.join("app/example.json")).read
    JSON.parse(json).to_json
  end

  def self.formatted
    [prompt_message] + all.map(&:formatted)
  end

  def self.prompt_message
    { role: "system", content: prompt }
  end

  def client
    OpenAI::Client.new(access_token: ENV['OPENAI_SECRET'])
  end

  def formatted
    { role:, content: { user_id => text }.to_json }
  end

  def message_history
    Message.formatted << formatted
  end

  def submit
    puts "SENDING:"
    puts message_history
    response = chat
    puts "RECEIVED:"
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

    content.keys.map do |key|
      Message.new(role: "assistant", user_id: key, text: content[key])
    end
  end

  def chat
    client.chat(
      parameters: {
        model: 'gpt-4-turbo',
        response_format: { type: 'json_object' },
        messages: message_history,
        temperature: 0.5
      }
    )
  end

  def send_to_user
    puts "sending"
  end

  def manual_chat(content)
    client.chat(
      parameters: {
        model: 'gpt-4-turbo',
        response_format: { type: 'json_object' },
        messages: Message.formatted << { role: "user", content: "message"},
        temperature: 0
      }
    )
  end
end
