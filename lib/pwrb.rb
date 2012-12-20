require "pwrb/version"

require 'clipboard'
require 'gpgme'
require 'json'
require 'highline/import'
require 'tabularize'
require 'securerandom'

module Pwrb
  class PasswordDB
    def initialize(options=nil)
      @filename = File.expand_path('~/.pw')
      @filename = File.readlink(@filename) if File.symlink?(@filename)
      @options = options
      @crypto = GPGME::Crypto.new

      read_safe
      @selected = @data.select{ |item| match(item, @options) }
    end

    def read_safe(password=nil)
      if File.file?(@filename)
        @password = password || ask_for_password("Enter master passphrase")
        plain_data = @crypto.decrypt(File.open(@filename), :password => @password).to_s
        @data = JSON.parse(plain_data, :symbolize_names => true)
      else
        create_safe(password)
      end
    end

    def write_safe
      plain_data = JSON.generate(@data)
      plain_data.force_encoding('ASCII-8BIT')
      @crypto.encrypt(plain_data, :output => File.open(@filename, 'w+'))
    end

    def create_safe(password=nil)
      puts "No password file detected, creating one at #{@filename}"
      @password = ask_for_password("Enter master passphrase", confirm = true) unless @password == password

      FileUtils.mkdir_p(File.dirname(@filename))
      @data = []
      write_safe
      File.chmod(0600, @filename)
    end

    def to_s
      "<*******>"
    end

    def user_match(item, user)
      /#{user}/i =~ item[:user]
    end

    def site_match(item, site)
      /#{site}/i =~ item[:site] || /#{site}/i =~ item[:url]
    end

    def match(item, options)
      user_match(item, options[:user]) && site_match(item, options[:site])
    end

    def ask_for_password(prompt, confirm=false)
      password = ask(prompt + ": ") { |q| q.echo = false; q.validate = /\A.+\Z/ }
      if confirm
        password_confirm = ask_for_password(prompt + " again")

        if password == password_confirm
          password
        else
          puts "Password mismatch, try again!"
          ask_for_password(prompt, true)
        end
      else
        password
      end
    end

    def ask_for_selection
      case
        when @selected.empty?
          puts "Record not exists!"
          nil
        when @selected.length == 1
          @selected.first
        else
          list
          choose = ask('Which one? ', Integer) { |q| q.in = 0..@selected.length-1 }
          @selected[choose]
      end
    end

    def ask_for_item(init={})
      item = init

      item[:user] = ask("User name? ") { |q| q.default = init[:user] || @options[:user]; q.validate = /\A\S+\Z/ }
      item[:email] = ask("Email? ") { |q| q.default = init[:email] }
      item[:site] = ask("Site? ") { |q| q.default = init[:site] || @options[:site]; q.validate = /\A.+\Z/ }
      item[:url] = ask("URL? ") { |q| q.default = init[:url] || @options[:site] }

      item
    end

    def ask_for_confirm
      confirm = ask("Are you sure? ") { |q| q.validate = /\A(y|yes|n|no)\Z/i }
      ['y', 'yes'].include?(confirm)
    end

    def timestamp
      Date.today.strftime("%Y%m%d")
    end

    def list
      return if @selected.empty?

      table = Tabularize.new
      table << %w[# ID User Password Site Date]
      table.separator!

      @selected.each_with_index do |item, index|
        user = item[:user]
        user += "<%s>" % item[:email] unless item[:email].empty?
        site = "%s[%s]" % [item[:site], item[:url]]
        password = (@options[:print] ? item[:password] : "***")

        table << [index.to_s, item[:id].split('-').first, user, password, site, item[:date]]
      end

      puts table
    end

    def copy
      target = ask_for_selection
      seconds = 10

      if target
        original_clipboard_content = Clipboard.paste
        sleep 0.1
        Clipboard.copy target[:password]
        puts "Password for #{target[:site]} is in clipboard for #{seconds} seconds"
        begin
          sleep seconds
        rescue Interrupt
          Clipboard.copy original_clipboard_content
          raise
        end
        Clipboard.copy original_clipboard_content
      end
    end

    def update
      target = ask_for_selection

      if target
        target[:password] = ask_for_password("Enter new password", confirm = true)
        target[:date] = timestamp
        write_safe
        puts "Update complete!"
      end
    end


    def add
      item = ask_for_item

      item[:id] = SecureRandom.uuid
      item[:password] = ask_for_password("Enter password", confirm = true)
      item[:date] = timestamp

      if ask_for_confirm
        @data << item
        write_safe
        puts "Added #{item[:user]}@#{item[:site]}!"
      end
    end

    def edit
      target = ask_for_selection

      if target
        ask_for_item(target)
        if ask_for_confirm
          target[:date] = timestamp
          write_safe
          puts "Update #{target[:user]}@#{target[:site]}!"
        end
      end
    end

    def remove
      target = ask_for_selection

      if target && ask_for_confirm
        @data.delete(target)
        write_safe
        puts "#{target[:user]}@#{target[:site]} Removed!"
      end
    end

  end
end
