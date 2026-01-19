fx_version 'cerulean'
game 'gta5'

description 'impound with mantine ui wip'
version '1.0.0'
author 'pen'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua'
}

client_scripts {
    'client/cl_*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_*.lua'
}

ui_page 'html/index.html'

files {
    'html/*'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'ox_target'
}

lua54 'yes'
