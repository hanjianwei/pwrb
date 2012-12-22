require 'gpgme'
require 'json'
require 'securerandom'

module Pwrb
  class DB
    def initialize(filename, password)
      @filename = filename
      @passwords = []
      @crypto = GPGME::Crypto.new

      # Read encrypted file
      if File.exist?(filename)
        text = @crypto.decrypt(File.open(filename), :password => password).to_s
        @passwords = JSON.parse(text, :symbolize_names => true)
      else
        FileUtils.mkdir_p(File.dirname(filename))
        save
        File.chmod(0600, filename)
      end
    end

    def save
      text = JSON.generate(@passwords)
      text.force_encoding('ASCII-8BIT')
      @crypto.encrypt(text, :output => File.open(@filename, 'w+'))
    end

    def to_s
      "<*>"
    end

    def query(user, site)
      @passwords.select {|p| /#{user}/i =~ p[:user] && (/#{site}/i =~ p[:site] || /#{site}/i =~ p[:url]) }
    end

    def insert(item)
      @passwords << item.merge(:id => SecureRandom.uuid, :date => timestamp)
      save
    end

    def update(new_item)
      new_item.merge!(:date => timestamp)
      item = @passwords.find { |p| p[:id] == new_item[:id] }
      if item
        item.merge!(new_item) { |_, oldval, newval| (newval && !newval.empty?) ? newval : oldval }
        save
      end
    end

    def remove(item)
      @passwords.delete(item)
      save
    end

    def timestamp
      Date.today.strftime("%Y%m%d")
    end
  end
end
