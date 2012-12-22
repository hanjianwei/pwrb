require 'highline/import'
require 'clipboard'

module Pwrb
  class CLI
    def initialize(db, echo = false)
      @db = db
      @echo = echo
    end

    def list(user, site)
      result = @db.query(user, site)
      return if result.empty?

      table = Tabularize.new

      table << %w[# ID User Password Site Date]
      table.separator!

      result.each_with_index do |p, index|
        user = p[:user]
        user += "<%s>" % p[:email] unless p[:email].empty?
        site = "%s[%s]" % [p[:site], p[:url]]
        password = (@echo ? p[:password] : "***")

        table << [index.to_s, p[:id].split('-').first, user, password, site, p[:date]]
      end

      puts table
    end

    def select(user, site)
      result = @db.query(user, site)

      case result.count
        when 0
          nil
        when 1
          result[0]
        else
          list(user, site)
          index = ask('Which one?', Integer) { |q| q.in = 0...result.count }
          result[index]
      end
    end

    def copy(user, site)
      item = select(user, site)
      return unless item

      seconds = 10
      original_clipboard = Clipboard.paste
      sleep(0.1)
      Clipboard.copy(item[:password])
      puts "Password for #{item[:site]} is in clipboard for #{seconds} seconds"

      begin
        sleep(seconds)
      rescue Interrupt
        Clipboard.copy(original_clipboard)
        raise
      end

      Clipboard.copy(original_clipboard)
    end

    def update(user, site)
      item = select(user, site)
      return unless item

      @db.update(item.merge(:password => new_password("Enter new password")))
    end

    def add(user, site)
      item = new_item(:user => user, :site => site)
      item[:password] = new_password("Enter password")

      @db.insert(item)
    end

    def edit(user, site)
      item = select(user, site)
      return unless item

      @db.update(new_item(item.dup))
    end

    def remove(user, site)
      item = select(user, site)
      return unless item

      @db.remove(item)
    end

    def new_item(init = {})
      item = init

      item[:user]  = ask("User name: ") { |q| q.default = init[:user]; q.validate = /\A\S+\Z/ }
      item[:email] = ask("Email: ")     { |q| q.default = init[:email] }
      item[:site]  = ask("Site: ")      { |q| q.default = init[:site]; q.validate = /\A.+\Z/ }
      item[:url]   = ask("URL: ")       { |q| q.default = init[:url] }

      item
    end

    def new_password(prompt)
      password = ask(prompt + ": ") { |q| q.echo = false }
      confirm  = ask(prompt + " again: ") { |q| q.echo = false }

      if password == confirm
        password
      else
        puts "Password mismatch, try again!"
        new_password(prompt)
      end
    end
  end
end
