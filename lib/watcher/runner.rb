#!/usr/bin/env ruby

require "io/console"
require "listen"
require "colored2"
require "tty-cursor"

class DirectoryWatcher
  ListenerCounters = Struct.new(:modified, :added, :removed) do
    attr_reader :reset_at

    def initialize(*args, &)
      super
      reset
    end

    def reset
      self.modified = self.added = self.removed = 0
      @reset_at = Time.now.to_f

      self
    end

    def increment(modified, added, removed)
      self.modified += modified || 0
      self.added += added || 0
      self.removed += removed || 0
    end

    def changed?
      modified + added + removed > 0
    end
  end

  COMMAND = ->(counter) {
    cursor = TTY::Cursor
    puts cursor.column(1)
    print "@ #{Time.now}"
    puts cursor.column(1)
    if counter.modified
      print "modified: #{counter.modified}".blue
      puts cursor.column(1)
    end

    if counter.added
      print "   added: #{counter.added}".green
      puts cursor.column(1)
    end
    if counter.removed
      print " removed: #{counter.removed}".red
      puts cursor.column(1)
    end
  }

  attr_reader :directory, :command, :minimum_frequency, :last_update,
              :mutex, :exec_command, :keypress_listen_threadm, :counters,
              :cursor

  def initialize(directory, *arguments)
    @mutex = Mutex.new

    @directory = directory
    @command = COMMAND
    @cursor = TTY::Cursor

    @minimum_frequency = 10 # seconds
    @counters = ListenerCounters.new

    self.last_update = 0

    @keypress_listen_thread ||= start_keypress_listen_thread

    @exec_command = ""
    parse_args!(arguments)
  end

  def run
    puts "\n\n─────────────────────────────┤ EXIT ├─────────────────────────────".bold.yellow

    puts "Watching #{directory} for changes... \n".bold.yellow
    puts " • If detected, the following command will run: #{"#{exec_command} <#modified> <#added> <#<removed>".bold.cyan}".bold.yellow unless exec_command.empty?
    puts " • Checking at least every #{minimum_frequency} seconds.".green.bold
    puts " • Press space bar to force the check for file changes now.".green.bold
    puts " • You'll see a green dot for new files, yellow for changes, red for deletes.".green.bold
    puts " • Press 'q' to exit, (or Ctrl-C or Ctrl-) if nothing else works.".yellow.bold
    puts
    Kernel.trap("SIGINT") { graceful_exit }

    listener.start
    sleep
    keypress_listen_thread.join
  end

  def parse_args!(arguments = ARGV)
    while !arguments.empty?
      arg = arguments.shift
      if Dir.exist?(arg)
        @directory = arg
      else
        @exec_command << "#{arg} "
      end
    end
  end

  private

  def graceful_exit
    puts "\n\n─────────────────────────────┤ EXIT ├─────────────────────────────".bold.yellow
    puts " • Killing the keypress thread...".red.bold
    begin
      keypress_listen_thread&.kill
    rescue StandardError
      nil
    end
    puts " • Stopping the listener...".red.bold
    begin
      listener&.stop
    rescue StandardError
      nil
    end
    puts " • Exiting....".red + "Thanks for playing....\n".green

    exit 11
  end

  def last_update=(value)
    mutex.synchronize { @last_update = value }
  end

  def start_keypress_listen_thread
    @screen_cursor = cursor
    Thread.new do
      sleep 2
      loop do
        key = $stdin.getch
        sleep 0.1
        next unless [' ', 'q'].include?(key)

        if key == 'q'
          graceful_exit
        end
        print @screen_cursor.column(1)
        puts "\n • Invoking a manually-triggered refresh...".yellow.bold
        do_command
      end
    end
  end

  def do_command
    self.last_update = Time.now.to_i
    command[counters]
    counters.reset

    print cursor.column(1)
    puts `#{exec_command}` unless exec_command.empty?

    print cursor.column(1)
    puts "Waiting #{minimum_frequency}sec for the next update.".yellow
    print cursor.column(1)
    puts " • Press 'q' to exit, (or Ctrl-C or Ctrl-) if nothing else works.".yellow.bold
    print cursor.column(1)
    sleep 1
  end

  def listener
    @listener ||= Listen.to(directory) do |modified_files, added_files, removed_files|
      modified    = modified_files.size
      added       = added_files.size
      removed     = removed_files.size

      delta = Time.now.to_i - last_update

      counters.increment(modified, added, removed)
      print ("•".yellow.bold.on.magenta * modified) + ("•".green.bold.on.magenta * added) + ("•".red.bold.on.magenta * removed)
      puts "\r\n"

      if delta > minimum_frequency && counters.changed?
        do_command
      end
    end
  end
end

DirectoryWatcher.new(ARGV.shift, *ARGV).run
