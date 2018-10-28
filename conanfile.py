'''
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
'''

from conans import ConanFile


class ShipwrightConanFile(ConanFile):
    name = 'shipwright'
    version = '0.0.1'
    settings = 'os', 'compiler', 'build_type', 'arch'

    def build_requirements(self):
        self.build_requires('catch2/[~=2.4.1]@bincrafters/stable')
        self.build_requires('frozen/20181020@bincrafters/stable')

        if self.settings.os == "Windows":
            self.build_requires('winflexbison/[~=2.5.16]@bincrafters/stable')
        else:
            self.build_requires('bison/[~=3.0.4]@bincrafters/stable')
            self.build_requires('flex/[~=2.6.4]@bincrafters/stable')
