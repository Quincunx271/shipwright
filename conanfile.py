'''
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
'''

from conans import ConanFile, CMake, tools
from conans.errors import ConanInvalidConfiguration

import os
import re

def cmakelists_version():
    try:
        cmakelists = tools.load('CMakeLists.txt')
        version = re.search(
            r'project\(.*VERSION\s+(\S*).*\)', cmakelists
        ).group(1)
        return version.strip()
    except:
        return None


def holds_int(s):
    try:
        int(s)
        return True
    except ValueError:
        return False


class ShipwrightConanFile(ConanFile):
    name = 'shipwright'
    version = cmakelists_version()
    description = 'A parser for the CMake scripting language'
    url = 'https://github.com/Quincunx271/shipwright'
    license = 'MPL-2.0'
    no_copy_source = True
    generators = 'cmake_paths'

    settings = 'os', 'compiler', 'build_type', 'arch'
    options = {
        'cppstd': 'ANY',
        'fPIC': [True, False],
    }
    default_options = {
        'cppstd': 17,
        'fPIC': True,
    }
    requires = (
        'frozen/20181020@bincrafters/stable',
        'catch2/2.4.1@bincrafters/stable',
    )
    exports_sources = 'cmake/*', 'src/*', 'CMakeLists.txt', 'LICENSE'

    def configure(self):
        if not holds_int(self.options.cppstd):
            raise ConanInvalidConfiguration('cppstd must hold an integer')
        if int(self.options.cppstd) < 17:
            raise ConanInvalidConfiguration('cppstd must be >= 17')

    def build_requirements(self):
        if self.settings.os == 'Windows':
            self.build_requires('winflexbison/2.5.16@bincrafters/stable')
        else:
            self.build_requires('bison/3.0.4@bincrafters/stable')
            self.build_requires('flex/2.6.4@bincrafters/stable')

    def _configure_cmake(self):
        cmake = CMake(self)
        cmake.configure()
        return cmake

    def source(self):
        hidden_pmm = '''
        include("${CMAKE_BINARY_DIR}/conan_paths.cmake")
        function(pmm)
        endfunction()
        '''

        tools.save('pmm.cmake', hidden_pmm)


    def build(self):
        cmake = self._configure_cmake()
        cmake.build()

    def package(self):
        cmake = self._configure_cmake()
        cmake.install()

        self.copy('LICENSE', dst='licenses')
