class User < ActiveRecord::Base
    has_many :identities
  
  def self.create_with_omniauth(auth)
    create(name: auth['info']['name'], uid: auth['uid'], provider: auth['provider'], email: auth["info"]["email"])
  end
end
