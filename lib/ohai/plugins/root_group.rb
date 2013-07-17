#
# Author:: Joseph Anthony Pasquale Holsten (<joseph@josephholsten.com>)
# Copyright:: Copyright (c) 2013 Joseph Anthony Pasquale Holsten
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

provides 'root_group'

if RUBY_PLATFORM =~ /msin|mingw|windows/

  require 'ffi'

  # Per http://support.microsoft.com/kb/243330 SID: S-1-5-32-544 is the
  # internal name for the Administrators group, which lets us work
  # properly in environments with a renamed or localized name for the
  # Administrators group
  BUILTIN_ADMINISTRATORS_SID = 'S-1-5-32-544'

  module Win32
    extend FFI::Library
    ffi_lib 'advapi32'
    attach_function :lookup_account_sid,
    :LookupAccountSidA,[ :pointer, :pointer, :pointer, :pointer, :pointer, :pointer, :pointer ], :long
  end

  module Win32
    extend FFI::Library
    ffi_lib 'advapi32'
    attach_function :convert_string_sid_to_sid,
    :ConvertStringSidToSidA,[ :pointer, :pointer ], :long
  end

  module Win32
    extend FFI::Library
    ffi_lib 'kernel32'
    attach_function :local_free,
    :LocalFree, [ :pointer ], :long
  end

  module Win32
    extend FFI::Library
    ffi_lib 'kernel32'
    attach_function :get_last_error,
    :GetLastError, [], :long
  end

  def get_windows_root_group_name
    succeeded = true
    administrators_group_name_result = nil
    
    administrators_sid_result = FFI::MemoryPointer.new(:pointer, 4)

    convert_result = Win32.convert_string_sid_to_sid(BUILTIN_ADMINISTRATORS_SID, administrators_sid_result)

    succeeded = convert_result != 0

    administrators_group_name_buffer = 0.chr * 260
    administrators_group_name_length = [administrators_group_name_buffer.length].pack('L')
    domain_name_length_buffer = [260].pack('L')
    sid_use_result = 0.chr * 4

    if succeeded 
      lookup_result = Win32.lookup_account_sid(
                                               nil,
                                               administrators_sid_result.read_pointer,
                                               administrators_group_name_buffer,
                                               administrators_group_name_length,
                                               nil,
                                               domain_name_length_buffer,
                                               sid_use_result)

      if  lookup_result == 0
        succeeded = false
        last_error = Win32.get_last_error
        puts "Last error #{last_error}"
      end
    end
    
    if succeeded
      administrators_group_name_result = administrators_group_name_buffer.strip
    end
    
    free_result = Win32.local_free(administrators_sid_result.read_pointer)

    administrators_group_name_result
  end
end

case ::RbConfig::CONFIG['host_os']
when /mswin|mingw32|windows/
  group = get_windows_root_group_name
  puts "Windows admin group: #{group}"
  root_group group
else
  root_group Etc.getgrgid(Etc.getpwnam('root').gid).name
end
