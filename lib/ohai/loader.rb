#
# Author:: Claire McQuin (<claire@opscode.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'ohai/log'
require 'ohai/mash'
require 'ohai/dsl/plugin'
require 'ohai/mixin/from_file'

module Ohai
  class Loader
    include Ohai::Mixin::FromFile

    def initialize(controller)
      @attributes = controller.attributes
    end

    def load_plugin(plugin_path, plugin_name=nil)
      plugin = nil

      contents = ""
      begin
        contents << IO.read(plugin_path)
      rescue IOError, Errno::ENOENT
        Ohai::Log.warn("Unable to open or read plugin at #{plugin_path}")
        return plugin
      end

      if contents.include?("Ohai.plugin")
        begin
          plugin = self.instance_eval(contents, plugin_path, 1)
        rescue SystemExit, Interrupt
          raise
        rescue NoMethodError => e
          Ohai::Log.warn("[UNSUPPORTED OPERATION] Plugin at #{plugin_path} used unsupported operation \'#{e.name.to_s}\'")
        rescue Exception, Errno::ENOENT => e
          Ohai::Log.warn("Plugin at #{plugin_path} threw exception #{e.inspect} #{e.backtrace.join("\n")}")
        end

        return plugin if plugin.nil?
        collect_provides(plugin)
      else
        Ohai::Log.warn("[DEPRECATION] Plugin at #{plugin_path} is a version 6 plugin. Version 6 plugins will not be supported in future releases of Ohai. Please upgrage your plugin to version 7 plugin syntax. For more information visit here: XXX")
        plugin = Ohai.v6plugin do collect_contents contents end
        if plugin.nil?
          Ohai::Log.warn("Unable to load plugin at #{plugin_path}")
          return plugin
        end
      end

      plugin
    end

    def run_list
      @plugins = collect_plugins
      @num_plugins = @plugins.size
      @num_visited = 0

      list = []
      while @num_visited < @num_plugins
        visit(next_unvisited, list)
      end
      list
    end

    private

    def collect_provides(plugin)
      plugin_provides = plugin.provides_attrs
      
      plugin_provides.each do |attr|
        parts = attr.split('/')
        a = @attributes
        unless parts.length == 0
          parts.shift if parts[0].length == 0
          parts.each do |part|
            a[part] ||= Mash.new
            a = a[part]
          end
        end

        a[:providers] ||= []
        a[:providers] << plugin
      end
    end

    def collect_plugins
      plugins = Mash.new
      @attributes.keys.sort.each do |attr|
        a = @attributes[attr]
        a.keys.sort.each do |attr_k|
          add_providers(a[attr_k][:providers], plugins) unless attr_k == "providers"
        end
        add_providers(a[:providers], plugins) if a.has_key? "providers"
      end
      plugins
    end

    def add_providers(providers, plugins)
      providers.each do |provider|
        plugins[provider.to_s] ||= Mash.new
        p = plugins[provider.to_s]
        p[:status] = :unvisited
        p[:object] = provider
      end
    end

    def next_unvisited
      @plugins.each do |plgn, vals|
        return plgn if vals[:status] == :unvisited
      end
    end

    def visit(plugin, list)
      status = @plugins[plugin][:status]
      if status == :tmpvisit
        Ohai::Log.warn("Circular dependencies.")
      elsif status == :unvisited
        p = @plugins[plugin]
        p[:status] = :tmpvisit
        p[:object].depends_attrs.sort.each do |dependency|
          parts = dependency.split('/')
          a = @attributes
          unless parts.length == 0
            parts.each do |part|
              next if part == Ohai::OS.collect_os
              a = a[part]
            end
          end
          a[:providers].each do |provider|
            visit(provider.to_s, list)
          end
        end
        @num_visited += 1
        p[:status] = :visited
        list << p[:object]
      end
    end

  end
end
