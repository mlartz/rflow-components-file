require 'rflow/component'
require 'digest/md5'

class RFlow
  module Components
    module File
      class DirectoryWatcher < RFlow::Component
        output_port :file_port
        output_port :raw_port

        DEFAULT_CONFIG = {
          'directory_path'  => '/tmp/import',
          'file_name_glob'  => '*',
          'poll_interval'   => 1,
          'files_per_poll'  => 1,
          'remove_files'    => true,
        }

        attr_accessor :config, :poll_interval, :directory_path, :file_name_glob, :remove_files

        def configure!(config)
          @config = DEFAULT_CONFIG.merge config
          @directory_path  = ::File.expand_path(@config['directory_path'])
          @file_name_glob  = @config['file_name_glob']
          @poll_interval   = @config['poll_interval'].to_i
          @files_per_poll  = @config['files_per_poll'].to_i
          @remove_files    = to_boolean(@config['remove_files'])

          unless ::File.directory?(@directory_path)
            raise ArgumentError, "Invalid directory '#{@directory_path}'"
          end

          unless ::File.readable?(@directory_path)
            raise ArgumentError, "Unable to read from directory '#{@directory_path}'"
          end

          # TODO: more error checking of input config
        end

        # TODO: optimize sending of messages based on what is connected
        def run!
          timer = EventMachine::PeriodicTimer.new(poll_interval) do
            RFlow.logger.debug { "#{name}: Polling for files in #{::File.join(@directory_path, @file_name_glob)}" }
            # Sort by last modified, which will process the earliest
            # modified file first
            file_paths = Dir.glob(::File.join(@directory_path, @file_name_glob)).sort_by {|f| test(?M, f)}

            file_paths.first(@files_per_poll).each do |path|
              RFlow.logger.debug { "#{name}: Importing #{path}" }
              ::File.open(path, 'r:BINARY') do |file|
                content = file.read

                RFlow.logger.debug { "#{name}: Read #{content.bytesize} bytes of #{file.size} in #{file.path}, md5 #{Digest::MD5.hexdigest(content)}" }

                file_port.send_message(RFlow::Message.new('RFlow::Message::Data::File').tap do |m|
                  m.data.path = ::File.expand_path(file.path)
                  m.data.size = file.size
                  m.data.content = content
                  m.data.creation_timestamp = file.ctime
                  m.data.modification_timestamp = file.mtime
                  m.data.access_timestamp = file.atime
                end)

                raw_port.send_message(RFlow::Message.new('RFlow::Message::Data::Raw').tap do |m|
                  m.data.raw = content
                end)
              end

              if @remove_files
                RFlow.logger.debug { "#{name}: Removing #{::File.join(@directory_path, path)}" }
                ::File.delete path
              end
            end
          end
        end

        def to_boolean(string)
          case string
          when /^true$/i, '1', true; true
          when /^false/i, '0', false; false
          else raise ArgumentError, "'#{string}' cannot be coerced to a boolean value"
          end
        end
      end
    end
  end
end
